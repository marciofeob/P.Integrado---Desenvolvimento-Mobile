import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botão primário padrão do STOX.
/// Substitui todos os ElevatedButton das telas.
class StoxButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;
  final double height;

  const StoxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : () {
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
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : icon != null
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
    );
  }
}

/// Botão secundário (outlined) padrão do STOX.
class StoxOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? foregroundColor;
  final double height;

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
    return SizedBox(
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
    );
  }
}

/// Botão de ação destrutiva (ex: excluir, limpar).
class StoxDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const StoxDestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return StoxOutlinedButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      foregroundColor: Colors.red.shade600,
      height: height,
    );
  }
}

/// Botão de texto simples (ações secundárias, links).
class StoxTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

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
    if (icon != null) {
      return TextButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed?.call();
        },
        icon: Icon(icon, color: textColor, size: 18),
        label: Text(label, style: TextStyle(color: textColor)),
      );
    }
    return TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed?.call();
      },
      child: Text(label, style: TextStyle(color: textColor)),
    );
  }
}

/// Botão flutuante centralizado (ex: fila de impressão, excluir em lote).
class StoxFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  const StoxFab({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          icon: Icon(icon),
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
    );
  }
}