import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final _urlController = TextEditingController();
  final _companyController = TextEditingController();
  bool _permitirSslInseguro = true;
  final Color primaryColor = const Color(0xFF0A6ED1);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('sap_url') ?? '';
      _companyController.text = prefs.getString('sap_company') ?? '';
      _permitirSslInseguro = prefs.getBool('sap_allow_untrusted') ?? true;
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_url', _urlController.text.trim());
    await prefs.setString('sap_company', _companyController.text.trim());
    await prefs.setBool('sap_allow_untrusted', _permitirSslInseguro);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Configurações salvas!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuração SAP"),
        // O StoxTheme já cuida das cores, mas mantivemos aqui para garantir consistência
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Conexão Service Layer",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ajuste os endereços para sincronização com o SAP Business One.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "Service Layer URL",
                  hintText: "https://servidor:50000/b1s/v1",
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: "CompanyDB",
                  hintText: "SBODemoBR",
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 25),
              
              // Container para o Switch para dar um visual de "Card"
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile.adaptive(
                  title: const Text(
                    "Permitir SSL pré-assinado",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "Ative se o servidor SAP usar certificado auto-assinado (comum em dev/test).",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _permitirSslInseguro,
                  activeColor: primaryColor,
                  onChanged: (bool value) {
                    setState(() {
                      _permitirSslInseguro = value;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveConfig,
                  child: const Text(
                    "SALVAR CONFIGURAÇÕES",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              // Padding extra no final para garantir que o botão não cole na barra de navegação
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}