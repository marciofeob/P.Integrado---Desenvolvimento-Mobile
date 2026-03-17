import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitário de diálogos padronizados do STOX.
abstract class StoxDialog {

  /// Diálogo de confirmação simples (Cancelar / Confirmar).
  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String labelConfirmar = 'CONFIRMAR',
    String labelCancelar = 'CANCELAR',
    bool destrutivo = false,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(labelCancelar,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, true);
            },
            style: destrutivo
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600)
                : null,
            child: Text(labelConfirmar,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  /// Diálogo de confirmação com digitação de palavra-chave.
  /// Usado para exclusões críticas (3+ itens).
  static Future<bool> confirmarComDigitacao(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String palavraChave = 'EXCLUIR',
  }) async {
    final controller = TextEditingController();
    bool habilitado = false;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade600, size: 24),
            const SizedBox(width: 8),
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensagem),
              const SizedBox(height: 16),
              Text('Digite "$palavraChave" para confirmar:',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                onTap: () => HapticFeedback.selectionClick(),
                onChanged: (v) => setDialogState(
                    () => habilitado = v.trim() == palavraChave),
                decoration: InputDecoration(
                  hintText: palavraChave,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCELAR',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: habilitado
                  ? () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context, true);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600),
              child: const Text('EXCLUIR',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return resultado ?? false;
  }
}

/// Chip de status (Estoque / Venda / Compra).
class StoxStatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const StoxStatusChip(this.label, {super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor:
          active ? Colors.green.shade50 : Colors.grey.shade100,
      avatar: Icon(
        active ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }
}

/// Badge numérico (ex: contador no ícone da fila de impressão).
class StoxBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const StoxBadge({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  color: Colors.red.shade600, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}