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

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _limparCampos() {
    HapticFeedback.selectionClick();
    setState(() {
      _usuarioController.clear();
      _senhaController.clear();
    });
  }

  Future<void> _login() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus(); // Recolhe o teclado ao tentar logar

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

      HapticFeedback.heavyImpact(); // Confirmação de sucesso

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
    HapticFeedback.vibrate(); // Feedback tátil para erro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(height: size.height * 0.08),
                      Image.asset("assets/images/Logo_colorida.png", height: 80),
                      const SizedBox(height: 24),
                      const Text(
                        "Contagem de Estoque",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Informe seu usuário e senha do SAP",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 40),
                      
                      TextField(
                        controller: _usuarioController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: "Usuário",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _ocultarSenha = !_ocultarSenha);
                            },
                          ),
                        ),
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _limparCampos,
                          child: Text("Limpar", style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _carregando ? null : _login,
                        child: _carregando
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text("ENTRAR E SINCRONIZAR"),
                      ),
                      
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ContadorOfflinePage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54), // Padronizado com o ElevatedButton do tema
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: theme.primaryColor, width: 1.5),
                          foregroundColor: theme.primaryColor,
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text(
                          "MODO CONTADOR OFFLINE",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ApiConfigPage()),
                          );
                        },
                        icon: Icon(Icons.settings, color: Colors.grey.shade600),
                        label: Text("Configurações da API", style: TextStyle(color: Colors.grey.shade600)),
                      ),
                      
                      const SizedBox(height: 20),
                      Image.asset("assets/images/sap-logo.png", height: 20),
                      const SizedBox(height: 24),
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