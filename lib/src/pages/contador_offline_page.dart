import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/ocr_service.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Tela de contagem de estoque offline.
///
/// Os dados são persistidos localmente via [DatabaseHelper] e
/// sincronizados com o SAP Business One pela [HomePage].
class ContadorOfflinePage extends StatefulWidget {
  const ContadorOfflinePage({super.key});

  @override
  State<ContadorOfflinePage> createState() => _ContadorOfflinePageState();
}

class _ContadorOfflinePageState extends State<ContadorOfflinePage> {
  final _codigoController     = TextEditingController();
  final _quantidadeController = TextEditingController(text: '1');
  final _depositoController   = TextEditingController(text: '01');
  final _focusNodeCodigo      = FocusNode();

  List<Map<String, dynamic>> _contagens    = [];
  bool                       _iniciando    = true;
  bool                       _scannerAtivo = false;
  bool                       _modoSelecao  = false;
  final Set<int>             _selecionados = {};

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
    _carregarContagens();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _quantidadeController.dispose();
    _depositoController.dispose();
    _focusNodeCodigo.dispose();
    super.dispose();
  }

  // ── Dados ─────────────────────────────────────────────────────────────────

  Future<void> _carregarConfiguracoes() async {
    final prefs    = await SharedPreferences.getInstance();
    final deposito = prefs.getString('sap_deposito_padrao') ?? '01';
    if (mounted) setState(() => _depositoController.text = deposito);
  }

  Future<void> _carregarContagens() async {
    final lista = await DatabaseHelper.instance.buscarContagens();
    if (!mounted) return;
    setState(() {
      _contagens = lista;
      _iniciando = false;
      _selecionados.removeWhere((id) => !lista.any((c) => c['id'] == id));
    });
  }

  // ── Seleção múltipla ──────────────────────────────────────────────────────

  void _entrarModoSelecao(int id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _modoSelecao = true;
      _selecionados.add(id);
    });
  }

  void _sairModoSelecao() => setState(() {
        _modoSelecao = false;
        _selecionados.clear();
      });

  void _toggleSelecao(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(id);
      }
    });
  }

  void _selecionarTodos() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selecionados.length == _contagens.length) {
        _selecionados.clear();
        _modoSelecao = false;
      } else {
        _selecionados.addAll(_contagens.map((c) => c['id'] as int));
      }
    });
  }

  Future<void> _excluirSelecionados() async {
    if (_selecionados.isEmpty) return;

    final qtd        = _selecionados.length;
    final todosItens = qtd == _contagens.length;

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoConfirmacaoExclusao(
        quantidade:   qtd,
        isTodosItens: todosItens,
        itens: _contagens
            .where((c) => _selecionados.contains(c['id']))
            .toList(),
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      for (final id in _selecionados) {
        await DatabaseHelper.instance.excluirContagem(id);
      }
      await StoxAudio.play('sounds/check.mp3');
      _sairModoSelecao();
      await _carregarContagens();
      if (!mounted) return;
      StoxSnackbar.sucesso(
        context,
        '$qtd ${qtd == 1 ? 'registro removido' : 'registros removidos'} com sucesso.',
      );
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao excluir: $e');
    }
  }

  // ── Duplicata ─────────────────────────────────────────────────────────────

  Map<String, dynamic>? _buscarDuplicata(String itemCode) {
    final codigo = itemCode.trim().toUpperCase();
    try {
      return _contagens
          .firstWhere((c) => c['itemCode'].toString().toUpperCase() == codigo);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _exibirDialogoDuplicata(
      Map<String, dynamic> existente, double novaQuantidade) async {
    await StoxAudio.play('sounds/error_beep.mp3', isError: true);
    if (!mounted) return false;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Item já contado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'O item ${existente['itemCode']} já foi registrado nesta sessão.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            StoxCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _linhaComparativo(
                    'Quantidade atual', '${existente['quantidade']}',
                    Colors.grey.shade700),
                const SizedBox(height: 8),
                _linhaComparativo('Nova quantidade', '$novaQuantidade',
                    Colors.orange.shade700,
                    negrito: true),
                const SizedBox(height: 8),
                _linhaComparativo('Depósito',
                    existente['warehouseCode'] ?? '01', Colors.grey.shade700),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Substituir irá descartar a quantidade atual e usar a nova.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          StoxTextButton(
            label: 'CANCELAR',
            onPressed: () => Navigator.pop(dialogCtx, false),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('SUBSTITUIR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Widget _linhaComparativo(String label, String valor, Color cor,
      {bool negrito = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(valor,
            style: TextStyle(
                fontSize: 13,
                color: cor,
                fontWeight: negrito ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  void _ajustarQuantidade(double valor, {TextEditingController? controller}) {
    HapticFeedback.selectionClick();
    final target = controller ?? _quantidadeController;
    final atual  = double.tryParse(target.text.replaceAll(',', '.')) ?? 0;
    final novo   = (atual + valor).clamp(0.0, double.infinity);
    setState(() {
      target.text = novo % 1 == 0
          ? novo.toInt().toString()
          : novo.toStringAsFixed(2);
    });
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _exportarRelatorio() async {
    HapticFeedback.lightImpact();
    if (_contagens.isEmpty) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Nenhuma contagem para exportar!');
      return;
    }
    try {
      await ExportService.exportarContagensParaCSV(_contagens);
      await StoxAudio.play('sounds/check.mp3');
      if (!mounted) return;
      StoxSnackbar.sucesso(context, 'Relatório exportado com sucesso!');
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao exportar: $e');
    }
  }

  Future<void> _escanearComIA() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final resultado = await OcrService.lerAnotacaoDaCamera();
    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        if (resultado['itemCode']!.isNotEmpty) {
          _codigoController.text = resultado['itemCode']!;
        }
        if (resultado['quantidade']!.isNotEmpty) {
          _quantidadeController.text = resultado['quantidade']!;
        }
      });
      await StoxAudio.play('sounds/beep.mp3');
      if (!mounted) return;
      StoxSnackbar.sucesso(context, 'Leitura via IA concluída!');
      _focusNodeCodigo.nextFocus();
    } else {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Nenhum texto reconhecido.');
    }
  }

  void _abrirScanner() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _scannerAtivo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LayoutBuilder(
        builder: (_, constraints) {
          final scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, 200),
            width: 280,
            height: 180,
          );
          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
                AppBar(
                  title: const Text('Escanear Código',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        scanWindow: scanWindow,
                        onDetect: (capture) async {
                          if (_scannerAtivo) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          _scannerAtivo = true;
                          final code = barcodes.first.rawValue ?? '';
                          await StoxAudio.play('sounds/beep.mp3');
                          if (!mounted) return;
                          _codigoController.text = code;
                          // ignore: use_build_context_synchronously
                          Navigator.of(sheetCtx).pop();
                          _focusNodeCodigo.nextFocus();
                        },
                      ),
                    ),
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha(179), BlendMode.srcOut),
                      child: Stack(children: [
                        Container(
                            decoration: const BoxDecoration(
                                color: Colors.black,
                                backgroundBlendMode: BlendMode.dstOut)),
                        Center(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ]),
                    ),
                    Center(
                      child: Container(
                        width: scanWindow.width,
                        height: scanWindow.height,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(sheetCtx).primaryColor,
                              width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Alinhe o código de barras dentro do quadro',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _salvarContagem() async {
    final itemCode  = _codigoController.text.trim();
    final deposito  = _depositoController.text.trim();
    final quantidade =
        double.tryParse(_quantidadeController.text.replaceAll(',', '.'));

    if (itemCode.isEmpty) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'O código do item é obrigatório.');
      return;
    }
    if (deposito.isEmpty) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Informe o código do depósito.');
      return;
    }
    if (quantidade == null || quantidade <= 0) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Informe uma quantidade válida e maior que zero.');
      return;
    }

    final duplicata = _buscarDuplicata(itemCode);
    if (duplicata != null) {
      final substituir = await _exibirDialogoDuplicata(duplicata, quantidade);
      if (!substituir) return;
      try {
        await DatabaseHelper.instance
            .atualizarContagem(duplicata['id'], quantidade);
        await StoxAudio.play('sounds/check.mp3');
        if (!mounted) return;
        StoxSnackbar.sucesso(context, 'Contagem de $itemCode atualizada!');
        _codigoController.clear();
        _quantidadeController.text = '1';
        await _carregarContagens();
        _focusNodeCodigo.requestFocus();
      } catch (e) {
        await StoxAudio.play('sounds/fail.mp3', isFail: true);
        if (!mounted) return;
        StoxSnackbar.erro(context, 'Erro ao atualizar: $e');
      }
      return;
    }

    try {
      await DatabaseHelper.instance.inserirContagem(
        itemCode,
        quantidade,
        warehouseCode: deposito,
      );
      await StoxAudio.play('sounds/check.mp3');
      if (!mounted) return;
      StoxSnackbar.sucesso(context, 'Item $itemCode salvo com sucesso!');
      _codigoController.clear();
      _quantidadeController.text = '1';
      await _carregarContagens();
      _focusNodeCodigo.requestFocus();
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao salvar: $e');
    }
  }

  // ── Edição ────────────────────────────────────────────────────────────────

  void _abrirEdicao(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    final editQtdController =
        TextEditingController(text: item['quantidade'].toString());
    final editDepController =
        TextEditingController(text: item['warehouseCode'] ?? '01');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar: ${item['itemCode']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quantidade contada:',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 10),
              StoxCard(
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 28),
                    onPressed: () {
                      _ajustarQuantidade(-1, controller: editQtdController);
                      setDialogState(() {});
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: editQtdController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.green, size: 28),
                    onPressed: () {
                      _ajustarQuantidade(1, controller: editQtdController);
                      setDialogState(() {});
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              StoxTextField(
                controller: editDepController,
                labelText: 'Depósito',
                prefixIcon: Icons.warehouse_rounded,
                textCapitalization: TextCapitalization.characters,
                helperText: 'Código do depósito para este item.',
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            StoxTextButton(
              label: 'CANCELAR',
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final novaQtd = double.tryParse(
                        editQtdController.text.replaceAll(',', '.')) ??
                    0;
                final novoDeposito = editDepController.text.trim();

                if (novaQtd <= 0) {
                  await StoxAudio.play('sounds/error_beep.mp3', isError: true);
                  if (!mounted) return;
                  StoxSnackbar.erro(context, 'Quantidade inválida.');
                  return;
                }
                if (novoDeposito.isEmpty) {
                  await StoxAudio.play('sounds/error_beep.mp3', isError: true);
                  if (!mounted) return;
                  StoxSnackbar.aviso(context, 'Informe o depósito.');
                  return;
                }

                final db = await DatabaseHelper.instance.database;
                await db.update(
                  'contagens',
                  {
                    'quantidade':    novaQtd,
                    'warehouseCode': novoDeposito.toUpperCase(),
                    'dataHora':      DateTime.now().toIso8601String(),
                    'syncStatus':    0,
                  },
                  where:     'id = ?',
                  whereArgs: [item['id']],
                );

                await StoxAudio.play('sounds/check.mp3');
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(dialogCtx);
                await _carregarContagens();
                if (!mounted) return;
                StoxSnackbar.sucesso(context, 'Contagem atualizada!');
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_modoSelecao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _modoSelecao) _sairModoSelecao();
      },
      child: Scaffold(
        appBar: _modoSelecao
            ? _buildAppBarSelecao(theme)
            : _buildAppBarNormal(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_modoSelecao) ...[
                  _buildBannerOffline(theme),
                  const SizedBox(height: 24),
                  StoxTextField(
                    controller: _codigoController,
                    labelText: 'Código do Item',
                    prefixIcon: Icons.inventory_2_outlined,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ler com IA',
                          icon: Icon(Icons.auto_awesome_rounded,
                              color: theme.primaryColor),
                          onPressed: _escanearComIA,
                        ),
                        IconButton(
                          tooltip: 'Escanear código de barras',
                          icon: Icon(Icons.qr_code_scanner_rounded,
                              color: theme.primaryColor),
                          onPressed: _abrirScanner,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StoxTextField(
                    controller: _depositoController,
                    labelText: 'Depósito',
                    prefixIcon: Icons.warehouse_rounded,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    helperText: 'Código do depósito para esta contagem.',
                  ),
                  const SizedBox(height: 16),
                  _buildQuantidadeSelector(),
                  const SizedBox(height: 32),
                  StoxButton(
                    label: 'SALVAR CONTAGEM',
                    icon: Icons.save_rounded,
                    onPressed: _salvarContagem,
                  ),
                  const SizedBox(height: 40),
                ],
                _buildCabecalhoHistorico(theme),
                const SizedBox(height: 12),
                _buildListaContagens(),
                if (_modoSelecao) const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _modoSelecao && _selecionados.isNotEmpty
            ? StoxFab(
                label:
                    'Excluir ${_selecionados.length} ${_selecionados.length == 1 ? "item" : "itens"}',
                icon: Icons.delete_rounded,
                backgroundColor: Colors.red.shade600,
                onPressed: _excluirSelecionados,
              )
            : null,
      ),
    );
  }

  // ── Subwidgets do Build ───────────────────────────────────────────────────

  AppBar _buildAppBarNormal() => AppBar(
        title: const Text('Contagem Offline'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.share_rounded),
            onPressed: _exportarRelatorio,
          ),
        ],
      );

  AppBar _buildAppBarSelecao(ThemeData theme) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancelar seleção',
          onPressed: _sairModoSelecao,
        ),
        title: Text(
            '${_selecionados.length} selecionado${_selecionados.length != 1 ? 's' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: 'Selecionar todos',
            onPressed: _selecionarTodos,
          ),
        ],
      );

  Widget _buildBannerOffline(ThemeData theme) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Modo Offline: os dados ficam salvos localmente no aparelho.',
              style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );

  Widget _buildCabecalhoHistorico(ThemeData theme) => Row(children: [
        Icon(
          _modoSelecao ? Icons.checklist_rounded : Icons.history_rounded,
          color: _modoSelecao ? theme.primaryColor : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          _modoSelecao
              ? '${_selecionados.length} selecionado${_selecionados.length != 1 ? 's' : ''}'
              : 'Histórico Recente',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _modoSelecao ? theme.primaryColor : Colors.black87),
        ),
        const Spacer(),
        if (!_modoSelecao)
          Text('Segure para selecionar',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        if (_modoSelecao)
          TextButton(
            onPressed: _selecionarTodos,
            child: Text(
              _selecionados.length == _contagens.length
                  ? 'Desmarcar todos'
                  : 'Selecionar todos',
              style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
      ]);

  Widget _buildQuantidadeSelector() => StoxCard(
        child: Row(children: [
          InkWell(
            onTap: () => _ajustarQuantidade(-1),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(Icons.remove_rounded,
                  color: Colors.red.shade600, size: 28),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _quantidadeController,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onTap: () => HapticFeedback.selectionClick(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => _ajustarQuantidade(1),
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(Icons.add_rounded,
                  color: Colors.green.shade600, size: 28),
            ),
          ),
        ]),
      );

  Widget _buildListaContagens() {
    if (_iniciando) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Column(children: [
          StoxSkeletonCard(),
          StoxSkeletonCard(),
          StoxSkeletonCard(),
        ]),
      );
    }

    if (_contagens.isEmpty) {
      return StoxCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Nenhuma contagem registrada.',
                style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.separated(
        key: ValueKey(_contagens.length),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _contagens.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item        = _contagens[index];
          final syncStatus  = item['syncStatus'] ?? 0;
          final deposito    = item['warehouseCode'] ?? '01';
          final id          = item['id'] as int;
          final selecionado = _selecionados.contains(id);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selecionado ? Colors.red.shade400 : Colors.grey.shade300,
                width: selecionado ? 2 : 1,
              ),
              color: selecionado ? Colors.red.shade50 : Colors.white,
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _modoSelecao
                  ? Checkbox(
                      value: selecionado,
                      onChanged: (_) => _toggleSelecao(id),
                      activeColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    )
                  : CircleAvatar(
                      backgroundColor: syncStatus == 1
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      child: Icon(
                        syncStatus == 1
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_rounded,
                        color:
                            syncStatus == 1 ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
              title: Text(
                item['itemCode'],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: selecionado ? Colors.red.shade700 : Colors.black87),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Qtd: ${item['quantidade']}  •  Dep: $deposito',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ),
              trailing: _modoSelecao
                  ? null
                  : IconButton(
                      icon: Icon(Icons.edit_rounded,
                          color: Theme.of(context).primaryColor),
                      onPressed: () => _abrirEdicao(item),
                    ),
              onTap:      _modoSelecao ? () => _toggleSelecao(id) : null,
              onLongPress: _modoSelecao ? null : () => _entrarModoSelecao(id),
            ),
          );
        },
      ),
    );
  }
}

