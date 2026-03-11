import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  static Future<void> exportarContagensParaCSV(List<Map<String, dynamic>> contagens) async {
    try {
      List<List<dynamic>> rows = [];
      
      // Cabeçalho amigável, com acentuação e compatível com Excel (delimitador ;)
      rows.add([
        "Código do Item (Fardo)", 
        "Quantidade", 
        "Data e Hora", 
        "Status de Sincronização"
      ]);

      for (var c in contagens) {
        // Correção: o banco de dados está salvando como 'dataHora' (camelCase)
        String dataHoraRaw = c['dataHora'] ?? '';
        String dataFormatada = dataHoraRaw;
        
        // Tratamento da Data/Hora (De ISO 8601 para formato local legível PT-BR)
        if (dataHoraRaw.length >= 19) {
          try {
            final dt = DateTime.parse(dataHoraRaw);
            dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
          } catch (_) {
            // Mantém o valor original se o parse falhar
          }
        }

        // Traduz o status de sincronização numérico para texto
        int syncStatusRaw = c['syncStatus'] ?? 0;
        String statusText = "Pendente";
        if (syncStatusRaw == 1) statusText = "Sincronizado";
        if (syncStatusRaw == 2) statusText = "Erro no Envio";

        // Formata a quantidade trocando ponto por vírgula para o Excel no padrão PT-BR
        String quantidadeFormatada = c['quantidade']?.toString().replaceAll('.', ',') ?? '0,0';

        rows.add([
          c['itemCode'] ?? '',
          quantidadeFormatada,
          dataFormatada,
          statusText,
        ]);
      }

      // Converte para CSV com delimitador ';' padrão brasileiro
      String csvData = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
      
      // Adiciona o BOM (Byte Order Mark) do UTF-8 para o Excel reconhecer acentos automaticamente (Ex: "Código", "Sincronização")
      const utf8BOM = '\uFEFF';
      final csvComBOM = utf8BOM + csvData;

      final directory = await getTemporaryDirectory();
      
      // Gera um nome de arquivo legível baseado na data/hora atual
      final agora = DateTime.now();
      final dataStr = "${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}";
      
      final path = "${directory.path}/Relatorio_STOX_$dataStr.csv";
      final file = File(path);

      // Escreve no arquivo forçando o encoding UTF-8
      await file.writeAsString(csvComBOM, encoding: utf8);
      
      // Compartilha o arquivo
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')], 
        text: 'Relatório de Contagem Offline - STOX Agro',
        subject: 'Relatório STOX - $dataStr',
      );
    } catch (e) {
      debugPrint("Erro na exportação do CSV: $e");
      rethrow; // Repassa o erro para a UI tratar e mostrar o SnackBar vermelho
    }
  }
}