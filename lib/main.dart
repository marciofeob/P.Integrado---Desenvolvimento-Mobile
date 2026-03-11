import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'features/auth/login_page.dart';
import 'core/themes/stox_theme.dart'; // <-- Caminho corrigido apontando para a pasta correta

class SecureHttpOverrides extends HttpOverrides {
  static bool allowUntrusted = true;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (allowUntrusted) {
          debugPrint('⚠️ AVISO: Certificado SSL ignorado para o host: $host (Configurado pelo usuário)');
          return true; 
        }
        return false; 
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  SecureHttpOverrides.allowUntrusted = prefs.getBool('sap_allow_untrusted') ?? true;
  
  HttpOverrides.global = SecureHttpOverrides();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const StoxApp());
}

class StoxApp extends StatelessWidget {
  const StoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STOX - Inventário',
      debugShowCheckedModeBanner: false,
      theme: StoxTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}