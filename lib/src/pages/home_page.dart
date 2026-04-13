import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_stox.dart';
import '../services/database_helper.dart';
import '../services/sap_service.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';
import 'api_config_page.dart';
import 'contador_offline_page.dart';
import 'import_page.dart';
import 'item_search_page.dart';
import 'log_page.dart';
import 'login_page.dart' show kStoxVersao, LoginPage;

/// Painel principal do STOX.
///
/// Exibe as contagens offline pendentes, ações rápidas em grid,
/// permite sincronizar com o SAP Business One e navega para as
/// demais telas via Drawer.
///
/// Responsabilidades:
/// - Monitorar conectividade de rede em tempo real
/// - Listar contagens pendentes do SQLite
/// - Sincronizar com SAP (POST para simples, PATCH para múltiplo)
///   com rastreabilidade por grupo (evita duplicação)
/// - Registrar eventos no log do sistema
/// - Interpretar erros SAP com mensagens amigáveis
/// - Exportar relatório CSV
/// - Navegação via Drawer (contagem simples, equipe, importação, log)
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

  // ── Contagem múltipla ──
  List<dynamic> _documentosAbertos = [];
  bool _carregandoDocs = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
    _iniciarMonitorConexao();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Conectividade ─────────────────────────────────────────────────────────

  /// Monitora mudanças de conectividade e atualiza o estado da UI.
  ///
  /// Quando a rede retorna, verifica automaticamente a sessão SAP.
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

    // Verifica estado inicial da rede
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline = results.every((r) => r == ConnectivityResult.none);
      setState(() => _semInternet = offline);
    });
  }

  // ── Dados iniciais ────────────────────────────────────────────────────────

  /// Carrega contagens, usuário e status SAP em paralelo.
  Future<void> _carregarDadosIniciais() async {
    await Future.wait([
      _carregarContagens(),
      _carregarUsuario(),
      _verificarConexaoSap(),
    ]);
  }

  /// Lê o nome do operador logado das preferências.
  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _nomeOperador = prefs.getString('UserName') ?? 'Operador STOX',
    );
  }

  /// Busca todas as contagens do SQLite e atualiza a lista.
  Future<void> _carregarContagens() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    if (!mounted) return;
    setState(() {
      _contagens = dados;
      _iniciando = false;
    });
  }

  /// Verifica localmente se há sessão SAP ativa (sem request de rede).
  Future<void> _verificarConexaoSap() async {
    final conectado = await SapService.verificarSessao();
    if (!mounted) return;
    setState(() => _sapConectado = conectado);
  }

  // ── Documentos abertos SAP (contagem múltipla) ────────────────────────────

  /// Busca documentos de contagem abertos no SAP via Service Layer.
  Future<void> _carregarDocumentosAbertos() async {
    setState(() => _carregandoDocs = true);
    try {
      final docs = await SapService.buscarDocumentosAbertos();
      if (!mounted) return;
      setState(() {
        _documentosAbertos = docs;
        _carregandoDocs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoDocs = false);
      StoxSnackbar.erro(context, 'Erro ao buscar documentos: $e');
    }
  }

  /// Carrega documentos de contagem **simples** abertos e exibe o bottom sheet.
  ///
  /// Filtra apenas `CountingType == 'ctSingleCounter'`.
  /// Se não houver documentos, vai direto para contagem livre.
  void _mostrarDocumentosSimples() {
    _carregarDocumentosAbertos().then((_) {
      if (!mounted) return;

      final simples = _documentosAbertos
          .where((d) => d['CountingType'] == 'ctSingleCounter')
          .toList();

      if (simples.isEmpty) {
        // Sem documentos simples abertos → contagem livre
        _abrirContagemSimplesDireta();
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _buildDocumentosSheet(
          sheetCtx,
          documentos: simples,
          titulo: 'Documentos de Contagem Simples',
          subtitulo:
              'Selecione um documento para contar, '
              'ou inicie uma contagem livre.',
          acaoExtra: StoxTextButton(
            label: 'CONTAGEM LIVRE',
            icon: Icons.add_rounded,
            onPressed: () {
              Navigator.pop(sheetCtx);
              _abrirContagemSimplesDireta();
            },
          ),
        ),
      );
    });
  }

  /// Carrega documentos de contagem **múltipla** abertos e exibe o bottom sheet.
  ///
  /// Filtra apenas `CountingType == 'ctMultipleCounters'`.
  void _mostrarDocumentosMultiplos() {
    _carregarDocumentosAbertos().then((_) {
      if (!mounted) return;

      final multiplos = _documentosAbertos
          .where((d) => d['CountingType'] == 'ctMultipleCounters')
          .toList();

      if (multiplos.isEmpty) {
        StoxSnackbar.aviso(
          context,
          'Nenhum documento de contagem múltipla aberto no SAP.',
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _buildDocumentosSheet(
          sheetCtx,
          documentos: multiplos,
          titulo: 'Contagem em Equipe',
          subtitulo:
              'Selecione o documento criado pelo gerente '
              'para iniciar a contagem em equipe.',
        ),
      );
    });
  }

  /// Abre a contagem simples diretamente (sem documento SAP).
  ///
  /// Limpa qualquer documento previamente selecionado e navega
  /// para [ContadorOfflinePage] em modo simples.
  Future<void> _abrirContagemSimplesDireta() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('selected_doc_entry'),
      prefs.remove('selected_doc_number'),
      prefs.remove('selected_doc_type'),
    ]);
    if (!mounted) return;
    Navigator.push(
      context,
      StoxApp.transicaoPadrao(const ContadorOfflinePage()),
    ).then((_) => _carregarContagens());
  }

  // ── Sincronização ─────────────────────────────────────────────────────────

  /// Sincroniza as contagens pendentes com o SAP Business One.
  ///
  /// Cada grupo (single / single_doc / multiple) é sincronizado de forma
  /// **independente** — o sucesso de um grupo não depende dos outros.
  /// Para cada grupo, cria um registro de `envio` no SQLite com o resultado
  /// e vincula as contagens ao envio correspondente.
  ///
  /// Todos os eventos são registrados no log do sistema para auditoria.
  Future<void> _sincronizarComSAP() async {
    if (_contagens.isEmpty) return;
    if (_semInternet) {
      StoxSnackbar.erro(context, 'Sem internet. Conecte-se para sincronizar.');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _carregando = true);

    final db = DatabaseHelper.instance;
    await db.logInfo('sync', 'Sincronização iniciada',
        mensagem: '${_contagens.length} contagem(ns) pendente(s).');

    try {
      // Separa contagens por modo
      final livres = _contagens
          .where((c) => c['countingMode'] == 'single')
          .toList();
      final simplesDoc = _contagens
          .where((c) => c['countingMode'] == 'single_doc')
          .toList();
      final multiplos = _contagens
          .where((c) => c['countingMode'] == 'multiple')
          .toList();

      int sucessos = 0;
      int falhas = 0;
      String? ultimoErro;

      // ── 1. Contagem livre (POST cria novo documento) ──
      if (livres.isNotEmpty) {
        final envioId = await db.criarEnvio(
          modo: 'single',
          totalItens: livres.length,
        );
        final ids = livres.map((c) => c['id'] as int).toList();
        final erro = await SapService.postInventoryCounting(livres);

        if (erro == null) {
          await db.finalizarEnvio(envioId, status: 1);
          await db.vincularContagensAoEnvio(ids, envioId, 1);
          await db.logSucesso('sync', 'POST concluído',
              mensagem:
                  '${livres.length} item(ns) enviado(s) como novo documento.');
          sucessos++;
        } else {
          await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
          await db.vincularContagensAoEnvio(ids, envioId, 2);
          await db.logErro('sync', 'Falha no POST',
              mensagem:
                  '${livres.length} item(ns) — modo Simples (Livre).',
              detalhes: erro);
          ultimoErro = erro;
          falhas++;
        }
      }

      // ── 2. Contagem simples com documento (PATCH sem CounterID) ──
      if (simplesDoc.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final docEntry = prefs.getInt('selected_doc_entry');
        final docNumber = prefs.getInt('selected_doc_number');

        final envioId = await db.criarEnvio(
          modo: 'single_doc',
          totalItens: simplesDoc.length,
          docEntry: docEntry,
          docNumber: docNumber,
        );
        final ids = simplesDoc.map((c) => c['id'] as int).toList();

        if (docEntry == null) {
          const erro = 'Documento não identificado. '
              'Selecione um documento de contagem simples no menu.';
          await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
          await db.vincularContagensAoEnvio(ids, envioId, 2);
          await db.logAviso('sync', 'Documento não selecionado',
              mensagem: erro);
          ultimoErro = erro;
          falhas++;
        } else {
          final erro = await SapService.patchSingleCounting(
            documentEntry: docEntry,
            contagens: simplesDoc,
          );
          if (erro == null) {
            await db.finalizarEnvio(envioId, status: 1);
            await db.vincularContagensAoEnvio(ids, envioId, 1);
            await db.logSucesso('sync', 'PATCH simples concluído',
                mensagem:
                    '${simplesDoc.length} item(ns) no Doc #$docNumber.');
            sucessos++;
          } else {
            await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
            await db.vincularContagensAoEnvio(ids, envioId, 2);
            await db.logErro('sync', 'Falha no PATCH simples',
                mensagem:
                    '${simplesDoc.length} item(ns) — Doc #$docNumber.',
                detalhes: erro);
            ultimoErro = erro;
            falhas++;
          }
        }
      }

      // ── 3. Contagem múltipla (PATCH com CounterID) ──
      if (multiplos.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final docEntry = prefs.getInt('selected_doc_entry');
        final docNumber = prefs.getInt('selected_doc_number');
        final counterID = await SapService.getCounterID();

        final envioId = await db.criarEnvio(
          modo: 'multiple',
          totalItens: multiplos.length,
          docEntry: docEntry,
          docNumber: docNumber,
        );
        final ids = multiplos.map((c) => c['id'] as int).toList();

        if (docEntry == null) {
          const erro = 'Documento não identificado. '
              'Selecione um documento de contagem em equipe no menu.';
          await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
          await db.vincularContagensAoEnvio(ids, envioId, 2);
          await db.logAviso('sync', 'Documento não selecionado',
              mensagem: erro);
          ultimoErro = erro;
          falhas++;
        } else if (counterID == null) {
          const erro = 'Seu contador (InternalKey) não foi identificado. '
              'Faça logout e login novamente para resolver.';
          await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
          await db.vincularContagensAoEnvio(ids, envioId, 2);
          await db.logAviso('sync', 'CounterID não encontrado',
              mensagem: erro);
          ultimoErro = erro;
          falhas++;
        } else {
          final erro = await SapService.patchInventoryCounting(
            documentEntry: docEntry,
            contagens: multiplos,
            counterID: counterID,
          );
          if (erro == null) {
            await db.finalizarEnvio(envioId, status: 1);
            await db.vincularContagensAoEnvio(ids, envioId, 1);
            await db.logSucesso('sync', 'PATCH múltiplo concluído',
                mensagem:
                    '${multiplos.length} item(ns) — Doc #$docNumber '
                    '— Contador #$counterID.');
            sucessos++;
          } else {
            await db.finalizarEnvio(envioId, status: 2, mensagemErro: erro);
            await db.vincularContagensAoEnvio(ids, envioId, 2);
            await db.logErro('sync', 'Falha no PATCH múltiplo',
                mensagem:
                    '${multiplos.length} item(ns) — Doc #$docNumber.',
                detalhes: erro);
            ultimoErro = erro;
            falhas++;
          }
        }
      }

      // ── 4. Limpar contagens sincronizadas e recarregar ──
      await db.limparContagensSincronizadas();
      await _carregarContagens();
      if (!mounted) return;

      if (falhas == 0) {
        await StoxAudio.play('sounds/check.mp3');
        if (!mounted) return;
        StoxSnackbar.sucesso(context, 'Sincronização concluída com sucesso!');
      } else if (sucessos > 0) {
        await db.logAviso('sync', 'Sincronização parcial',
            mensagem: '$sucessos grupo(s) ok, $falhas com erro.');
        await StoxAudio.play('sounds/error_beep.mp3', isError: true);
        if (!mounted) return;
        StoxSnackbar.aviso(
          context,
          '$sucessos grupo(s) sincronizado(s), $falhas com erro.',
        );
        _exibirErroSap(ultimoErro!);
      } else {
        await StoxAudio.play('sounds/fail.mp3', isFail: true);
        if (!mounted) return;
        _exibirErroSap(ultimoErro!);
      }
    } catch (e) {
      await db.logErro('sync', 'Falha de comunicação',
          mensagem: 'Exceção durante a sincronização.',
          detalhes: '$e');
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

  // ── Interpretação de erros SAP ────────────────────────────────────────────

  /// Analisa a mensagem de erro bruta do SAP e retorna um [_ErroSap] amigável.
  _ErroSap _interpretarErroSap(String mensagemBruta) {
    final msg = mensagemBruta.toUpperCase();
    final tecnico = mensagemBruta.length > 300
        ? '${mensagemBruta.substring(0, 300)}...'
        : mensagemBruta;

    // Tenta identificar o item que causou o erro
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

    // ── Contagem já aberta ──
    if (mensagemBruta.contains('-1310') ||
        mensagemBruta.contains('1470000497') ||
        msg.contains('ALREADY')) {
      return _ErroSap(
        icone: Icons.lock_clock_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Contagem já aberta no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" já possui uma contagem aberta '
                  'e não finalizada no SAP Business One.'
            : 'Um dos itens já possui uma contagem aberta '
                  'e não finalizada no SAP.',
        orientacao:
            'Acesse SAP Business One → Estoque → Contagem de Estoque, '
            'finalize ou cancele a contagem existente e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    // ── Sessão expirada ──
    if (msg.contains('SESSION') ||
        msg.contains('401') ||
        msg.contains('UNAUTHORIZED')) {
      return _ErroSap(
        icone: Icons.lock_rounded,
        cor: Colors.red.shade700,
        titulo: 'Sessão expirada',
        mensagem: 'Sua sessão no SAP Business One expirou.',
        orientacao:
            'Faça login novamente para continuar. '
            'Seus dados de contagem estão salvos.',
        codigoTecnico: tecnico,
      );
    }

    // ── Falha de rede ──
    if (msg.contains('TIMEOUT') ||
        msg.contains('CONNECTION') ||
        msg.contains('SOCKET')) {
      return _ErroSap(
        icone: Icons.wifi_off_rounded,
        cor: Colors.red.shade700,
        titulo: 'Falha de comunicação',
        mensagem: 'Não foi possível conectar ao servidor SAP Business One.',
        orientacao:
            'Verifique se você está conectado à rede corporativa '
            'e se o servidor SAP está acessível.',
      );
    }

    // ── Pontuação: item vs depósito ──
    int pontoItem = 0;
    int pontoDeposito = 0;

    if (msg.contains('-4002')) pontoItem += 10;
    if (msg.contains('ITEM NOT FOUND')) pontoItem += 8;
    if (msg.contains('INVALID ITEM')) pontoItem += 8;
    if (msg.contains('ITEM') && msg.contains('NOT EXIST')) pontoItem += 7;
    if (msg.contains('ITEM') && msg.contains('NOT FOUND')) pontoItem += 6;
    if (msg.contains('ITEM') && msg.contains('INVALID')) pontoItem += 5;
    if (msg.contains('ITEM CODE')) pontoItem += 4;
    if (msg.contains('ITEM') && msg.contains('UNKNOWN')) pontoItem += 4;
    if (itemEncontrado.isNotEmpty) pontoItem += 3;

    if (msg.contains('-5002')) pontoDeposito += 10;
    if (msg.contains('WAREHOUSE NOT FOUND')) pontoDeposito += 8;
    if (msg.contains('INVALID WAREHOUSE')) pontoDeposito += 8;
    if (msg.contains('WAREHOUSE') && msg.contains('NOT FOUND')) {
      pontoDeposito += 6;
    }
    if (msg.contains('WAREHOUSE') && msg.contains('INVALID')) {
      pontoDeposito += 5;
    }
    if (msg.contains('WAREHOUSECODE') && msg.contains('NOT FOUND')) {
      pontoDeposito += 6;
    }
    if (msg.contains('WAREHOUSE') && pontoDeposito == 0) pontoDeposito += 1;

    if (pontoItem > pontoDeposito && pontoItem > 0) {
      return _ErroSap(
        icone: Icons.inventory_2_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Item não encontrado no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" não existe no cadastro '
                  'do SAP Business One.'
            : 'Um dos itens da contagem não existe no cadastro '
                  'do SAP Business One.',
        orientacao:
            'Corrija o código do item na tela de contagem '
            'e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    if (pontoDeposito > pontoItem && pontoDeposito > 1) {
      return _ErroSap(
        icone: Icons.warning_amber_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Erro ao enviar contagem',
        mensagem: depositoEncontrado.isNotEmpty
            ? 'O SAP recusou o item com depósito "$depositoEncontrado". '
                  'Confirme se o código e o depósito estão corretos.'
            : 'O SAP recusou um ou mais itens. '
                  'Confirme os códigos e o depósito configurado.',
        orientacao:
            'Verifique o retorno técnico abaixo, '
            'corrija o problema e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    return _ErroSap(
      icone: Icons.error_outline_rounded,
      cor: Colors.red.shade700,
      titulo: 'Erro na sincronização',
      mensagem: itemEncontrado.isNotEmpty
          ? 'Ocorreu um erro ao processar o item "$itemEncontrado".'
          : 'Ocorreu um erro ao enviar os dados '
                'para o SAP Business One.',
      orientacao:
          'Anote a mensagem de erro abaixo e contate o administrador '
          'do SAP se o problema persistir.',
      codigoTecnico: tecnico,
    );
  }

  /// Exibe o diálogo de erro SAP com mensagem amigável e retorno técnico.
  void _exibirErroSap(String mensagemBruta) {
    final erro = _interpretarErroSap(mensagemBruta);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
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
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 18),
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
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  StoxApp.transicaoPadrao(const ApiConfigPage()),
                );
              },
            ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx);
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
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildAppBarStatusChip(),
          ),
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
                      _buildContagensHeader(),
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
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_box_rounded,
                label: 'Simples',
                sub: 'Um operador conta',
                cor: theme.primaryColor,
                onTap: () {
                  if (!_sapConectado || _semInternet) {
                    _abrirContagemSimplesDireta();
                    return;
                  }
                  _mostrarDocumentosSimples();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.groups_rounded,
                label: 'Equipe',
                sub: _sapConectado
                    ? 'Múltiplos contadores'
                    : 'Requer login SAP',
                cor: _sapConectado
                    ? Colors.purple.shade700
                    : Colors.grey.shade400,
                onTap: () {
                  if (!_sapConectado || _semInternet) {
                    StoxSnackbar.aviso(
                      context,
                      _semInternet
                          ? 'Sem internet. Conecte-se primeiro.'
                          : 'Faça login no SAP para acessar contagem em equipe.',
                    );
                    return;
                  }
                  _mostrarDocumentosMultiplos();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
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
                icon: Icons.upload_file_rounded,
                label: 'Importar',
                sub: 'CSV de coletor',
                cor: Colors.orange.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    StoxApp.transicaoPadrao(const ImportPage()),
                  ).then((_) => _carregarContagens());
                },
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

  // ── Indicador SAP na AppBar ─────────────────────────────────────────────

  Widget _buildAppBarStatusChip() {
    final Color cor;
    final IconData icone;
    final String label;

    if (_semInternet) {
      cor = Colors.red.shade300;
      icone = Icons.wifi_off_rounded;
      label = 'Offline';
    } else if (_sapConectado) {
      cor = Colors.greenAccent;
      icone = Icons.cloud_done_rounded;
      label = 'SAP Online';
    } else {
      cor = Colors.red.shade300;
      icone = Icons.cloud_off_rounded;
      label = 'Sem sessão';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: cor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista de contagens ────────────────────────────────────────────────────

  Widget _buildContagensHeader() {
    return Row(
      children: [
        Icon(Icons.history_rounded, color: Colors.grey.shade500, size: 20),
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildItemContagem(Map<String, dynamic> item) {
    final deposito = item['warehouseCode'] ?? '01';
    final isMultiplo = item['countingMode'] == 'multiple';

    return StoxCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isMultiplo
              ? Colors.purple.shade50
              : Theme.of(context).primaryColor.withAlpha(26),
          radius: 22,
          child: Icon(
            isMultiplo ? Icons.groups_rounded : Icons.inventory_2_rounded,
            color: isMultiplo
                ? Colors.purple.shade700
                : Theme.of(context).primaryColor,
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
            item['counterName'] != null
                ? 'Qtd: ${item['quantidade']}  •  '
                      'Dep: $deposito  •  ${item['counterName']}'
                : 'Qtd: ${item['quantidade']}  •  Dep: $deposito',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
          onPressed: () async {
            HapticFeedback.vibrate();
            final confirmar = await StoxDialog.confirmar(
              context,
              titulo: 'Excluir contagem',
              mensagem:
                  'Deseja excluir a contagem do item '
                  '"${item['itemCode']}"?',
              labelConfirmar: 'EXCLUIR',
              destrutivo: true,
            );
            if (!confirmar) return;
            await DatabaseHelper.instance.excluirContagem(item['id']);
            if (!mounted) return;
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

  // ── Bottom sheet de documentos ─────────────────────────────────────────────

  Widget _buildDocumentosSheet(
    BuildContext sheetCtx, {
    List<dynamic>? documentos,
    String titulo = 'Documentos de Contagem Abertos',
    String subtitulo =
        'Selecione o documento criado pelo gerente '
        'para iniciar a contagem.',
    Widget? acaoExtra,
  }) {
    final theme = Theme.of(context);
    final docs = documentos ?? _documentosAbertos;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(Icons.assignment_rounded,
                    color: theme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(subtitulo,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          if (acaoExtra != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: acaoExtra),
          const SizedBox(height: 16),
          if (_carregandoDocs)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final doc = docs[i] as Map<String, dynamic>;
                  return _buildDocCard(doc, sheetCtx);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc, BuildContext sheetCtx) {
    final theme = Theme.of(context);
    final docNum = doc['DocumentNumber'] ?? '?';
    final docEntry = doc['DocumentEntry'] as int? ?? 0;
    final countDate = doc['CountDate']?.toString().split('T').first ?? '';
    final tipo = doc['CountingType']?.toString() ?? '';
    final isMultiplo = tipo == 'ctMultipleCounters';
    final contadores = (doc['IndividualCounters'] as List?) ?? [];
    final remarks = doc['Remarks']?.toString() ?? '';

    return StoxCard(
      borderColor: isMultiplo ? Colors.purple.shade200 : Colors.blue.shade200,
      child: InkWell(
        onTap: () async {
          HapticFeedback.selectionClick();
          Navigator.pop(sheetCtx);
          final prefs = await SharedPreferences.getInstance();
          await Future.wait([
            prefs.setInt('selected_doc_entry', docEntry),
            prefs.setInt('selected_doc_number', docNum is int ? docNum : 0),
            prefs.setString('selected_doc_type', tipo),
          ]);
          if (!mounted) return;
          Navigator.push(
            context,
            StoxApp.transicaoPadrao(const ContadorOfflinePage()),
          ).then((_) => _carregarContagens());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isMultiplo ? Icons.groups_rounded : Icons.person_rounded,
                    color: isMultiplo
                        ? Colors.purple.shade700
                        : theme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Doc #$docNum',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isMultiplo
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isMultiplo ? 'Múltiplo' : 'Simples',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMultiplo
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Data: $countDate',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              if (contadores.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Contadores: ${contadores.map((c) => c['CounterName']).join(', ')}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (remarks.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(remarks,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 14, color: theme.primaryColor),
                  const SizedBox(width: 4),
                  Text('Toque para iniciar contagem',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

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
                // ── Contagem Simples ──
                ListTile(
                  leading: Icon(Icons.add_box_rounded,
                      color: theme.primaryColor),
                  title: const Text('Contagem Simples',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Um operador conta e sincroniza',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    if (_sapConectado && !_semInternet) {
                      _mostrarDocumentosSimples();
                    } else {
                      _abrirContagemSimplesDireta();
                    }
                  },
                ),

                // ── Contagem em Equipe ──
                ListTile(
                  leading: Icon(Icons.groups_rounded,
                      color: _sapConectado
                          ? Colors.purple.shade700
                          : Colors.grey.shade400),
                  title: Text('Contagem em Equipe',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color:
                              _sapConectado ? null : Colors.grey.shade400)),
                  subtitle: Text(
                      _sapConectado
                          ? 'Selecionar documento do SAP'
                          : 'Faça login no SAP primeiro',
                      style: TextStyle(
                          fontSize: 12,
                          color: _sapConectado
                              ? Colors.grey.shade500
                              : Colors.grey.shade400)),
                  trailing: _carregandoDocs
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.purple.shade400))
                      : null,
                  enabled: _sapConectado && !_semInternet,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    _mostrarDocumentosMultiplos();
                  },
                ),

                // ── Importar Contagem ──
                ListTile(
                  leading: Icon(Icons.upload_file_rounded,
                      color: Colors.orange.shade700),
                  title: const Text('Importar Contagem',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('CSV de outro STOX ou coletor',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(context,
                            StoxApp.transicaoPadrao(const ImportPage()))
                        .then((_) => _carregarContagens());
                  },
                ),

                _buildDrawerDivider(),

                // ── Pesquisar Item ──
                ListTile(
                  leading: Icon(Icons.search_rounded,
                      color: theme.primaryColor),
                  title: const Text('Pesquisar Item SAP',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(context,
                        StoxApp.transicaoPadrao(const ItemSearchPage()));
                  },
                ),

                _buildDrawerDivider(),

                // ── Log do Sistema ──
                ListTile(
                  leading: Icon(Icons.receipt_long_rounded,
                      color: Colors.blueGrey.shade600),
                  title: const Text('Log do Sistema',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Histórico de atividades e envios',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(context,
                        StoxApp.transicaoPadrao(const LogPage()));
                  },
                ),

                // ── Configurações ──
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
                    Navigator.push(context,
                        StoxApp.transicaoPadrao(const ApiConfigPage()));
                  },
                ),
              ],
            ),
          ),

          // ── Rodapé do Drawer ──
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sair da Conta',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              HapticFeedback.heavyImpact();
              await SapService.logout();
              await DatabaseHelper.instance.logInfo(
                'auth',
                'Logout realizado',
                mensagem: 'Operador: $_nomeOperador.',
              );
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
              16,
              8,
              16,
              24 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Text(
              kStoxVersao,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  /// Divider padrão para separar seções do Drawer.
  Widget _buildDrawerDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(color: Colors.grey.shade200),
  );
}

// ── Modelo de erro amigável ─────────────────────────────────────────────────

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