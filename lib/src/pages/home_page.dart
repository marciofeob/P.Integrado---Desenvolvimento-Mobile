import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_stox.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/sap_service.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';
import 'login_page.dart';
import 'contador_offline_page.dart';
import 'api_config_page.dart';
import 'item_search_page.dart';

/// Painel principal do STOX.
///
/// Exibe as contagens offline pendentes, ações rápidas em grid,
/// permite sincronizar com o SAP Business One e navega para as
/// demais telas via Drawer.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagens = [];
  bool _iniciando = true;
  bool _carregando = false;
  String _nomeOperador = 'Operador...';
  bool _sapConectado = false;
  bool _semInternet = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
    _iniciarMonitorConexao();
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  // ── Conectividade ─────────────────────────────────────────────────────────

  void _iniciarMonitorConexao() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (!mounted) return;
      if (offline != _semInternet) {
        setState(() => _semInternet = offline);
        if (offline) {
          StoxSnackbar.erro(context, 'Sem conexão com a internet.');
        } else {
          StoxSnackbar.sucesso(context, 'Conexão restabelecida!');
          _verificarConexaoSap();
        }
      }
    });

    // Verifica estado inicial
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline = results.every((r) => r == ConnectivityResult.none);
      setState(() => _semInternet = offline);
    });
  }

  // ── Dados ─────────────────────────────────────────────────────────────────

  Future<void> _carregarDadosIniciais() async {
    await Future.wait([
      _carregarContagens(),
      _carregarUsuario(),
      _verificarConexaoSap(),
    ]);
  }

  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _nomeOperador = prefs.getString('UserName') ?? 'Operador STOX',
    );
  }

  Future<void> _carregarContagens() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    if (!mounted) return;
    setState(() {
      _contagens = dados;
      _iniciando = false;
    });
  }

  Future<void> _verificarConexaoSap() async {
    final conectado = await SapService.verificarSessao();
    if (!mounted) return;
    setState(() => _sapConectado = conectado);
  }

  // ── Exportação ────────────────────────────────────────────────────────────

  Future<void> _exportarRelatorio() async {
    HapticFeedback.lightImpact();
    if (_contagens.isEmpty) {
      StoxSnackbar.aviso(context, 'Nenhuma contagem para exportar.');
      return;
    }
    try {
      final exportado = await ExportService.exportarContagensParaCSV(
        _contagens,
      );
      if (!mounted) return;
      if (exportado) {
        await StoxAudio.play('sounds/check.mp3');
        if (!mounted) return;
        StoxSnackbar.sucesso(context, 'Relatório exportado com sucesso!');
      }
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao exportar: $e');
    }
  }

  // ── Sincronização ─────────────────────────────────────────────────────────

  Future<void> _sincronizarComSAP() async {
    if (_contagens.isEmpty) return;
    if (_semInternet) {
      StoxSnackbar.erro(context, 'Sem internet. Conecte-se para sincronizar.');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _carregando = true);

    try {
      final erro = await SapService.postInventoryCounting(_contagens);

      if (erro == null) {
        await StoxAudio.play('sounds/check.mp3');
        await DatabaseHelper.instance.limparContagens();
        await _carregarContagens();
        if (!mounted) return;
        StoxSnackbar.sucesso(context, 'Sincronização concluída com sucesso!');
      } else {
        await StoxAudio.play('sounds/fail.mp3', isFail: true);
        if (!mounted) return;
        _exibirErroSap(erro);
      }
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(
        context,
        'Sem conexão com o servidor SAP. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Erros SAP ─────────────────────────────────────────────────────────────

  _ErroSap _interpretarErroSap(String mensagemBruta) {
    final msg = mensagemBruta.toUpperCase();
    final tecnico = mensagemBruta.length > 300
        ? '${mensagemBruta.substring(0, 300)}...'
        : mensagemBruta;

    String itemEncontrado = '';
    String depositoEncontrado = '';
    for (final c in _contagens) {
      final codigo = c['itemCode'].toString().trim().toUpperCase();
      if (msg.contains(codigo)) {
        itemEncontrado = c['itemCode'].toString().trim();
        depositoEncontrado = c['warehouseCode']?.toString().trim() ?? '';
        break;
      }
    }

    if (mensagemBruta.contains('-1310') ||
        mensagemBruta.contains('1470000497') ||
        msg.contains('ALREADY')) {
      return _ErroSap(
        icone: Icons.lock_clock_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Contagem já aberta no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" já possui uma contagem aberta e não finalizada no SAP Business One.'
            : 'Um dos itens já possui uma contagem aberta e não finalizada no SAP.',
        orientacao:
            'Acesse SAP Business One → Estoque → Contagem de Estoque, finalize ou cancele a contagem existente e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    if (msg.contains('SESSION') ||
        msg.contains('401') ||
        msg.contains('UNAUTHORIZED')) {
      return _ErroSap(
        icone: Icons.lock_rounded,
        cor: Colors.red.shade700,
        titulo: 'Sessão expirada',
        mensagem: 'Sua sessão no SAP Business One expirou.',
        orientacao:
            'Faça login novamente para continuar. Seus dados de contagem estão salvos.',
        codigoTecnico: tecnico,
      );
    }

    if (msg.contains('TIMEOUT') ||
        msg.contains('CONNECTION') ||
        msg.contains('SOCKET')) {
      return _ErroSap(
        icone: Icons.wifi_off_rounded,
        cor: Colors.red.shade700,
        titulo: 'Falha de comunicação',
        mensagem: 'Não foi possível conectar ao servidor SAP Business One.',
        orientacao:
            'Verifique se você está conectado à rede corporativa e se o servidor SAP está acessível.',
      );
    }

    int pontoItem = 0;
    int pontoDeposito = 0;

    if (msg.contains('-4002')) { pontoItem += 10; }
    if (msg.contains('ITEM NOT FOUND')) { pontoItem += 8; }
    if (msg.contains('INVALID ITEM')) { pontoItem += 8; }
    if (msg.contains('ITEM') && msg.contains('NOT EXIST')) { pontoItem += 7; }
    if (msg.contains('ITEM') && msg.contains('NOT FOUND')) { pontoItem += 6; }
    if (msg.contains('ITEM') && msg.contains('INVALID')) { pontoItem += 5; }
    if (msg.contains('ITEM CODE')) { pontoItem += 4; }
    if (msg.contains('ITEM') && msg.contains('UNKNOWN')) { pontoItem += 4; }
    if (itemEncontrado.isNotEmpty) { pontoItem += 3; }

    if (msg.contains('-5002')) { pontoDeposito += 10; }
    if (msg.contains('WAREHOUSE NOT FOUND')) { pontoDeposito += 8; }
    if (msg.contains('INVALID WAREHOUSE')) { pontoDeposito += 8; }
    if (msg.contains('WAREHOUSE') && msg.contains('NOT FOUND')) { pontoDeposito += 6; }
    if (msg.contains('WAREHOUSE') && msg.contains('INVALID')) { pontoDeposito += 5; }
    if (msg.contains('WAREHOUSECODE') && msg.contains('NOT FOUND')) { pontoDeposito += 6; }
    if (msg.contains('WAREHOUSE') && pontoDeposito == 0) { pontoDeposito += 1; }

    if (pontoItem > pontoDeposito && pontoItem > 0) {
      return _ErroSap(
        icone: Icons.inventory_2_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Item não encontrado no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" não existe no cadastro do SAP Business One.'
            : 'Um dos itens da contagem não existe no cadastro do SAP Business One.',
        orientacao:
            'Corrija o código do item na tela de contagem e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    if (pontoDeposito > pontoItem && pontoDeposito > 1) {
      return _ErroSap(
        icone: Icons.warning_amber_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Erro ao enviar contagem',
        mensagem: depositoEncontrado.isNotEmpty
            ? 'O SAP recusou o item com depósito "$depositoEncontrado". Confirme se o código e o depósito estão corretos.'
            : 'O SAP recusou um ou mais itens. Confirme os códigos e o depósito configurado.',
        orientacao:
            'Verifique o retorno técnico abaixo, corrija o problema e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    return _ErroSap(
      icone: Icons.error_outline_rounded,
      cor: Colors.red.shade700,
      titulo: 'Erro na sincronização',
      mensagem: itemEncontrado.isNotEmpty
          ? 'Ocorreu um erro ao processar o item "$itemEncontrado".'
          : 'Ocorreu um erro ao enviar os dados para o SAP Business One.',
      orientacao:
          'Anote a mensagem de erro abaixo e contate o administrador do SAP se o problema persistir.',
      codigoTecnico: tecnico,
    );
  }

  void _exibirErroSap(String mensagemBruta) {
    final erro = _interpretarErroSap(mensagemBruta);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: erro.cor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(erro.icone, color: erro.cor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                erro.titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                erro.mensagem,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              StoxCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        erro.orientacao,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (erro.codigoTecnico != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Retorno do SAP:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                StoxCard(
                  borderColor: Colors.grey.shade300,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SelectableText(
                      erro.codigoTecnico!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.blueGrey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          if (erro.titulo.contains('Depósito'))
            StoxTextButton(
              label: 'IR PARA CONFIGURAÇÕES',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  StoxApp.transicaoPadrao(const ApiConfigPage()),
                );
              },
            ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              if (erro.titulo.contains('expirada')) {
                Navigator.pushAndRemoveUntil(
                  context,
                  StoxApp.transicaoPadrao(const LoginPage()),
                  (r) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: erro.cor,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              erro.titulo.contains('expirada') ? 'FAZER LOGIN' : 'ENTENDIDO',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Painel STOX',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: () {
              HapticFeedback.lightImpact();
              _carregarDadosIniciais();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Banner offline persistente ──
            if (_semInternet) _buildOfflineBanner(),

            if (_carregando) const StoxLinearLoading(),

            StoxSummaryCard(
              totalItens: _contagens.length,
              carregando: _carregando,
              onSincronizar: _sincronizarComSAP,
            ),

            if (_iniciando)
              const StoxSkeletonList(quantidade: 5)
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                  children: [
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    if (_contagens.isEmpty)
                      _buildEmptyState()
                    else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Contagens pendentes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_contagens.length} itens',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._contagens.map(_buildItemContagem),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Banner offline ────────────────────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sem conexão com a internet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            'OFFLINE',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ações Rápidas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            _buildChipConexao(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_box_rounded,
                label: 'Contagem',
                sub: 'Modo offline',
                cor: theme.primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    StoxApp.transicaoPadrao(const ContadorOfflinePage()),
                  ).then((_) => _carregarContagens());
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.search_rounded,
                label: 'Pesquisar',
                sub: 'Consulta SAP',
                cor: Colors.teal.shade600,
                onTap: () => Navigator.push(
                  context,
                  StoxApp.transicaoPadrao(const ItemSearchPage()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.share_rounded,
                label: 'Exportar',
                sub: '${_contagens.length} reg.',
                cor: Colors.orange.shade700,
                onTap: _exportarRelatorio,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String sub,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          height: 100,
          decoration: BoxDecoration(
            color: cor.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cor.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cor, size: 26),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chip de conexão SAP ───────────────────────────────────────────────────

  Widget _buildChipConexao() {
    // Sem internet = sempre vermelho
    if (_semInternet) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 4),
            Text(
              'Sem internet',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final conectado = _sapConectado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: conectado ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: conectado ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            conectado ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 14,
            color: conectado ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            conectado ? 'SAP Conectado' : 'Sem sessão',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: conectado ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Subwidgets ────────────────────────────────────────────────────────────

  Widget _buildItemContagem(Map<String, dynamic> item) {
    final deposito = item['warehouseCode'] ?? '01';
    return StoxCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
          radius: 22,
          child: Icon(
            Icons.inventory_2_rounded,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          '${item['itemCode']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Qtd: ${item['quantidade']}  •  Dep: $deposito',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
          onPressed: () async {
            HapticFeedback.vibrate();
            await DatabaseHelper.instance.excluirContagem(item['id']);
            _carregarContagens();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_done_rounded,
              size: 64,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tudo sincronizado!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há contagens pendentes para envio.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.primaryColor),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 40, color: Colors.grey),
            ),
            accountName: Text(
              _nomeOperador,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Row(
              children: [
                Icon(
                  _semInternet
                      ? Icons.wifi_off_rounded
                      : _sapConectado
                          ? Icons.check_circle
                          : Icons.cancel,
                  color: _semInternet
                      ? Colors.redAccent
                      : _sapConectado
                          ? Colors.greenAccent
                          : Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _semInternet
                      ? 'Sem internet'
                      : _sapConectado
                          ? 'SAP Business One Conectado'
                          : 'SAP Desconectado',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.add_box_rounded,
                    color: theme.primaryColor,
                  ),
                  title: const Text(
                    'Contagem Offline',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      StoxApp.transicaoPadrao(const ContadorOfflinePage()),
                    ).then((_) => _carregarContagens());
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.search_rounded,
                    color: theme.primaryColor,
                  ),
                  title: const Text(
                    'Pesquisar Item SAP',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      StoxApp.transicaoPadrao(const ItemSearchPage()),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.grey.shade200),
                ),
                ListTile(
                  leading: Icon(
                    Icons.settings_rounded,
                    color: Colors.grey.shade600,
                  ),
                  title: Text(
                    'Configurações da API',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      StoxApp.transicaoPadrao(const ApiConfigPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'Sair da Conta',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              HapticFeedback.heavyImpact();
              await SapService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                StoxApp.transicaoPadrao(const LoginPage()),
                (r) => false,
              );
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16,
              24 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Text(
              'STOX v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelo de erro amigável ───────────────────────────────────────────────────

class _ErroSap {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String mensagem;
  final String orientacao;
  final String? codigoTecnico;

  const _ErroSap({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.mensagem,
    required this.orientacao,
    this.codigoTecnico,
  });
}