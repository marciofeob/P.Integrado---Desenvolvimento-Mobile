import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _carregarDadosLocais();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosLocais() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    if (mounted) {
      setState(() => _contagensOffline = dados);
    }
  }

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 400]);
        } else {
          Vibration.vibrate(duration: 300);
        }
      } else {
        isError ? HapticFeedback.vibrate() : HapticFeedback.heavyImpact();
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir feedback: $e");
    }
  }

  Future<void> _sincronizarComSAP() async {
    if (_contagensOffline.isEmpty) return;
    
    HapticFeedback.lightImpact();
    setState(() => _carregando = true);
    
    try {
      final erro = await SapService.postInventoryCounting(_contagensOffline);
      
      if (erro == null) {
        await _tocarFeedback('sounds/check.mp3');
        
        // Limpa os dados se a sincronização for 100% bem-sucedida
        await DatabaseHelper.instance.limparContagens();
        await _carregarDadosLocais();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Sincronização concluída com sucesso!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Erro: $e', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _exibirErroSap(String mensagemBruta) {
    bool isItemDuplicado =
        mensagemBruta.contains("-1310") ||
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isItemDuplicado ? Icons.warning_amber_rounded : Icons.error_outline,
              color: isItemDuplicado ? Colors.orange.shade700 : Colors.red.shade700,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isItemDuplicado ? "Conflito de Itens" : "Erro na API",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Problema na sincronização:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                isItemDuplicado
                    ? "O SAP informou que o item ${itemEncontrado.isNotEmpty ? itemEncontrado : 'selecionado'} já possui uma contagem aberta e não finalizada."
                    : "Ocorreu um erro ao processar os dados enviados para o SAP Business One.",
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Log Técnico do SAP:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  mensagemBruta,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isItemDuplicado ? Colors.orange.shade700 : Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("ENTENDI", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO: O Scaffold fica na raiz e a SafeArea protege apenas o corpo (body).
    // Isso evita o corte visual superior, preenchendo a barra de status com a cor do AppBar.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel STOX", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _carregarDadosLocais();
            },
            tooltip: "Recarregar Dados",
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
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
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      // Padding flexível para evitar cortes (removido o limite rígido de altura)
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3), 
            blurRadius: 12, 
            offset: const Offset(0, 6)
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Garante que a coluna ocupe apenas o espaço necessário
        children: [
          const Text(
            "Itens aguardando envio",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "${_contagensOffline.length}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          // Botão adaptado para preencher de forma segura e responsiva
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _carregando || _contagensOffline.isEmpty
                  ? null
                  : _sincronizarComSAP,
              icon: _carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: const Text("SINCRONIZAR AGORA", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContagensList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80), // Padding extra no fundo para a navegação segura
      itemCount: _contagensOffline.length,
      itemBuilder: (context, index) {
        final item = _contagensOffline[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              radius: 22,
              child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).primaryColor, size: 22),
            ),
            title: Text(
              "${item['itemCode']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("Quantidade lida: ${item['quantidade']}", style: TextStyle(color: Colors.grey.shade700)),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              onPressed: () async {
                HapticFeedback.vibrate();
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_done_rounded, size: 64, color: Colors.green.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            "Tudo sincronizado!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            "Não há contagens pendentes para envio.",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

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
            accountName: const Text("Operador STOX", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                SizedBox(width: 6),
                Text("SAP Business One Conectado"),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.add_box_rounded, color: theme.primaryColor),
                  title: const Text("Nova Contagem Offline", style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContadorOfflinePage(),
                      ),
                    ).then((_) => _carregarDadosLocais());
                  },
                ),
                ListTile(
                  leading: Icon(Icons.search_rounded, color: theme.primaryColor),
                  title: const Text("Pesquisar Item SAP", style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ItemSearchPage()),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
                ListTile(
                  leading: Icon(Icons.settings_rounded, color: Colors.grey.shade600),
                  title: Text("Configurações da API", style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApiConfigPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text("Sair da Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              HapticFeedback.heavyImpact();
              await SapService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (r) => false,
              );
            },
          ),
          const SizedBox(height: 24), // Área segura na base do drawer
        ],
      ),
    );
  }
}