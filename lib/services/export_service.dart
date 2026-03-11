import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<void> exportarContagensParaCSV(List<Map<String, dynamic>> contagens) async {
    List<List<dynamic>> rows = [];
    // Cabeçalho compatível com Excel (delimitador ;)
    rows.add(["Codigo_Item_Fardo", "Quantidade", "Data_Hora"]);

    for (var c in contagens) {
      rows.add([
        c['itemCode'],
        c['quantidade'],
        c['data_hora'] ?? '', // Caso seu SQL tenha o campo de data
      ]);
    }

    String csvData = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/contagem_stox_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);

    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'Relatório de Contagem Offline - STOX');
  }
}