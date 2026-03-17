import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sap_service.dart';
import '../widgets/widgets.dart';
import 'api_config_page.dart';
import 'home_page.dart';
import 'contador_offline_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuarioController = TextEditingController();
  final _senhaController   = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // ─── AÇÕES ─────────────────────────────────────────────────────────────────

  void _limparCampos() {
    HapticFeedback.selectionClick();
    setState(() {
      _usuarioController.clear();
      _senhaController.clear();
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final prefs     = await SharedPreferences.getInstance();
    final sapUrl    = prefs.getString('sap_url');
    final companyDb = prefs.getString('sap_company');

    if (sapUrl == null || sapUrl.isEmpty ||
        companyDb == null || companyDb.isEmpty) {
      // ignore: use_build_context_synchronously
      StoxSnackbar.aviso(context, 'Configure a API SAP antes de prosseguir.');
      return;
    }

    if (_usuarioController.text.isEmpty || _senhaController.text.isEmpty) {
      // ignore: use_build_context_synchronously
      StoxSnackbar.aviso(context, 'Usuário e senha são obrigatórios.');
      return;
    }

    setState(() => _carregando = true);
    try {
      final sucesso = await SapService.login(
        usuario: _usuarioController.text.trim(),
        senha:   _senhaController.text,
      );

      if (!sucesso) {
        // ignore: use_build_context_synchronously
        StoxSnackbar.erro(context, 'Credenciais inválidas.');
        return;
      }

      HapticFeedback.heavyImpact();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      StoxSnackbar.erro(context, 'Erro de conexão com o servidor SAP.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(height: size.height * 0.08),
                    Image.asset('assets/images/Logo_colorida.png', height: 80),
                    const SizedBox(height: 24),
                    const Text('Contagem de Estoque',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Informe seu usuário e senha do SAP',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 40),

                    // ── Usuário ──
                    StoxTextField(
                      controller: _usuarioController,
                      labelText: 'Usuário',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // ── Senha ──
                    StoxPasswordField(
                      controller: _senhaController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: StoxTextButton(
                        label: 'Limpar',
                        onPressed: _limparCampos,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Entrar ──
                    StoxButton(
                      label: 'ENTRAR E SINCRONIZAR',
                      loading: _carregando,
                      onPressed: _login,
                    ),

                    const SizedBox(height: 16),

                    // ── Modo offline ──
                    StoxOutlinedButton(
                      label: 'MODO CONTADOR OFFLINE',
                      icon: Icons.qr_code_scanner,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContadorOfflinePage()),
                      ),
                    ),

                    const Spacer(),

                    // ── Configurações ──
                    StoxTextButton(
                      label: 'Configurações da API',
                      icon: Icons.settings,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ApiConfigPage()),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Image.asset('assets/images/sap-logo.png', height: 20),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}