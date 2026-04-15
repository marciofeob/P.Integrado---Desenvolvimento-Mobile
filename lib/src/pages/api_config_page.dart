import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Tela de configuração da conexão SAP Business One.
///
/// Permite ao usuário definir:
/// - URL do Service Layer
/// - CompanyDB (base de dados SAP)
/// - Código do depósito padrão
/// - Permissão de SSL auto-assinado
///
/// Os valores são persistidos em [SharedPreferences] e lidos pelo
/// [SapService] em todas as requisições subsequentes.
class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final _urlController = TextEditingController();
  final _companyController = TextEditingController();
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

  // ── Persistência ──────────────────────────────────────────────────────────

  /// Carrega os valores salvos nas preferências para preencher os campos.
  Future<void> _carregarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _urlController.text = prefs.getString('sap_url') ?? '';
      _companyController.text = prefs.getString('sap_company') ?? '';
      _depositoController.text =
          prefs.getString('sap_deposito_padrao') ?? '01';
      _permitirSslInseguro =
          prefs.getBool('sap_allow_untrusted') ?? true;
    });
  }

  /// Valida e salva as configurações, depois retorna à tela anterior.
  Future<void> _salvarConfig() async {
    FocusScope.of(context).unfocus();

    // ── Validação ──
    final deposito = _depositoController.text.trim();
    if (deposito.isEmpty) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Informe o código do depósito padrão.');
      return;
    }

    // ── Salvar em paralelo ──
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('sap_url', _urlController.text.trim()),
      prefs.setString('sap_company', _companyController.text.trim()),
      prefs.setString('sap_deposito_padrao', deposito.toUpperCase()),
      prefs.setBool('sap_allow_untrusted', _permitirSslInseguro),
    ]);

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
      appBar: AppBar(
        title: const Text('Configuração SAP'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Cabeçalho ──
              const Text(
                'Conexão Service Layer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Ajuste os endereços para sincronização '
                'com o SAP Business One.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 30),

              // ── Campos ──
              StoxTextField(
                controller: _urlController,
                labelText: 'Service Layer URL',
                prefixIcon: Icons.link,
                helperText: 'Ex: https://192.168.1.10:50000/b1s/v1',
              ),

              const SizedBox(height: 20),

              StoxTextField(
                controller: _companyController,
                labelText: 'CompanyDB',
                prefixIcon: Icons.business,
                helperText: 'Nome da base de dados SAP',
              ),

              const SizedBox(height: 20),

              StoxTextField(
                controller: _depositoController,
                labelText: 'Depósito Padrão',
                prefixIcon: Icons.warehouse_rounded,
                textCapitalization: TextCapitalization.characters,
                helperText: 'Código do depósito (ex: 01)',
              ),

              const SizedBox(height: 25),

              // ── SSL ──
              StoxCard(
                child: SwitchListTile.adaptive(
                  title: const Text('Permitir SSL auto-assinado'),
                  subtitle: Text(
                    'Ative se o servidor SAP usar certificado '
                    'auto-assinado (padrão em ambientes on-premises).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  value: _permitirSslInseguro,
                  activeThumbColor: primaryColor,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _permitirSslInseguro = value);
                  },
                ),
              ),

              const SizedBox(height: 40),

              // ── Ações ──
              StoxButton(
                label: 'SALVAR CONFIGURAÇÕES',
                icon: Icons.save_rounded,
                onPressed: _salvarConfig,
              ),

              const SizedBox(height: 16),

              // ── Rodapé ──
              StoxTextButton(
                label: 'Voltar',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }
}