import 'package:flutter/material.dart';

/// Utilitário de SnackBars padronizados do STOX.
/// Centraliza todos os showSnackBar das telas em métodos estáticos.
abstract class StoxSnackbar {

  /// SnackBar de erro (vermelho).
  static void erro(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem: mensagem,
      cor: Colors.red.shade700,
      icone: Icons.error_outline,
    );
  }

  /// SnackBar de aviso (laranja).
  static void aviso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem: mensagem,
      cor: Colors.orange.shade700,
      icone: Icons.warning_amber_rounded,
    );
  }

  /// SnackBar de sucesso (verde).
  static void sucesso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem: mensagem,
      cor: Colors.green.shade700,
      icone: Icons.check_circle_outline_rounded,
      duracao: const Duration(seconds: 2),
    );
  }

  /// SnackBar de informação (azul).
  static void info(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem: mensagem,
      cor: Colors.blue.shade700,
      icone: Icons.info_outline_rounded,
      duracao: const Duration(seconds: 2),
    );
  }

  static void _mostrar(
    BuildContext context, {
    required String mensagem,
    required Color cor,
    required IconData icone,
    Duration duracao = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icone, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
            child: Text(mensagem,
                style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      duration: duracao,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}