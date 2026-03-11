import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:stox/db/database_helper.dart';
import 'package:stox/services/export_service.dart';

class ContadorOfflinePage extends StatefulWidget {
  const ContadorOfflinePage({super.key});

  @override
  State<ContadorOfflinePage> createState() => _ContadorOfflinePageState();
}

class _ContadorOfflinePageState extends State<ContadorOfflinePage> {
  final _codigoController = TextEditingController();
  final _quantidadeController = TextEditingController(text: '1');
  final _focusNodeCodigo = FocusNode();
  final Color primaryColor = const Color(0xFF0A6ED1);
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _scannerProcessando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _quantidadeController.dispose();
    _focusNodeCodigo.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir som: $e");
    }
  }

  void _ajustarQuantidade(double valor, {TextEditingController? controller}) {
    final targetController = controller ?? _quantidadeController;
    double atual = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
    double novoValor = atual + valor;
    if (novoValor < 0) novoValor = 0;
    setState(() {
      targetController.text = novoValor % 1 == 0
          ? novoValor.toInt().toString()
          : novoValor.toStringAsFixed(2);
    });
  }

  Future<void> _exportarRelatorio() async {
    try {
      final contagens = await DatabaseHelper.instance.buscarContagens();
      if (contagens.isEmpty) {
        _mostrarMensagem('Nenhuma contagem para exportar!', Colors.orange);
        return;
      }
      await ExportService.exportarContagensParaCSV(contagens);
    } catch (e) {
      _mostrarMensagem('Erro ao exportar: $e', Colors.red);
    }
  }

  void _abrirScanner() {
    _scannerProcessando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutBuilder(builder: (context, constraints) {
        // Área de captura idêntica à ItemSearchPage
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, 200),
          width: 250,
          height: 150,
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, color: Colors.grey[300]),
                AppBar(
                  title: const Text('Escanear Código'),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      MobileScanner(
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
                            Navigator.of(context).pop();
                            // Após fechar, foca na quantidade para agilizar
                            _focusNodeCodigo.nextFocus();
                          }
                        },
                      ),
                      // Overlay de Máscara
                      _buildScannerOverlay(scanWindow),
                      // Borda Branca da área de leitura
                      Center(
                        child: Container(
                          width: scanWindow.width,
                          height: scanWindow.height,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("Alinhe o código de barras dentro do quadro",
                      style: TextStyle(color: Colors.grey)),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildScannerOverlay(Rect scanWindow) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.6), BlendMode.srcOut),
      child: Stack(
        children: [
          Container(color: Colors.black),
          Center(
            child: Container(
              width: scanWindow.width,
              height: scanWindow.height,
              decoration: BoxDecoration(
                color: Colors.red, // Cor irrelevante devido ao BlendMode.srcOut
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarContagem() async {
    final itemCode = _codigoController.text.trim();
    final quantidadeStr = _quantidadeController.text.trim();

    if (itemCode.isEmpty) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem('O código é obrigatório!', Colors.orange);
      return;
    }

    final quantidade = double.tryParse(quantidadeStr.replaceAll(',', '.'));
    if (quantidade == null || quantidade <= 0) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem('Quantidade inválida!', Colors.red);
      return;
    }

    try {
      await DatabaseHelper.instance.inserirContagem(itemCode, quantidade);
      _mostrarMensagem('Item $itemCode salvo!', Colors.green);
      _codigoController.clear();
      _quantidadeController.text = '1';
      setState(() {});
      _focusNodeCodigo.requestFocus();
    } catch (e) {
      _mostrarMensagem('Erro: $e', Colors.red);
    }
  }

  // ... (Mantenha as funções _abrirEdicao, _confirmarExclusao e _mostrarMensagem iguais)

  void _abrirEdicao(Map<String, dynamic> item) {
    final editController = TextEditingController(text: item['quantidade'].toString());
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar: ${item['itemCode']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ajuste a quantidade:'),
              const SizedBox(height: 15),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      _ajustarQuantidade(-1, controller: editController);
                      setDialogState(() {});
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: editController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () {
                      _ajustarQuantidade(1, controller: editController);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('VOLTAR')),
            ElevatedButton(
              onPressed: () async {
                final novaQtd = double.tryParse(editController.text) ?? 0;
                await DatabaseHelper.instance.atualizarContagem(item['id'], novaQtd);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  _mostrarMensagem('Atualizado!', Colors.green);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: Text('Deseja remover a contagem do item $itemCode?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.excluirContagem(id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                _mostrarMensagem('Registro removido', Colors.blueGrey);
              }
            },
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contagem Offline'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.share),
            onPressed: _exportarRelatorio,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Modo Offline: Dados salvos localmente.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _codigoController,
              focusNode: _focusNodeCodigo,
              decoration: InputDecoration(
                labelText: 'Código do Item',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _abrirScanner,
                ),
              ),
            ),
            const SizedBox(height: 25),
            _buildQuantidadeSelector(),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _salvarContagem,
                child: const Text('SALVAR CONTAGEM'),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Histórico Recente',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Divider(),
            _buildListaContagens(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantidadeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _ajustarQuantidade(-1),
          ),
          Expanded(
            child: TextField(
              controller: _quantidadeController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: InputBorder.none),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () => _ajustarQuantidade(1),
          ),
        ],
      ),
    );
  }

  Widget _buildListaContagens() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.buscarContagens(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhuma contagem.');
        final itens = snapshot.data!.reversed.toList();
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itens.length > 10 ? 10 : itens.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = itens[index];
            return ListTile(
              title: Text(item['itemCode'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Qtd: ${item['quantidade']}'),
              trailing: const Icon(Icons.edit_note, color: Colors.blueGrey),
              onTap: () => _abrirEdicao(item),
              onLongPress: () => _confirmarExclusao(item['id'], item['itemCode']),
            );
          },
        );
      },
    );
  }
}