import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto padrão do STOX com haptic feedback.
class StoxTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? helperText;

  const StoxTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onTap: () => HapticFeedback.selectionClick(),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Campo de senha com botão de mostrar/ocultar integrado.
class StoxPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const StoxPasswordField({
    super.key,
    required this.controller,
    this.labelText = 'Senha',
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<StoxPasswordField> createState() => _StoxPasswordFieldState();
}

class _StoxPasswordFieldState extends State<StoxPasswordField> {
  bool _ocultar = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _ocultar,
      textInputAction: widget.textInputAction,
      onTap: () => HapticFeedback.selectionClick(),
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_ocultar ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _ocultar = !_ocultar);
          },
        ),
      ),
    );
  }
}

/// Barra de busca com ícone de IA e scanner integrados.
class StoxSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback? onIA;
  final VoidCallback? onScanner;
  final void Function(String)? onChanged;

  const StoxSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onIA,
    this.onScanner,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            onTap: () => HapticFeedback.selectionClick(),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Código ou Nome',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onIA != null)
                    IconButton(
                      icon: const Icon(Icons.auto_awesome,
                          color: Colors.blueAccent),
                      tooltip: 'Ler texto com IA',
                      onPressed: onIA,
                    ),
                  if (onScanner != null)
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded,
                          color: theme.primaryColor),
                      tooltip: 'Escanear código de barras',
                      onPressed: onScanner,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          width: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onSearch();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ]),
    );
  }
}