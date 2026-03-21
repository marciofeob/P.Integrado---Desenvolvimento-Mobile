import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Serviço de exportação de contagens para CSV.
///
/// Gera um arquivo CSV compatível com Excel PT-BR (delimitador `;`,
/// encoding UTF-8 com BOM) e o compartilha via [SharePlus].
class ExportService {
  ExportService._();

  // ── CSV ───────────────────────────────────────────────────────────────────

  /// Escapa um campo: envolve em aspas duplas se contiver `;`, `"` ou `\n`.
  static String _escapar(String valor) {
    if (valor.contains(';') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  static String _toCsv(List<List<String>> linhas) =>
      linhas.map((l) => l.map(_escapar).join(';')).join('\n');

  // ── Formatação ────────────────────────────────────────────────────────────

  static String _formatarData(String raw) {
    if (raw.length < 19) return raw;
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  static String _formatarStatus(int status) => switch (status) {
        1 => 'Sincronizado',
        2 => 'Erro no Envio',
        _ => 'Pendente',
      };

  // ── Exportação ────────────────────────────────────────────────────────────

  /// Gera e compartilha o relatório CSV das [contagens] fornecidas.
  ///
  /// Retorna `true` se o usuário efetivamente compartilhou o arquivo,
  /// ou `false` se cancelou/fechou o diálogo de compartilhamento.
  /// Lança exceção em caso de falha — o chamador deve tratar e exibir feedback.
  static Future<bool> exportarContagensParaCSV(
    List<Map<String, dynamic>> contagens,
  ) async {
    try {
      final linhas = <List<String>>[
        ['Código do Item', 'Depósito', 'Quantidade', 'Data e Hora', 'Status'],
        ...contagens.map((c) => [
              c['itemCode']?.toString()                        ?? '',
              c['warehouseCode']?.toString()                   ?? '01',
              c['quantidade']?.toString().replaceAll('.', ',') ?? '0,0',
              _formatarData(c['dataHora']?.toString()          ?? ''),
              _formatarStatus(c['syncStatus'] as int?          ?? 0),
            ]),
      ];

      // BOM UTF-8 garante que o Excel reconheça acentos automaticamente
      const bom      = '\uFEFF';
      final conteudo = bom + _toCsv(linhas);

      final dir   = await getTemporaryDirectory();
      final agora = DateTime.now();
      final tag   = '${agora.year}'
          '${agora.month.toString().padLeft(2, '0')}'
          '${agora.day.toString().padLeft(2, '0')}_'
          '${agora.hour.toString().padLeft(2, '0')}'
          '${agora.minute.toString().padLeft(2, '0')}';

      final arquivo = File('${dir.path}/Relatorio_STOX_$tag.csv');
      await arquivo.writeAsString(conteudo);

      final resultado = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(arquivo.path, mimeType: 'text/csv')],
          text:    'Relatório de Contagem Offline - STOX',
          subject: 'Relatório STOX - $tag',
        ),
      );

      return resultado.status == ShareResultStatus.success;
    } catch (e) {
      if (kDebugMode) debugPrint('ExportService.exportarContagensParaCSV: $e');
      rethrow;
    }
  }
}