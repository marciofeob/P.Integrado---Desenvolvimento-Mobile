import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sap_service.dart';
import '../config/api_config_page.dart';
import '../home/home_page.dart';
import '../contador/contador_offline_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuarioController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;
  final Color primaryColor = const Color(0xFF0A6ED1);

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _limparCampos() => setState(() {
    _usuarioController.clear();
    _senhaController.clear();
  });

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    final sapUrl = prefs.getString('sap_url');
    final companyDb = prefs.getString('sap_company');

    if (sapUrl == null || sapUrl.isEmpty || companyDb == null || companyDb.isEmpty) {
      _mostrarErro("Configure a API SAP antes de prosseguir.");
      return;
    }

    if (_usuarioController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarErro("Usuário e senha são obrigatórios.");
      return;
    }

    setState(() => _carregando = true);
    try {
      final sucesso = await SapService.login(
        usuario: _usuarioController.text,
        senha: _senhaController.text,
      );

      if (!sucesso) {
        _mostrarErro("Credenciais inválidas.");
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      _mostrarErro("Erro de conexão com o servidor SAP.");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pegamos o tamanho da tela para cálculos de responsividade
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      // SafeArea no topo para o Scaffold inteiro
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              // ConstrainedBox garante que a Column ocupe pelo menos a altura da tela
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(height: size.height * 0.08), // Espaçamento proporcional
                      Image.asset("assets/images/Logo_colorida.png", height: 80),
                      const SizedBox(height: 24),
                      const Text(
                        "Contagem de Estoque",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Informe seu usuário e senha do SAP",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      
                      // Campos de Texto
                      TextField(
                        controller: _usuarioController,
                        decoration: InputDecoration(
                          labelText: "Usuário",
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                        ),
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _limparCampos,
                          child: const Text("Limpar", style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // Botão Principal (Ação mais importante)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _login,
                          child: _carregando
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("ENTRAR E SINCRONIZAR"),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Botão Offline
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ContadorOfflinePage()),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text("MODO CONTADOR OFFLINE"),
                        ),
                      ),
                      
                      const Spacer(), // Empurra os itens abaixo para o rodapé
                      
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ApiConfigPage()),
                        ),
                        icon: const Icon(Icons.settings, color: Colors.grey),
                        label: const Text("Configurações da API", style: TextStyle(color: Colors.grey)),
                      ),
                      
                      const SizedBox(height: 20),
                      Image.asset("assets/images/sap-logo.png", height: 20),
                      const SizedBox(height: 16), // Padding extra para evitar toque na barra de navegação
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}