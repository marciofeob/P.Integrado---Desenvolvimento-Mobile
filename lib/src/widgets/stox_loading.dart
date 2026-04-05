import 'package:flutter/material.dart';

// ── StoxLoadingSpinner ──────────────────────────────────────────────────────

/// Spinner centralizado com mensagem opcional.
///
/// Usar em telas que aguardam uma operação pontual (ex.: login, busca).
/// Para carregamentos de lista, prefira [StoxSkeletonList].
///
/// ```dart
/// if (_carregando) const StoxLoadingSpinner(mensagem: 'Buscando no SAP...')
/// ```
class StoxLoadingSpinner extends StatelessWidget {
  final String? mensagem;

  const StoxLoadingSpinner({super.key, this.mensagem});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: tema.colorScheme.primary,
            ),
          ),
          if (mensagem != null) ...[
            const SizedBox(height: 16),
            Text(
              mensagem!,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── StoxLinearLoading ───────────────────────────────────────────────────────

/// Barra fina de progresso indeterminado no topo da tela.
///
/// Usar dentro de um [Column] acima do conteúdo durante
/// sincronizações e operações de rede:
/// ```dart
/// Column(children: [
///   if (_carregando) const StoxLinearLoading(),
///   StoxSummaryCard(...),
/// ])
/// ```
class StoxLinearLoading extends StatelessWidget {
  const StoxLinearLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 3,
        backgroundColor:
            Theme.of(context).colorScheme.primary.withAlpha(30),
      ),
    );
  }
}

// ── StoxSkeletonCard ────────────────────────────────────────────────────────

/// Card fantasma com animação de pulso (shimmer sem dependência externa).
///
/// Usado internamente por [StoxSkeletonList]. Pode ser usado isoladamente
/// quando precisar de um placeholder customizado.
class StoxSkeletonCard extends StatefulWidget {
  const StoxSkeletonCard({super.key});

  @override
  State<StoxSkeletonCard> createState() => _StoxSkeletonCardState();
}

class _StoxSkeletonCardState extends State<StoxSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacidade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacidade = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(width: 180, height: 14),
            const SizedBox(height: 12),
            _SkeletonLine(width: 120, height: 12),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _SkeletonLine(height: 10)),
                const SizedBox(width: 48),
                _SkeletonLine(width: 60, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha retangular de placeholder para skeleton loading.
class _SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const _SkeletonLine({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── StoxSkeletonList ────────────────────────────────────────────────────────

/// Lista de [StoxSkeletonCard] para placeholder no primeiro carregamento.
///
/// ```dart
/// if (_iniciando)
///   const StoxSkeletonList(quantidade: 5)
/// else
///   Expanded(child: _buildLista())
/// ```
class StoxSkeletonList extends StatelessWidget {
  final int quantidade;

  const StoxSkeletonList({super.key, this.quantidade = 5});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: quantidade,
          itemBuilder: (_, _) => const StoxSkeletonCard(),
        ),
      ),
    );
  }
}