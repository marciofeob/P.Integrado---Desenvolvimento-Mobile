import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _limparCampos() {
    _usuarioController.clear();
    _senhaController.clear();
  }

  void _sairApp() {
    SystemNavigator.pop();
  }

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    final sapUrl = prefs.getString('sap_url');
    final companyDb = prefs.getString('sap_company');

    if (sapUrl == null || sapUrl.isEmpty) {
      _mostrarErro(
          "Service Layer não configurada. Acesse Configurações e informe a URL do servidor SAP.");
      return;
    }

    if (companyDb == null || companyDb.isEmpty) {
      _mostrarErro(
          "Banco de dados (CompanyDB) não configurado. Verifique as configurações do SAP.");
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
        _mostrarErro(
            "Não foi possível realizar o login. Verifique suas credenciais ou entre em contato com o TI.");
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      _mostrarErro(
          "Erro de conexão com o servidor SAP. Verifique sua rede ou contate o TI.");
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(mensagem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              Image.asset(
                "assets/images/Logo_colorida.png",
                height: 70,
              ),

              const SizedBox(height: 24),

              const Text(
                "Contagem de Estoque",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Informe seu usuário e senha do SAP",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 40),

              // Campos de Usuário e Senha
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Usuário"),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Senha"),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _senhaController,
                obscureText: _ocultarSenha,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarSenha
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _ocultarSenha = !_ocultarSenha;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _limparCampos,
                  child: const Text("Limpar"),
                ),
              ),

              const SizedBox(height: 10),

              // Botão de Entrar (Login SAP)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A6ED1),
                  ),
                  onPressed: _carregando ? null : _login,
                  child: _carregando
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          "Entrar e Sincronizar",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão de Modo Contador Offline
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0A6ED1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Agora navega de verdade para a tela offline
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContadorOfflinePage()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0A6ED1)),
                  label: const Text(
                    "Modo Contador Offline",
                    style: TextStyle(
                      color: Color(0xFF0A6ED1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _sairApp,
                child: const Text("Cancelar"),
              ),

              const SizedBox(height: 20),

              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ApiConfigPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text("Configurações da API"),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}