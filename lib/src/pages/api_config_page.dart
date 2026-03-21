import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Tela de configuração da conexão com o SAP Business One Service Layer.
///
/// Persiste URL, CompanyDB, depósito padrão e política de SSL
/// via [SharedPreferences].
class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final _urlController      = TextEditingController();
  final _companyController  = TextEditingController();
  final _depositoController = TextEditingController();

  bool _permitirSslInseguro = true;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _companyController.dispose();
    _depositoController.dispose();
    super.dispose();
  }

  // ── Dados ─────────────────────────────────────────────────────────────────

  Future<void> _carregarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlController.text      = prefs.getString('sap_url')             ?? '';
      _companyController.text  = prefs.getString('sap_company')         ?? '';
      _depositoController.text = prefs.getString('sap_deposito_padrao') ?? '01';
      _permitirSslInseguro     = prefs.getBool('sap_allow_untrusted')   ?? true;
    });
  }

  Future<void> _salvarConfig() async {
    FocusScope.of(context).unfocus();

    final deposito = _depositoController.text.trim();
    if (deposito.isEmpty) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Informe o código do depósito padrão.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_url',             _urlController.text.trim());
    await prefs.setString('sap_company',         _companyController.text.trim());
    await prefs.setString('sap_deposito_padrao', deposito.toUpperCase());
    await prefs.setBool('sap_allow_untrusted',   _permitirSslInseguro);

    await StoxAudio.play('sounds/check.mp3');
    if (!mounted) return;
    StoxSnackbar.sucesso(context, 'Configurações salvas com sucesso!');
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuração SAP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conexão Service Layer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajuste os endereços para sincronização com o SAP Business One.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 30),

              StoxTextField(
                controller:      _urlController,
                labelText:       'Service Layer URL',
                prefixIcon:      Icons.link,
                keyboardType:    TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              StoxTextField(
                controller:      _companyController,
                labelText:       'CompanyDB',
                prefixIcon:      Icons.business,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              StoxTextField(
                controller:         _depositoController,
                labelText:          'Depósito Padrão',
                prefixIcon:         Icons.warehouse_rounded,
                textInputAction:    TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                onSubmitted:        (_) => _salvarConfig(),
                helperText: 'Código do depósito usado nas contagens de inventário.',
              ),
              const SizedBox(height: 25),

              StoxCard(
                child: SwitchListTile.adaptive(
                  title: const Text(
                    'Permitir SSL pré-assinado',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Ative se o servidor SAP usar certificado auto-assinado '
                    '(comum em ambientes de desenvolvimento e teste).',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: _permitirSslInseguro,
                  // ignore: deprecated_member_use
                  activeColor: primaryColor,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _permitirSslInseguro = value);
                  },
                ),
              ),

              const SizedBox(height: 40),

              StoxButton(
                label:     'SALVAR CONFIGURAÇÕES',
                icon:      Icons.save_rounded,
                onPressed: _salvarConfig,
              ),

              const SizedBox(height: 48),
              Text(
                'STOX v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}