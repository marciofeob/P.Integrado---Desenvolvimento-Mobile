import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_stox.dart';

/// Permite SSL auto-assinado globalmente quando o usuário ativa
/// a opção "Permitir SSL pré-assinado" nas configurações.
///
/// Configurado antes de qualquer requisição HTTP em [main].
class SecureHttpOverrides extends HttpOverrides {
  static bool allowUntrusted = true;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (allowUntrusted) {
          if (kDebugMode) {
            debugPrint('SecureHttpOverrides: SSL ignorado para $host');
          }
          return true;
        }
        return false;
      };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientação ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ── SSL ──
  final prefs = await SharedPreferences.getInstance();
  SecureHttpOverrides.allowUntrusted =
      prefs.getBool('sap_allow_untrusted') ?? true;
  HttpOverrides.global = SecureHttpOverrides();

  // ── Status bar e navigation bar ──
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const StoxApp());
}