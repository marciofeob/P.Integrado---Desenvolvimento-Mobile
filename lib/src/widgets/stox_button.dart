import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── _StoxPressable ──────────────────────────────────────────────────────────

/// Widget interno que envolve botões com animação de compressão ao toque.
///
/// Scale 0.95 → 1.0 em 80ms. Aplicado automaticamente em [StoxButton],
/// [StoxOutlinedButton], [StoxTextButton] e [StoxFab].
///
/// Quando [enabled] é `false`, a animação de compressão não é acionada,
/// evitando feedback visual em botões desabilitados.
class _StoxPressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _StoxPressable({required this.child, this.enabled = true});

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
      onTapDown: widget.enabled ? (_) => _ctrl.reverse() : null,
      onTapUp: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapCancel: widget.enabled ? () => _ctrl.forward() : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── Helper de conteúdo ──────────────────────────────────────────────────────

/// Monta o conteúdo interno dos botões: ícone + label ou só label.
///
/// Extraído para evitar duplicação entre [StoxButton] e [StoxOutlinedButton].
Widget _buildIconLabel(String label, IconData? icon) {
  const estilo = TextStyle(fontWeight: FontWeight.bold);
  if (icon == null) return Text(label, style: estilo);

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Text(label, style: estilo),
    ],
  );
}

// ── StoxButton ──────────────────────────────────────────────────────────────

/// Botão primário do STOX — substitui [ElevatedButton] nas telas.
///
/// Exibe um [CircularProgressIndicator] quando [loading] é `true`
/// e desabilita o toque automaticamente. Envolvido por [_StoxPressable]
/// para animação de compressão ao toque.
///
/// ```dart
/// StoxButton(
///   label: 'SALVAR',
///   icon: Icons.save_rounded,
///   loading: _carregando,
///   onPressed: _salvar,
/// )
/// ```
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

  bool get _habilitado => !loading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return _StoxPressable(
      enabled: _habilitado,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: _habilitado
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!.call();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : _buildIconLabel(label, icon),
        ),
      ),
    );
  }
}

// ── StoxOutlinedButton ──────────────────────────────────────────────────────

/// Botão secundário do STOX — substitui [OutlinedButton] nas telas.
///
/// ```dart
/// StoxOutlinedButton(
///   label: 'CANCELAR',
///   icon: Icons.close,
///   onPressed: _cancelar,
/// )
/// ```
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
    return _StoxPressable(
      enabled: onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onPressed!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _buildIconLabel(label, icon),
        ),
      ),
    );
  }
}

// ── StoxDestructiveButton ───────────────────────────────────────────────────

/// Botão de ação destrutiva (excluir, limpar).
///
/// Atalho para [StoxOutlinedButton] com cor vermelha.
///
/// ```dart
/// StoxDestructiveButton(
///   label: 'EXCLUIR',
///   icon: Icons.delete_rounded,
///   onPressed: _excluir,
/// )
/// ```
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
  Widget build(BuildContext context) => StoxOutlinedButton(
        label: label,
        onPressed: onPressed,
        icon: icon,
        foregroundColor: Colors.red.shade600,
        height: height,
      );
}

// ── StoxTextButton ──────────────────────────────────────────────────────────

/// Botão de texto discreto — ações secundárias e links.
///
/// ```dart
/// StoxTextButton(label: 'Configurações', icon: Icons.settings, onPressed: _irConfig)
/// ```
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
    final VoidCallback? onTap = onPressed != null
        ? () {
            HapticFeedback.selectionClick();
            onPressed!.call();
          }
        : null;

    return _StoxPressable(
      enabled: onPressed != null,
      child: icon != null
          ? TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: textColor, size: 18),
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
///
/// Usado para ações principais no rodapé da tela (ex.: excluir lote).
///
/// ```dart
/// // No Scaffold:
/// floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
/// floatingActionButton: StoxFab(
///   label: 'Excluir 3 itens',
///   icon: Icons.delete_rounded,
///   backgroundColor: Colors.red.shade600,
///   onPressed: _excluirSelecionados,
/// ),
/// ```
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
    return _StoxPressable(
      enabled: onPressed != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onPressed != null
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!.call();
                  }
                : null,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  backgroundColor ?? Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}