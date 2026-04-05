import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitários de diálogos padronizados do STOX.
///
/// Classe abstrata — não deve ser instanciada.
///
/// Padrão: o `BuildContext` do diálogo é nomeado `dialogCtx` para evitar
/// conflito com o `context` da tela pai (ver `code_standards.md`).
abstract class StoxDialog {
  /// Diálogo de confirmação simples com botões Cancelar / Confirmar.
  ///
  /// Defina [destrutivo] como `true` para colorir o botão de confirmação
  /// em vermelho (ações como excluir, limpar).
  ///
  /// Retorna `true` se confirmou, `false` se cancelou ou fechou.
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
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              labelCancelar,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx, true);
            },
            style: destrutivo
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                  )
                : null,
            child: Text(
              labelConfirmar,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  /// Diálogo de confirmação que exige digitação de [palavraChave].
  ///
  /// Indicado para exclusões críticas onde um clique acidental seria custoso
  /// (ex: limpar todas as contagens, excluir lote).
  ///
  /// O botão de confirmar só é habilitado quando o texto digitado
  /// corresponde exatamente à [palavraChave] (default: `'EXCLUIR'`).
  static Future<bool> confirmarComDigitacao(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String palavraChave = 'EXCLUIR',
  }) async {
    final controller = TextEditingController();

    try {
      var habilitado = false;

      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade600, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensagem),
                const SizedBox(height: 16),
                Text(
                  'Digite "$palavraChave" para confirmar:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  onTap: () => HapticFeedback.selectionClick(),
                  onChanged: (v) => setState(
                    () => habilitado = v.trim() == palavraChave,
                  ),
                  decoration: InputDecoration(
                    hintText: palavraChave,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: habilitado
                    ? () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(dialogCtx, true);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                child: const Text(
                  'EXCLUIR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );

      return resultado ?? false;
    } finally {
      // Garante dispose mesmo se o diálogo lançar exceção
      controller.dispose();
    }
  }
}

// ── StoxStatusChip ──────────────────────────────────────────────────────────

/// Chip de status booleano — indica se um item está habilitado ou não.
///
/// Usado nos chips Estoque / Venda / Compra da tela de consulta.
///
/// ```dart
/// StoxStatusChip('Estoque', active: item['InventoryItem'] == 'tYES')
/// ```
class StoxStatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const StoxStatusChip(this.label, {super.key, required this.active});

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        color: WidgetStatePropertyAll(
          active ? Colors.green.shade50 : Colors.grey.shade100,
        ),
        avatar: Icon(
          active ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: active ? Colors.green : Colors.grey,
        ),
      );
}

// ── StoxBadge ───────────────────────────────────────────────────────────────

/// Badge numérico sobreposto a um widget filho.
///
/// Oculta automaticamente quando [count] é zero.
/// Suporta contagens de 1 a 99+ sem overflow visual.
///
/// ```dart
/// StoxBadge(
///   count: _carrinho.length,
///   child: IconButton(icon: const Icon(Icons.print_rounded), ...),
/// )
/// ```
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
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints:
                  const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}