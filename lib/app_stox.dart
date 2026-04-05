import 'package:flutter/material.dart';

import 'src/pages/login_page.dart';
import 'src/widgets/stox_theme.dart';

/// Raiz da aplicação STOX.
///
/// Configura o [MaterialApp] com o tema SAP Fiori ([StoxTheme.lightTheme]),
/// define [LoginPage] como rota inicial e disponibiliza [transicaoPadrao]
/// para transições consistentes em toda a navegação.
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

  // ── Transição padrão entre telas ──────────────────────────────────────────

  /// Cria um [PageRouteBuilder] com a transição padrão do STOX.
  ///
  /// Combina slide sutil da direita (4%) com fade-in.
  /// - Duração de entrada: 300ms
  /// - Duração de saída: 250ms
  /// - Curva: [Curves.easeOut]
  ///
  /// Usar em qualquer navegação para manter consistência visual:
  /// ```dart
  /// Navigator.push(context, StoxApp.transicaoPadrao(MinhaPage()));
  /// ```
  static Route<T> transicaoPadrao<T>(Widget pagina) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => pagina,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, _, child) {
        final curva = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curva),
            child: child,
          ),
        );
      },
    );
  }
}