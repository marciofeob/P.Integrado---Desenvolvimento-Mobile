import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_stox.dart';

/// Permite certificados SSL auto-assinados quando habilitado pelo usuário.
///
/// Necessário em ambientes SAP on-premises onde o Service Layer
/// utiliza certificados internos não reconhecidos pela cadeia pública.
///
/// A flag [allowUntrusted] é lida de [SharedPreferences] em [main]
/// e aplicada globalmente via [HttpOverrides.global].
class SecureHttpOverrides extends HttpOverrides {
  /// Quando `true`, aceita qualquer certificado SSL.
  ///
  /// Controlado pela chave `sap_allow_untrusted` nas preferências.
  /// Default: `true` (padrão corporativo SAP on-premises).
  static bool allowUntrusted = true;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (allowUntrusted) {
          if (kDebugMode) {
            debugPrint('SecureHttpOverrides: SSL ignorado para $host:$port');
          }
          return true;
        }
        return false;
      };
  }
}

/// Ponto de entrada da aplicação STOX.
///
/// Responsável por:
/// 1. Travar orientação em retrato.
/// 2. Limpar sessão SAP anterior (exige login a cada abertura por segurança).
/// 3. Configurar override de SSL conforme preferências do usuário.
/// 4. Definir estilo da barra de status e navegação do sistema.
/// 5. Iniciar o [StoxApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientação ────────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ── Preferências ──────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── Sessão SAP ────────────────────────────────────────────────────────────
  // Limpa cookies de sessão para forçar login a cada abertura.
  // Motivo: tokens B1SESSION expiram no servidor e manter cookies antigos
  // causa falhas silenciosas nas requisições subsequentes.
  await Future.wait([
    prefs.remove('B1SESSION'),
    prefs.remove('ROUTEID'),
    prefs.remove('UserName'),
  ]);

  // ── SSL ────────────────────────────────────────────────────────────────────
  SecureHttpOverrides.allowUntrusted =
      prefs.getBool('sap_allow_untrusted') ?? true;
  HttpOverrides.global = SecureHttpOverrides();

  // ── UI do sistema ─────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const StoxApp());
}