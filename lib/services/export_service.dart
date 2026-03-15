import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  static Future<void> exportarContagensParaCSV(
    List<Map<String, dynamic>> contagens,
  ) async {
    try {
      List<List<dynamic>> rows = [];

      rows.add([
        "Código do Item",
        "Quantidade",
        "Depósito",          // ✅ coluna adicionada
        "Data e Hora",
        "Status de Sincronização",
      ]);

      for (var c in contagens) {
        String dataHoraRaw = c['dataHora'] ?? '';
        String dataFormatada = dataHoraRaw;

        if (dataHoraRaw.length >= 19) {
          try {
            final dt = DateTime.parse(dataHoraRaw);
            dataFormatada =
                "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} "
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
          } catch (_) {}
        }

        int syncStatusRaw = c['syncStatus'] ?? 0;
        String statusText = "Pendente";
        if (syncStatusRaw == 1) statusText = "Sincronizado";
        if (syncStatusRaw == 2) statusText = "Erro no Envio";

        String quantidadeFormatada =
            c['quantidade']?.toString().replaceAll('.', ',') ?? '0,0';

        // ✅ lê warehouseCode do banco, fallback para '01' em dados antigos
        String deposito = c['warehouseCode']?.toString().trim() ?? '01';
        if (deposito.isEmpty) deposito = '01';

        rows.add([
          c['itemCode'] ?? '',
          quantidadeFormatada,
          deposito,
          dataFormatada,
          statusText,
        ]);
      }

      String csvData = const ListToCsvConverter(
        fieldDelimiter: ';',
      ).convert(rows);

      const utf8BOM = '\uFEFF';
      final csvComBOM = utf8BOM + csvData;

      final directory = await getTemporaryDirectory();
      final agora = DateTime.now();
      final dataStr =
          "${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}"
          "_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}";

      final path = "${directory.path}/Relatorio_STOX_$dataStr.csv";
      final file = File(path);
      await file.writeAsString(csvComBOM, encoding: utf8);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        text: 'Relatório de Contagem Offline - STOX',
        subject: 'Relatório STOX - $dataStr',
      );
    } catch (e) {
      debugPrint("Erro na exportação do CSV: $e");
      rethrow;
    }
  }
}