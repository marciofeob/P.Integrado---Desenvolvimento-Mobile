import 'package:flutter/material.dart';
import '../../db/database_helper.dart';

class ContadorOfflinePage extends StatefulWidget {
  const ContadorOfflinePage({super.key});

  @override
  State<ContadorOfflinePage> createState() => _ContadorOfflinePageState();
}

class _ContadorOfflinePageState extends State<ContadorOfflinePage> {
  final _codigoController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _focusNodeCodigo = FocusNode();

  Future<void> _salvarContagem() async {
    final itemCode = _codigoController.text.trim();
    final quantidadeStr = _quantidadeController.text.trim();

    if (itemCode.isEmpty || quantidadeStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o código e a quantidade!'), backgroundColor: Colors.red),
      );
      return;
    }

    final quantidade = double.tryParse(quantidadeStr.replaceAll(',', '.'));
    if (quantidade == null || quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade inválida!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Salva no banco de dados local (SQLite)
    await DatabaseHelper.instance.inserirContagem(itemCode, quantidade);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item $itemCode salvo com sucesso!'), backgroundColor: Colors.green),
    );

    // Limpa os campos para a próxima leitura
    _codigoController.clear();
    _quantidadeController.clear();
    
    // Volta o foco para o campo de código (ideal para quem usa leitor bluetooth/câmera)
    FocusScope.of(context).requestFocus(_focusNodeCodigo);
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _quantidadeController.dispose();
    _focusNodeCodigo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contagem Offline'),
        backgroundColor: const Color(0xFF0A6ED1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'As contagens feitas aqui serão salvas no celular. Você precisará fazer login depois para enviar ao SAP.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: _codigoController,
              focusNode: _focusNodeCodigo,
              decoration: InputDecoration(
                labelText: 'Código do Item (ItemCode)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    // TODO: Chamar o leitor de código de barras pela câmera
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Câmera em breve!')),
                    );
                  },
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            
            const SizedBox(height: 20),
            
            TextField(
              controller: _quantidadeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _salvarContagem(),
            ),
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: _salvarContagem,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A6ED1),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Salvar Contagem', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}