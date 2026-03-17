import 'package:flutter/material.dart';

import '../services/sap_service.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Tela de abertura do STOX com animação da logo e verificação de sessão.
///
/// Executa 3 animações em sequência (fade, scale, slideY) em 1200ms,
/// depois verifica se existe sessão SAP válida (B1SESSION + ROUTEID)
/// e navega para [HomePage] ou [LoginPage].
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _slideY;

  @override
  void initState() {
    super.initState();

    // ── Controller principal (1200ms) ──
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // ── Fade: 0% → 60% do tempo ──
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    // ── Scale: 0.7 → 1.0 com easeOutBack (0% → 60%) ──
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // ── SlideY: 24px → 0px no subtítulo (30% → 80%) ──
    _slideY = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _iniciar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Fluxo principal ──

  /// Inicia a animação e verifica sessão em paralelo.
  Future<void> _iniciar() async {
    // Dispara animação e verificação de sessão ao mesmo tempo
    final resultados = await Future.wait([
      _controller.forward().orCancel.then((_) => true).catchError((_) => false),
      SapService.verificarSessao(),
    ]);

    // 600ms de respiro após a animação
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final temSessao = resultados[1];
    _navegar(temSessao);
  }

  /// Navega para [HomePage] ou [LoginPage] com fade de 500ms.
  void _navegar(bool temSessao) {
    final destino = temSessao ? const HomePage() : const LoginPage();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destino,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      backgroundColor: tema.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo animada (fade + scale) ──
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 160,
                  height: 160,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Subtítulo animado (fade + slideY) ──
            AnimatedBuilder(
              animation: _slideY,
              builder: (_, _) {
                return FadeTransition(
                  opacity: _fade,
                  child: Transform.translate(
                    offset: Offset(0, _slideY.value),
                    child: Text(
                      'Inventário Inteligente',
                      style: tema.textTheme.titleMedium?.copyWith(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // ── Versão no rodapé ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: FadeTransition(
            opacity: _fade,
            child: Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}