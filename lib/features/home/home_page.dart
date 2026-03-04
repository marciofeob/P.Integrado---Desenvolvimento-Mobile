import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../services/sap_service.dart';
import '../auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagensOffline = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosLocais();
  }

  // Busca o que foi salvo no SQLite
  Future<void> _carregarDadosLocais() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    setState(() {
      _contagensOffline = dados;
    });
  }

  // Envia tudo para o SAP Service Layer
  Future<void> _sincronizarComSAP() async {
    if (_contagensOffline.isEmpty) return;

    setState(() => _carregando = true);

    try {
      // Chama o método que criamos no SapService
      final sucesso = await SapService.postInventoryCounting(_contagensOffline);

      if (sucesso) {
        // Se o SAP aceitar, apagamos o banco local
        await DatabaseHelper.instance.limparContagens();
        await _carregarDadosLocais();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronização concluída com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar para o SAP. Tente novamente.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel de Sincronização"),
        backgroundColor: const Color(0xFF0A6ED1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SapService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Itens aguardando envio: ${_contagensOffline.length}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _carregando || _contagensOffline.isEmpty ? null : _sincronizarComSAP,
                  icon: _carregando 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text("Sincronizar", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: _contagensOffline.isEmpty
                ? const Center(
                    child: Text("Nenhuma contagem offline pendente.", style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _contagensOffline.length,
                    itemBuilder: (context, index) {
                      final item = _contagensOffline[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0A6ED1),
                          child: Icon(Icons.inventory, color: Colors.white, size: 20),
                        ),
                        title: Text("Item: ${item['itemCode']}"),
                        subtitle: Text("Quantidade: ${item['quantidade']}"),
                        trailing: const Icon(Icons.warning, color: Colors.orange, size: 20),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}