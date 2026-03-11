import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../db/database_helper.dart';
import '../../services/sap_service.dart';
import '../auth/login_page.dart';
import '../contador/contador_offline_page.dart';
import '../config/api_config_page.dart';
import '../consultas/item_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagensOffline = [];
  bool _carregando = false;
  final Color primaryColor = const Color(0xFF0A6ED1);
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _carregarDadosLocais();
  }

  Future<void> _carregarDadosLocais() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    setState(() => _contagensOffline = dados);
  }

  // ... (seus métodos _tocarFeedback, _sincronizarComSAP e _exibirErroSap permanecem iguais)
  // Vou focar no BUILD que é onde o problema de corte acontece.

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 400]);
        } else {
          Vibration.vibrate(duration: 300);
        }
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir feedback: $e");
    }
  }

  Future<void> _sincronizarComSAP() async {
    if (_contagensOffline.isEmpty) return;
    setState(() => _carregando = true);
    try {
      final erro = await SapService.postInventoryCounting(_contagensOffline);
      if (erro == null) {
        await _tocarFeedback('sounds/check.mp3');
        await DatabaseHelper.instance.limparContagens();
        await _carregarDadosLocais();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronização concluída!'), backgroundColor: Colors.green),
        );
      } else {
        await _tocarFeedback('sounds/fail.mp3', isError: true);
        if (!mounted) return;
        _exibirErroSap(erro);
      }
    } catch (e) {
      await _tocarFeedback('sounds/fail.mp3', isError: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _exibirErroSap(String mensagemBruta) {
    bool isItemDuplicado = mensagemBruta.contains("-1310") ||
        mensagemBruta.contains("1470000497") ||
        mensagemBruta.toLowerCase().contains("already");

    String itemEncontrado = "";
    for (var contagem in _contagensOffline) {
      String codigo = contagem['itemCode'].toString().trim();
      if (mensagemBruta.toUpperCase().contains(codigo.toUpperCase())) {
        itemEncontrado = codigo;
        break;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(isItemDuplicado ? Icons.warning_amber_rounded : Icons.error_outline,
                color: isItemDuplicado ? Colors.orange : Colors.red),
            const SizedBox(width: 10),
            Text(isItemDuplicado ? "Conflito de Itens" : "Erro na API"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Problema na sincronização:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(isItemDuplicado
                  ? "O SAP informou que o fardo ${itemEncontrado.isNotEmpty ? itemEncontrado : 'selecionado'} já possui uma contagem aberta."
                  : "Ocorreu um erro ao processar os dados no SAP."),
              const SizedBox(height: 20),
              const Divider(),
              Text(mensagemBruta, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.blueGrey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDI")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Usamos SafeArea para garantir que nada fique embaixo das barras de navegação do sistema
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Painel STOX"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _carregarDadosLocais),
          ],
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            _buildSummaryHeader(),
            Expanded(
              child: _contagensOffline.isEmpty
                  ? _buildEmptyState()
                  : _buildContagensList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("Fardos aguardando envio", style: TextStyle(color: Colors.white70)),
          Text(
            "${_contagensOffline.length}",
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Botão de Sincronizar com largura adaptável
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _carregando || _contagensOffline.isEmpty ? null : _sincronizarComSAP,
                icon: _carregando 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
                label: const Text("SINCRONIZAR AGORA"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContagensList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding inferior para não colar na base
      itemCount: _contagensOffline.length,
      itemBuilder: (context, index) {
        final item = _contagensOffline[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(Icons.inventory_2, color: primaryColor),
            title: Text("${item['itemCode']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Quantidade: ${item['quantidade']}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                await DatabaseHelper.instance.excluirContagem(item['id']);
                _carregarDadosLocais();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey),
          Text("Tudo em dia!", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
            accountName: const Text("Operador STOX"),
            accountEmail: const Text("SAP Business One Conectado"),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_box_outlined),
                  title: const Text("Nova Contagem Offline"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ContadorOfflinePage()))
                        .then((_) => _carregarDadosLocais());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text("Pesquisar Item SAP"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemSearchPage()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text("Configurações API"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiConfigPage()));
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sair", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await SapService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}