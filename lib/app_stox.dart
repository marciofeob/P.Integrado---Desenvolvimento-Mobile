import 'package:flutter/material.dart';

import 'src/pages/login_page.dart';
import 'src/widgets/stox_theme.dart';

/// Ponto de entrada da aplicação STOX.
/// Configura o MaterialApp com o tema SAP Fiori e a rota inicial.
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