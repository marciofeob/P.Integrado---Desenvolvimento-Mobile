import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'app_stox.dart';

/// Sobrescreve o cliente HTTP global para permitir SSL auto-assinado
/// quando o usuário habilita a opção nas configurações.
class SecureHttpOverrides extends HttpOverrides {
  static bool allowUntrusted = true;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (allowUntrusted) {
          debugPrint(
              '⚠️ AVISO: Certificado SSL ignorado para o host: $host '
              '(Configurado pelo usuário)');
          return true;
        }
        return false;
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lê a preferência de SSL antes de qualquer requisição de rede
  final prefs = await SharedPreferences.getInstance();
  SecureHttpOverrides.allowUntrusted =
      prefs.getBool('sap_allow_untrusted') ?? true;
  HttpOverrides.global = SecureHttpOverrides();

  // Força orientação retrato
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Ajusta as cores da barra de status e navegação
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const StoxApp());
}