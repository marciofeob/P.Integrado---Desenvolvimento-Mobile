import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  /// Escapa um campo CSV: envolve em aspas se contiver ; " ou quebra de linha.
  static String _escaparCampo(String valor) {
    if (valor.contains(';') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  /// Converte lista de linhas em CSV com delimitador ';' (padrão PT-BR).
  static String _converterParaCsv(List<List<String>> linhas) {
    return linhas
        .map((linha) => linha.map(_escaparCampo).join(';'))
        .join('\n');
  }

  static Future<void> exportarContagensParaCSV(
    List<Map<String, dynamic>> contagens,
  ) async {
    try {
      final linhas = <List<String>>[];

      // Cabeçalho compatível com Excel PT-BR
      linhas.add([
        'Código do Item',
        'Depósito',
        'Quantidade',
        'Data e Hora',
        'Status',
      ]);

      for (final c in contagens) {
        // Formata data de ISO 8601 → DD/MM/YYYY HH:MM:SS
        final dataHoraRaw = c['dataHora']?.toString() ?? '';
        String dataFormatada = dataHoraRaw;
        if (dataHoraRaw.length >= 19) {
          try {
            final dt = DateTime.parse(dataHoraRaw);
            dataFormatada =
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year} '
                '${dt.hour.toString().padLeft(2, '0')}:'
                '${dt.minute.toString().padLeft(2, '0')}:'
                '${dt.second.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        // Status legível
        final syncStatus = c['syncStatus'] ?? 0;
        final statusText = syncStatus == 1
            ? 'Sincronizado'
            : syncStatus == 2
                ? 'Erro no Envio'
                : 'Pendente';

        // Quantidade com vírgula para Excel PT-BR
        final quantidade =
            c['quantidade']?.toString().replaceAll('.', ',') ?? '0,0';

        linhas.add([
          c['itemCode']?.toString()      ?? '',
          c['warehouseCode']?.toString() ?? '01',
          quantidade,
          dataFormatada,
          statusText,
        ]);
      }

      // BOM UTF-8 para o Excel reconhecer acentos
      const bom        = '\uFEFF';
      final csvContent = bom + _converterParaCsv(linhas);

      // Salva em diretório temporário
      final dir   = await getTemporaryDirectory();
      final agora = DateTime.now();
      final tag   =
          '${agora.year}'
          '${agora.month.toString().padLeft(2, '0')}'
          '${agora.day.toString().padLeft(2, '0')}_'
          '${agora.hour.toString().padLeft(2, '0')}'
          '${agora.minute.toString().padLeft(2, '0')}';

      final path = '${dir.path}/Relatorio_STOX_$tag.csv';
      await File(path).writeAsString(csvContent);

      // Compartilha via share_plus
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        text:    'Relatório de Contagem Offline - STOX',
        subject: 'Relatório STOX - $tag',
      );
    } catch (e) {
      debugPrint('Erro na exportação do CSV: $e');
      rethrow;
    }
  }
}