import 'package:flutter/material.dart';

import 'src/pages/splash_page.dart';
import 'src/widgets/stox_theme.dart';

/// Raiz da aplicação STOX.
///
/// Configura o [MaterialApp] com o tema SAP Fiori ([StoxTheme.lightTheme]),
/// define [SplashPage] como rota inicial e aplica transição padrão
/// (slide 4% + fade, 300ms) em todas as navegações via [onGenerateRoute].
class StoxApp extends StatelessWidget {
  const StoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                     'STOX - Inventário',
      debugShowCheckedModeBanner: false,
      theme:                     StoxTheme.lightTheme,
      home:                      const SplashPage(),
      onGenerateRoute:           _gerarRota,
    );
  }

  // ── Transição padrão entre telas ──

  /// Slide sutil da direita (4%) combinado com fade.
  /// Duração: 300ms com [Curves.easeOut].
  Route<dynamic>? _gerarRota(RouteSettings settings) {
    // Mapear rotas nomeadas aqui se necessário no futuro.
    return null;
  }

  /// Cria um [PageRouteBuilder] com a transição padrão do STOX.
  ///
  /// Usar em qualquer `Navigator.push` para manter consistência:
  /// ```dart
  /// Navigator.push(context, StoxApp.transicaoPadrao(MinhaPage()));
  /// ```
  static Route<T> transicaoPadrao<T>(Widget pagina) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => pagina,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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