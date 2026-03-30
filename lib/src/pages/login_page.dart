import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_stox.dart';
import '../services/sap_service.dart';
import '../widgets/widgets.dart';
import 'api_config_page.dart';
import 'home_page.dart';
import 'contador_offline_page.dart';

/// Tela de autenticação do STOX.
///
/// Valida as credenciais contra o SAP Business One via [SapService.login].
/// Oferece acesso ao modo offline sem autenticação.
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

  // ── Ações ─────────────────────────────────────────────────────────────────

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
    final sapUrl    = prefs.getString('sap_url')     ?? '';
    final companyDb = prefs.getString('sap_company') ?? '';

    if (!mounted) return;

    if (sapUrl.isEmpty || companyDb.isEmpty) {
      StoxSnackbar.aviso(context, 'Configure a API SAP antes de prosseguir.');
      return;
    }

    if (_usuarioController.text.isEmpty || _senhaController.text.isEmpty) {
      StoxSnackbar.aviso(context, 'Usuário e senha são obrigatórios.');
      return;
    }

    setState(() => _carregando = true);
    try {
      final sucesso = await SapService.login(
        usuario: _usuarioController.text.trim(),
        senha:   _senhaController.text,
      );

      if (!mounted) return;

      if (!sucesso) {
        StoxSnackbar.erro(context, 'Credenciais inválidas.');
        return;
      }

      HapticFeedback.heavyImpact();
      Navigator.pushReplacement(
        context,
        StoxApp.transicaoPadrao(const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro de conexão com o servidor SAP.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (_, constraints) {
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

                    const Text(
                      'Contagem de Estoque',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Informe seu usuário e senha do SAP',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 40),

                    StoxTextField(
                      controller:      _usuarioController,
                      labelText:       'Usuário',
                      prefixIcon:      Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 20),

                    StoxPasswordField(
                      controller:      _senhaController,
                      textInputAction: TextInputAction.done,
                      onSubmitted:     (_) => _login(),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: StoxTextButton(
                        label:     'Limpar',
                        onPressed: _limparCampos,
                      ),
                    ),

                    const SizedBox(height: 20),

                    StoxButton(
                      label:     'ENTRAR E SINCRONIZAR',
                      loading:   _carregando,
                      onPressed: _login,
                    ),

                    const SizedBox(height: 16),

                    StoxOutlinedButton(
                      label: 'MODO CONTADOR OFFLINE',
                      icon:  Icons.qr_code_scanner,
                      onPressed: () => Navigator.push(
                        context,
                        StoxApp.transicaoPadrao(const ContadorOfflinePage()),
                      ),
                    ),

                    const Spacer(),

                    StoxTextButton(
                      label: 'Configurações da API',
                      icon:  Icons.settings,
                      onPressed: () => Navigator.push(
                        context,
                        StoxApp.transicaoPadrao(const ApiConfigPage()),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'STOX v1.0.0 — Grupo JCN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),

                    SizedBox(height: bottomPadding > 0 ? bottomPadding + 16 : 24),
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