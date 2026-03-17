import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── _StoxPressable ──────────────────────────────────────────────────────────

/// Widget interno que envolve botões com animação de compressão ao toque.
///
/// Scale 0.95 → 1.0 em 80ms. Aplicado automaticamente em [StoxButton],
/// [StoxOutlinedButton], [StoxTextButton] e [StoxFab].
class _StoxPressable extends StatefulWidget {
  final Widget child;

  const _StoxPressable({required this.child});

  @override
  State<_StoxPressable> createState() => _StoxPressableState();
}

class _StoxPressableState extends State<_StoxPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      value: 1.0,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── StoxButton ──────────────────────────────────────────────────────────────

/// Botão primário do STOX — substitui [ElevatedButton] nas telas.
///
/// Exibe um [CircularProgressIndicator] quando [loading] é `true`
/// e desabilita o toque automaticamente. Envolvido por [_StoxPressable]
/// para animação de compressão ao toque.
class StoxButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onPressed;
  final bool          loading;
  final IconData?     icon;
  final Color?        backgroundColor;
  final double        height;

  const StoxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading         = false,
    this.icon,
    this.backgroundColor,
    this.height          = 54,
  });

  @override
  Widget build(BuildContext context) {
    return _StoxPressable(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: loading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : icon != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Text(label,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ── StoxOutlinedButton ──────────────────────────────────────────────────────

/// Botão secundário do STOX — substitui [OutlinedButton] nas telas.
class StoxOutlinedButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onPressed;
  final IconData?     icon;
  final Color?        foregroundColor;
  final double        height;

  const StoxOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.foregroundColor,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Theme.of(context).primaryColor;
    return _StoxPressable(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onPressed?.call();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ── StoxDestructiveButton ───────────────────────────────────────────────────

/// Botão de ação destrutiva (excluir, limpar).
/// Atalho para [StoxOutlinedButton] com cor vermelha.
class StoxDestructiveButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onPressed;
  final IconData?     icon;
  final double        height;

  const StoxDestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) => StoxOutlinedButton(
        label:           label,
        onPressed:       onPressed,
        icon:            icon,
        foregroundColor: Colors.red.shade600,
        height:          height,
      );
}

// ── StoxTextButton ──────────────────────────────────────────────────────────

/// Botão de texto discreto — ações secundárias e links.
class StoxTextButton extends StatelessWidget {
  final String        label;
  final VoidCallback? onPressed;
  final IconData?     icon;
  final Color?        color;

  const StoxTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.grey.shade600;
    void onTap() {
      HapticFeedback.selectionClick();
      onPressed?.call();
    }

    return _StoxPressable(
      child: icon != null
          ? TextButton.icon(
              onPressed: onTap,
              icon:  Icon(icon, color: textColor, size: 18),
              label: Text(label, style: TextStyle(color: textColor)),
            )
          : TextButton(
              onPressed: onTap,
              child: Text(label, style: TextStyle(color: textColor)),
            ),
    );
  }
}

// ── StoxFab ─────────────────────────────────────────────────────────────────

/// Botão de ação flutuante (FAB) de largura total.
/// Usado para ações principais no rodapé da tela (ex.: excluir lote).
class StoxFab extends StatelessWidget {
  final String        label;
  final IconData      icon;
  final VoidCallback? onPressed;
  final Color?        backgroundColor;

  const StoxFab({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return _StoxPressable(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            },
            icon:  Icon(icon),
            label: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  backgroundColor ?? Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}