// ── Diálogo de confirmação de exclusão ───────────────────────────────────────

/// Exige digitação de "EXCLUIR" quando a seleção tem 3 ou mais itens.
class _DialogoConfirmacaoExclusao extends StatefulWidget {
  final int                         quantidade;
  final bool                        isTodosItens;
  final List<Map<String, dynamic>>  itens;

  const _DialogoConfirmacaoExclusao({
    required this.quantidade,
    required this.isTodosItens,
    required this.itens,
  });

  @override
  State<_DialogoConfirmacaoExclusao> createState() =>
      _DialogoConfirmacaoExclusaoState();
}

class _DialogoConfirmacaoExclusaoState
    extends State<_DialogoConfirmacaoExclusao> {
  final _confirmController = TextEditingController();
  bool  _confirmacaoValida = false;

  bool get _exigeDigitacao => widget.quantidade >= 3;

  @override
  void initState() {
    super.initState();
    if (_exigeDigitacao) {
      _confirmController.addListener(() {
        setState(() {
          _confirmacaoValida =
              _confirmController.text.trim().toUpperCase() == 'EXCLUIR';
        });
      });
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = !_exigeDigitacao || _confirmacaoValida;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.delete_forever_rounded,
              color: Colors.red.shade700, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.isTodosItens
                ? 'Excluir toda a contagem'
                : 'Excluir ${widget.quantidade} ${widget.quantidade == 1 ? 'item' : 'itens'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            StoxCard(
              padding: const EdgeInsets.all(12),
              borderColor: Colors.red.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.itens.take(5).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['itemCode'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              'Qtd: ${item['quantidade']}  •  Dep: ${item['warehouseCode'] ?? '01'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )),
                  if (widget.itens.length > 5) ...[
                    const SizedBox(height: 4),
                    Text('+ ${widget.itens.length - 5} itens...',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade400)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Esta ação não pode ser desfeita.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500),
            ),
            if (_exigeDigitacao) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Para confirmar, digite EXCLUIR no campo abaixo.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StoxTextField(
                controller: _confirmController,
                labelText: 'Digite EXCLUIR',
                textCapitalization: TextCapitalization.characters,
                suffixIcon: _confirmacaoValida
                    ? Icon(Icons.check_circle_rounded,
                        color: Colors.red.shade600)
                    : null,
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        StoxTextButton(
          label: 'CANCELAR',
          onPressed: () => Navigator.pop(context, false),
        ),
        ElevatedButton.icon(
          onPressed: habilitado
              ? () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context, true);
                }
              : null,
          icon: const Icon(Icons.delete_rounded, size: 16),
          label: Text(
            'EXCLUIR ${widget.quantidade}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}