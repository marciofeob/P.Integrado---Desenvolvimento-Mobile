import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stox/db/database_helper.dart';
import 'package:stox/services/export_service.dart';
import 'package:stox/services/ocr_service.dart';

class ContadorOfflinePage extends StatefulWidget {
  const ContadorOfflinePage({super.key});

  @override
  State<ContadorOfflinePage> createState() => _ContadorOfflinePageState();
}

class _ContadorOfflinePageState extends State<ContadorOfflinePage> {
  final _codigoController = TextEditingController();
  final _quantidadeController = TextEditingController(text: '1');
  // ✅ FIX: campo de depósito pré-preenchido pelo valor salvo nas configurações
  final _depositoController = TextEditingController(text: '01');
  final _focusNodeCodigo = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ✅ FIX: lista em estado — sem FutureBuilder (elimina rebuild excessivo e problema da key)
  List<Map<String, dynamic>> _contagens = [];
  bool _scannerProcessando = false;

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
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ FIX: carrega depósito padrão das configurações (evita hardcode "01")
  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    final deposito = prefs.getString('sap_deposito_padrao') ?? '01';
    if (mounted) {
      setState(() => _depositoController.text = deposito);
    }
  }

  // ✅ FIX: método centralizado — chamado no init e após toda mutação
  Future<void> _carregarContagens() async {
    final lista = await DatabaseHelper.instance.buscarContagens();
    if (mounted) setState(() => _contagens = lista);
  }

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      } else {
        isError ? HapticFeedback.vibrate() : HapticFeedback.lightImpact();
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir som ou vibrar: $e");
    }
  }

  void _ajustarQuantidade(double valor, {TextEditingController? controller}) {
    HapticFeedback.selectionClick();
    final targetController = controller ?? _quantidadeController;
    double atual =
        double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
    double novoValor = atual + valor;
    if (novoValor < 0) novoValor = 0;
    setState(() {
      targetController.text = novoValor % 1 == 0
          ? novoValor.toInt().toString()
          : novoValor.toStringAsFixed(2);
    });
  }

  Future<void> _exportarRelatorio() async {
    HapticFeedback.lightImpact();
    try {
      if (_contagens.isEmpty) {
        _mostrarMensagem('Nenhuma contagem para exportar!', isWarning: true);
        return;
      }
      await ExportService.exportarContagensParaCSV(_contagens);
      _mostrarMensagem('Relatório exportado com sucesso!', isSuccess: true);
    } catch (e) {
      _mostrarMensagem('Erro ao exportar: $e', isError: true);
    }
  }

  Future<void> _escanearComIA() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    _mostrarMensagem(
      'Abrindo câmera para leitura inteligente...',
      isSuccess: true,
    );

    final resultado = await OcrService.lerAnotacaoDaCamera();

    if (resultado != null) {
      setState(() {
        if (resultado['itemCode']!.isNotEmpty) {
          _codigoController.text = resultado['itemCode']!;
        }
        if (resultado['quantidade']!.isNotEmpty) {
          _quantidadeController.text = resultado['quantidade']!;
        }
      });
      await _tocarFeedback('sounds/beep.mp3');
      _mostrarMensagem('Leitura via IA concluída!', isSuccess: true);
      _focusNodeCodigo.nextFocus();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _abrirScanner() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _scannerProcessando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          LayoutBuilder(builder: (context, constraints) {
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, 200),
          width: 280,
          height: 180,
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
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
                AppBar(
                  title: const Text(
                    'Escanear Código',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(
                          scanWindow: scanWindow,
                          onDetect: (capture) async {
                            if (_scannerProcessando) return;
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              _scannerProcessando = true;
                              final code = barcodes.first.rawValue ?? "";
                              await _tocarFeedback('sounds/beep.mp3');

                              if (!mounted) return;
                              _codigoController.text = code;
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pop();
                              _focusNodeCodigo.nextFocus();
                            }
                          },
                        ),
                      ),
                      // ✅ FIX: withOpacity → withAlpha (compatível com qualquer versão Flutter)
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha(179), // era withOpacity(0.7)
                          BlendMode.srcOut,
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                backgroundBlendMode: BlendMode.dstOut,
                              ),
                            ),
                            Center(
                              child: Container(
                                width: scanWindow.width,
                                height: scanWindow.height,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: scanWindow.width,
                          height: scanWindow.height,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Alinhe o código de barras dentro do quadro",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _salvarContagem() async {
    final itemCode = _codigoController.text.trim();
    final quantidadeStr = _quantidadeController.text.trim();
    final deposito = _depositoController.text.trim();

    if (itemCode.isEmpty) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem('O código do item é obrigatório.', isWarning: true);
      return;
    }

    if (deposito.isEmpty) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem('Informe o código do depósito.', isWarning: true);
      return;
    }

    final quantidade =
        double.tryParse(quantidadeStr.replaceAll(',', '.'));
    if (quantidade == null || quantidade <= 0) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem(
        'Informe uma quantidade válida e maior que zero.',
        isError: true,
      );
      return;
    }

    try {
      // ✅ FIX: passa warehouseCode para o banco (depósito dinâmico)
      await DatabaseHelper.instance.inserirContagem(
        itemCode,
        quantidade,
        warehouseCode: deposito,
      );
      HapticFeedback.heavyImpact();
      await _tocarFeedback('sounds/check.mp3');
      _mostrarMensagem('Item $itemCode salvo com sucesso!', isSuccess: true);

      _codigoController.clear();
      _quantidadeController.text = '1';
      // ✅ FIX: recarrega lista de estado — sem FutureBuilder
      await _carregarContagens();
      _focusNodeCodigo.requestFocus();
    } catch (e) {
      await _tocarFeedback('sounds/fail.mp3', isError: true);
      _mostrarMensagem('Erro ao salvar: $e', isError: true);
    }
  }

  void _abrirEdicao(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    final editController = TextEditingController(
      text: item['quantidade'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Editar: ${item['itemCode']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ajuste a quantidade contada:',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 28,
                      ),
                      onPressed: () {
                        _ajustarQuantidade(-1, controller: editController);
                        setDialogState(() {});
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: editController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                      onPressed: () {
                        _ajustarQuantidade(1, controller: editController);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Text(
                'CANCELAR',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final novaQtd = double.tryParse(
                      editController.text.replaceAll(',', '.'),
                    ) ??
                    0;
                if (novaQtd <= 0) {
                  _mostrarMensagem('Quantidade inválida.', isError: true);
                  return;
                }
                await DatabaseHelper.instance
                    .atualizarContagem(item['id'], novaQtd);
                if (mounted) {
                  HapticFeedback.heavyImpact();
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                  await _carregarContagens(); // ✅ FIX: atualiza lista de estado
                  _mostrarMensagem('Quantidade atualizada!', isSuccess: true);
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExclusao(int id, String itemCode) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Excluir Registro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente remover a contagem do item $itemCode? Esta ação não pode ser desfeita.',
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'CANCELAR',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              await DatabaseHelper.instance.excluirContagem(id);
              if (mounted) {
                HapticFeedback.heavyImpact();
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                await _carregarContagens(); // ✅ FIX: atualiza lista de estado
                _mostrarMensagem(
                  'Registro removido com sucesso.',
                  isSuccess: true,
                );
              }
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }

  void _mostrarMensagem(
    String msg, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    Color bgColor = Colors.grey.shade800;
    IconData iconData = Icons.info_outline;

    if (isError) {
      bgColor = Colors.red.shade700;
      iconData = Icons.error_outline;
      HapticFeedback.vibrate();
    } else if (isSuccess) {
      bgColor = Colors.green.shade700;
      iconData = Icons.check_circle_outline;
    } else if (isWarning) {
      bgColor = Colors.orange.shade700;
      iconData = Icons.warning_amber_rounded;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contagem Offline'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.share_rounded),
            onPressed: _exportarRelatorio,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de modo offline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modo Offline: Os dados lidos nesta tela ficam salvos localmente no aparelho.',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Campo: Código do Item
              TextField(
                controller: _codigoController,
                focusNode: _focusNodeCodigo,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código do Item',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Ler com IA (Foto/Texto)',
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          color: theme.primaryColor,
                        ),
                        onPressed: _escanearComIA,
                      ),
                      IconButton(
                        tooltip: 'Ler Código de Barras',
                        icon: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: theme.primaryColor,
                        ),
                        onPressed: _abrirScanner,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ FIX: Campo de depósito — pré-preenchido com o padrão das configs
              TextField(
                controller: _depositoController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Depósito',
                  prefixIcon: Icon(Icons.warehouse_rounded),
                  helperText: 'Código do depósito para esta contagem.',
                ),
              ),
              const SizedBox(height: 16),

              // Seletor de quantidade
              _buildQuantidadeSelector(),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _salvarContagem,
                icon: const Icon(Icons.save_rounded),
                label: const Text('SALVAR CONTAGEM'),
              ),
              const SizedBox(height: 40),

              // Cabeçalho do histórico
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
                    'Histórico Recente',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Segure para excluir',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ✅ FIX: lista baseada em estado — sem FutureBuilder, sem key problem
              _buildListaContagens(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantidadeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _ajustarQuantidade(-1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.remove_rounded,
                color: Colors.red.shade600,
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _quantidadeController,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          InkWell(
            onTap: () => _ajustarQuantidade(1),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.add_rounded,
                color: Colors.green.shade600,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX: usa _contagens (estado) em vez de FutureBuilder
  Widget _buildListaContagens() {
    if (_contagens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhuma contagem registrada.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _contagens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _contagens[index];
        final syncStatus = item['syncStatus'] ?? 0;
        // ✅ FIX: exibe o depósito salvo em cada contagem
        final deposito = item['warehouseCode'] ?? '01';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: syncStatus == 1
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Icon(
                syncStatus == 1
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_upload_rounded,
                color: syncStatus == 1 ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              item['itemCode'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Qtd: ${item['quantidade']}  •  Dep: $deposito',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.edit_rounded,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () => _abrirEdicao(item),
            ),
            onLongPress: () =>
                _confirmarExclusao(item['id'], item['itemCode']),
          ),
        );
      },
    );
  }
}