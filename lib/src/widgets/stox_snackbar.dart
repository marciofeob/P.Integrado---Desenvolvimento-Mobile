import 'package:flutter/material.dart';

/// Utilitário de SnackBars padronizados do STOX.
///
/// Classe abstrata — não deve ser instanciada.
/// Centraliza todos os [ScaffoldMessenger.showSnackBar] das telas.
///
/// Cada chamada remove o SnackBar anterior antes de exibir o novo,
/// evitando empilhamento quando ações são disparadas em sequência.
///
/// ```dart
/// StoxSnackbar.sucesso(context, 'Item salvo!');
/// StoxSnackbar.erro(context, 'Falha na conexão.');
/// StoxSnackbar.aviso(context, 'Campo obrigatório.');
/// StoxSnackbar.info(context, 'Sincronizando...');
/// ```
abstract class StoxSnackbar {
  /// SnackBar de erro — fundo vermelho, duração padrão de 4 segundos.
  static void erro(BuildContext context, String mensagem) => _mostrar(
        context,
        mensagem: mensagem,
        cor: Colors.red.shade700,
        icone: Icons.error_outline,
      );

  /// SnackBar de aviso — fundo laranja, duração padrão de 4 segundos.
  static void aviso(BuildContext context, String mensagem) => _mostrar(
        context,
        mensagem: mensagem,
        cor: Colors.orange.shade700,
        icone: Icons.warning_amber_rounded,
      );

  /// SnackBar de sucesso — fundo verde, duração de 2 segundos.
  static void sucesso(BuildContext context, String mensagem) => _mostrar(
        context,
        mensagem: mensagem,
        cor: Colors.green.shade700,
        icone: Icons.check_circle_outline_rounded,
        duracao: const Duration(seconds: 2),
      );

  /// SnackBar informativo — fundo azul, duração de 2 segundos.
  static void info(BuildContext context, String mensagem) => _mostrar(
        context,
        mensagem: mensagem,
        cor: Colors.blue.shade700,
        icone: Icons.info_outline_rounded,
        duracao: const Duration(seconds: 2),
      );

  static void _mostrar(
    BuildContext context, {
    required String mensagem,
    required Color cor,
    required IconData icone,
    Duration duracao = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);

    // Remove SnackBar anterior para evitar empilhamento
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icone, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: duracao,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}