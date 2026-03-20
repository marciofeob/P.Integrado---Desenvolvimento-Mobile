import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_stox.dart';
import '../services/database_helper.dart';
import '../services/sap_service.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';
import 'login_page.dart';
import 'contador_offline_page.dart';
import 'api_config_page.dart';
import 'item_search_page.dart';

/// Painel principal do STOX.
///
/// Exibe as contagens offline pendentes, permite sincronizar com o
/// SAP Business One e navega para as demais telas via Drawer.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagens    = [];
  bool                       _iniciando    = true;
  bool                       _carregando   = false;
  String                     _nomeOperador = 'Operador...';

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  // ── Dados ─────────────────────────────────────────────────────────────────

  Future<void> _carregarDadosIniciais() async {
    await Future.wait([_carregarContagens(), _carregarUsuario()]);
  }

  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _nomeOperador = prefs.getString('UserName') ?? 'Operador STOX');
  }

  Future<void> _carregarContagens() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    if (!mounted) return;
    setState(() {
      _contagens = dados;
      _iniciando = false;
    });
  }

  // ── Sincronização ─────────────────────────────────────────────────────────

  Future<void> _sincronizarComSAP() async {
    if (_contagens.isEmpty) return;
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
      StoxSnackbar.erro(context, 'Sem conexão com o servidor SAP. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Erros SAP ─────────────────────────────────────────────────────────────

  /// Classifica a mensagem de erro bruta do SAP em uma categoria amigável
  /// usando um sistema de pontuação por palavras-chave.
  _ErroSap _interpretarErroSap(String mensagemBruta) {
    final msg     = mensagemBruta.toUpperCase();
    final tecnico = mensagemBruta.length > 300
        ? '${mensagemBruta.substring(0, 300)}...'
        : mensagemBruta;

    String itemEncontrado     = '';
    String depositoEncontrado = '';
    for (final c in _contagens) {
      final codigo = c['itemCode'].toString().trim().toUpperCase();
      if (msg.contains(codigo)) {
        itemEncontrado     = c['itemCode'].toString().trim();
        depositoEncontrado = c['warehouseCode']?.toString().trim() ?? '';
        break;
      }
    }

    // Contagem já aberta
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

    // Sessão expirada
    if (msg.contains('SESSION') || msg.contains('401') || msg.contains('UNAUTHORIZED')) {
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

    // Falha de rede
    if (msg.contains('TIMEOUT') || msg.contains('CONNECTION') || msg.contains('SOCKET')) {
      return _ErroSap(
        icone: Icons.wifi_off_rounded,
        cor: Colors.red.shade700,
        titulo: 'Falha de comunicação',
        mensagem: 'Não foi possível conectar ao servidor SAP Business One.',
        orientacao:
            'Verifique se você está conectado à rede corporativa e se o servidor SAP está acessível.',
      );
    }

    // Pontuação por palavras-chave para classificar item vs depósito
    int pontoItem     = 0;
    int pontoDeposito = 0;

    if (msg.contains('-4002'))                              pontoItem += 10;
    if (msg.contains('ITEM NOT FOUND'))                     pontoItem += 8;
    if (msg.contains('INVALID ITEM'))                       pontoItem += 8;
    if (msg.contains('ITEM') && msg.contains('NOT EXIST'))  pontoItem += 7;
    if (msg.contains('ITEM') && msg.contains('NOT FOUND'))  pontoItem += 6;
    if (msg.contains('ITEM') && msg.contains('INVALID'))    pontoItem += 5;
    if (msg.contains('ITEM CODE'))                          pontoItem += 4;
    if (msg.contains('ITEM') && msg.contains('UNKNOWN'))    pontoItem += 4;
    if (itemEncontrado.isNotEmpty)                          pontoItem += 3;

    if (msg.contains('-5002'))                                       pontoDeposito += 10;
    if (msg.contains('WAREHOUSE NOT FOUND'))                         pontoDeposito += 8;
    if (msg.contains('INVALID WAREHOUSE'))                           pontoDeposito += 8;
    if (msg.contains('WAREHOUSE') && msg.contains('NOT FOUND'))      pontoDeposito += 6;
    if (msg.contains('WAREHOUSE') && msg.contains('INVALID'))        pontoDeposito += 5;
    if (msg.contains('WAREHOUSECODE') && msg.contains('NOT FOUND'))  pontoDeposito += 6;
    if (msg.contains('WAREHOUSE') && pontoDeposito == 0)             pontoDeposito += 1;

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

    // Fallback genérico
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
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: erro.cor.withAlpha(26),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(erro.icone, color: erro.cor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(erro.titulo,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(erro.mensagem,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
              StoxCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(erro.orientacao,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade800,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
              if (erro.codigoTecnico != null) ...[
                const SizedBox(height: 12),
                Text('Retorno do SAP:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
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
                          height: 1.5),
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
                Navigator.push(context,
                    StoxApp.transicaoPadrao(const ApiConfigPage()));
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
                  borderRadius: BorderRadius.circular(8)),
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
        title: const Text('Painel STOX',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: () {
              HapticFeedback.lightImpact();
              _carregarContagens();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(children: [
          // ── Linear loading durante sincronização ──
          if (_carregando) const StoxLinearLoading(),

          StoxSummaryCard(
            totalItens:    _contagens.length,
            carregando:    _carregando,
            onSincronizar: _sincronizarComSAP,
          ),

          // ── Skeleton no primeiro carregamento ──
          if (_iniciando)
            const StoxSkeletonList(quantidade: 5)
          else if (_contagens.isEmpty)
            Expanded(child: _buildEmptyState())
          else
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildListaContagens(),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Subwidgets do Build ───────────────────────────────────────────────────

  Widget _buildListaContagens() => ListView.builder(
        key: ValueKey(_contagens.length),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        itemCount: _contagens.length,
        itemBuilder: (context, index) {
          final item     = _contagens[index];
          final deposito = item['warehouseCode'] ?? '01';

          return StoxCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
                radius: 22,
                child: Icon(Icons.inventory_2_rounded,
                    color: Theme.of(context).primaryColor, size: 22),
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
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400),
                onPressed: () async {
                  HapticFeedback.vibrate();
                  await DatabaseHelper.instance.excluirContagem(item['id']);
                  _carregarContagens();
                },
              ),
            ),
          );
        },
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.cloud_done_rounded,
                  size: 64, color: Colors.green.shade400),
            ),
            const SizedBox(height: 24),
            Text('Tudo sincronizado!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text('Não há contagens pendentes para envio.',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(children: [
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(color: theme.primaryColor),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person_rounded, size: 40, color: Colors.grey),
          ),
          accountName: Text(_nomeOperador,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          accountEmail: const Row(children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
            SizedBox(width: 6),
            Text('SAP Business One Conectado'),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: Icon(Icons.add_box_rounded, color: theme.primaryColor),
                title: const Text('Nova Contagem Offline',
                    style: TextStyle(fontWeight: FontWeight.w500)),
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
                leading: Icon(Icons.search_rounded, color: theme.primaryColor),
                title: const Text('Pesquisar Item SAP',
                    style: TextStyle(fontWeight: FontWeight.w500)),
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
                leading: Icon(Icons.settings_rounded,
                    color: Colors.grey.shade600),
                title: Text('Configurações da API',
                    style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500)),
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
          title: const Text('Sair da Conta',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Modelo de erro amigável ───────────────────────────────────────────────────

/// Encapsula os dados de exibição de um erro de sincronização SAP.
/// Produzido por [_interpretarErroSap] e consumido por [_exibirErroSap].
class _ErroSap {
  final IconData icone;
  final Color    cor;
  final String   titulo;
  final String   mensagem;
  final String   orientacao;
  final String?  codigoTecnico;

  const _ErroSap({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.mensagem,
    required this.orientacao,
    this.codigoTecnico,
  });
}