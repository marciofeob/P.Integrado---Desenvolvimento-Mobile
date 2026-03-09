import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:stox/db/database_helper.dart';

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
  
  // Variável para evitar múltiplas leituras e erros de navegação
  bool _scannerProcessando = false;

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
      targetController.text = novoValor % 1 == 0 ? novoValor.toInt().toString() : novoValor.toStringAsFixed(2);
    });
  }

  void _abrirScanner() {
    _scannerProcessando = false;
    
    // Define o tamanho da janela de leitura (ex: 250x150)
    final scanWindow = Rect.fromCenter(
      center: Offset(MediaQuery.of(context).size.width / 2, (MediaQuery.of(context).size.height * 0.7) / 2 - 50),
      width: 250,
      height: 150,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, color: Colors.grey[300]),
            AppBar(
              title: const Text('Aponte para o Código'), 
              centerTitle: true, 
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    scanWindow: scanWindow, // Limita a área de leitura
                    onDetect: (capture) async {
                      if (_scannerProcessando) return;
                      
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        _scannerProcessando = true;
                        final code = barcodes.first.rawValue ?? "";
                        
                        await _tocarFeedback('sounds/beep.mp3');
                        
                        if (!mounted) return;
                        setState(() => _codigoController.text = code);
                        
                        // Fecha apenas o modal do scanner
                        Navigator.of(context).pop(); 
                        
                        // Foca na quantidade após um breve delay
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) _focusNodeCodigo.nextFocus();
                        });
                      }
                    },
                  ),
                  // Overlay para escurecer o que está fora da janela de leitura
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(color: Colors.black),
                        Center(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Moldura da janela
                  Center(
                    child: Container(
                      width: scanWindow.width,
                      height: scanWindow.height,
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Alinhe o código dentro do retângulo azul"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _salvarContagem() async {
    final itemCode = _codigoController.text.trim();
    final quantidadeStr = _quantidadeController.text.trim();
    
    if (itemCode.isEmpty || quantidadeStr.isEmpty) { 
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      _mostrarMensagem('Preencha todos os campos!', Colors.orange); 
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

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(seconds: 2)));
  }

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
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () { _ajustarQuantidade(-1, controller: editController); setDialogState(() {}); }),
                  Expanded(child: TextField(controller: editController, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () { _ajustarQuantidade(1, controller: editController); setDialogState(() {}); }),
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
                Navigator.pop(context);
                setState(() {});
                _mostrarMensagem('Atualizado com sucesso!', Colors.green);
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
              Navigator.pop(context);
              setState(() {});
              _mostrarMensagem('Registro removido', Colors.blueGrey);
            },
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contagem Offline (STOX)'), backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Modo Offline: Os dados ficam no dispositivo.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 25),
            TextField(
              controller: _codigoController,
              focusNode: _focusNodeCodigo,
              decoration: InputDecoration(
                labelText: 'Código do Item',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2), borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _abrirScanner),
              ),
            ),
            const SizedBox(height: 25),
            const Text('Quantidade', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _ajustarQuantidade(-1)),
                  Expanded(child: TextField(controller: _quantidadeController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _ajustarQuantidade(1)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _salvarContagem,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                child: const Text('SALVAR CONTAGEM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
            const Row(children: [Icon(Icons.history, size: 18, color: Colors.grey), SizedBox(width: 8), Text('Histórico Recente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]),
            const Divider(),
            _buildListaContagens(),
          ],
        ),
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
          itemCount: itens.length > 5 ? 5 : itens.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = itens[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.inventory_2_outlined, color: primaryColor),
              title: Text(item['itemCode'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Quantidade: ${item['quantidade']}'),
              trailing: const Icon(Icons.edit_note, color: Colors.grey),
              onTap: () => _abrirEdicao(item),
              onLongPress: () => _confirmarExclusao(item['id'], item['itemCode']),
            );
          },
        );
      },
    );
  }
}