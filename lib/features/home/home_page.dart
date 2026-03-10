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
          const SnackBar(
              content: Text('Sincronização concluída!'),
              backgroundColor: Colors.green),
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

  // MÉTODO DE ERRO - EXIBE JSON TÉCNICO + MENSAGEM AMIGÁVEL
  void _exibirErroSap(String mensagemBruta) {
    // 1. Identifica se é erro de duplicidade (Contagem aberta no SAP)
    bool isItemDuplicado = mensagemBruta.contains("-1310") ||
        mensagemBruta.contains("1470000497") ||
        mensagemBruta.toLowerCase().contains("already");

    // 2. Procura qual item da nossa lista local causou o erro na API
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
              const Text("Problema na sincronização:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(isItemDuplicado
                  ? "O SAP informou que o item ${itemEncontrado.isNotEmpty ? itemEncontrado : 'selecionado'} já possui uma contagem aberta e não pode ser enviado novamente."
                  : "Ocorreu um erro ao processar os dados no SAP."),
              const SizedBox(height: 16),
              const Text("O que fazer?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(itemEncontrado.isNotEmpty
                  ? "• Remova o item $itemEncontrado (lixeira) e tente enviar novamente."
                  : "• Verifique a lista de contagens ou contate o suporte TI."),
              const SizedBox(height: 20),
              const Divider(),
              const Text("Dados brutos da API (Técnico):",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey[300]!)),
                child: Text(
                  mensagemBruta,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ENTENDI",
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel STOX"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDadosLocais,
          ),
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
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("Itens aguardando envio",
              style: TextStyle(color: Colors.white70)),
          Text(
            "${_contagensOffline.length}",
            style: const TextStyle(
                color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _carregando || _contagensOffline.isEmpty
                  ? null
                  : _sincronizarComSAP,
              icon: _carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: const Text("SINCRONIZAR AGORA"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
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
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF0A6ED1), size: 40),
            ),
            accountName: const Text("Operador STOX",
                style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Conectado ao SAP Business One"),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SectionHeader(title: "OPERACIONAL"),
                ListTile(
                  leading: Icon(Icons.add_box_outlined, color: primaryColor),
                  title: const Text("Nova Contagem Offline"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ContadorOfflinePage()))
                        .then((_) => _carregarDadosLocais());
                  },
                ),
                const Divider(),
                const _SectionHeader(title: "CONSULTAS & RELATÓRIOS"),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.orange),
                  title: const Text("Pesquisar Item SAP"),
                  subtitle: const Text("Estoque, Detalhes e Etiquetas"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ItemSearchPage()));
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Configurações API"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ApiConfigPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sair", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await SapService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContagensList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contagensOffline.length,
      itemBuilder: (context, index) {
        final item = _contagensOffline[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(Icons.inventory_2, color: primaryColor),
            title: Text("${item['itemCode']}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Tudo em dia!",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: const TextStyle(
              color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}