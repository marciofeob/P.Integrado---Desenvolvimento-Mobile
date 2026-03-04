import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SapService {
  
  // ==========================================
  // MÉTODOS DE AUTENTICAÇÃO (LOGIN / LOGOUT)
  // ==========================================

  static Future<bool> login({required String usuario, required String senha}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final company = prefs.getString('sap_company');

    if (baseUrl == null || company == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "CompanyDB": company,
          "UserName": usuario,
          "Password": senha,
        }),
      );

      if (response.statusCode == 200) {
        // 1. Pega o SessionId com 100% de certeza pelo corpo da resposta (JSON)
        final data = jsonDecode(response.body);
        final sessionId = data['SessionId'];

        if (sessionId != null) {
          await prefs.setString('B1SESSION', sessionId);
        }

        // 2. Pega o ROUTEID pelo Header (necessário caso seu SAP use Balanceador de Carga)
        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          final routeIdMatch = RegExp(r'ROUTEID=([^;]+)').firstMatch(rawCookie);
          if (routeIdMatch != null) {
            await prefs.setString('ROUTEID', routeIdMatch.group(1)!);
          }
        }
        
        return true; // Login deu certo!
      }
      return false; // Erro de credencial
    } catch (e) {
      return false; // Erro de internet ou servidor fora
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');

    if (baseUrl != null && session != null) {
      try {
        // Tenta deslogar no servidor do SAP para liberar a licença
        await http.post(
          Uri.parse('$baseUrl/Logout'),
          headers: {"Cookie": "B1SESSION=$session"},
        );
      } catch (_) {}
    }

    // Limpa os dados do celular
    await prefs.remove('B1SESSION');
    await prefs.remove('ROUTEID');
  }

  // ==========================================
  // MÉTODOS DE INVENTÁRIO / ESTOQUE
  // ==========================================

  /// Busca as informações de um Item no SAP pelo ItemCode (lido no código de barras)
  static Future<Map<String, dynamic>?> getItem(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return null;

    final response = await http.get(
      Uri.parse("$baseUrl/Items('$itemCode')?\$select=ItemCode,ItemName,BarCode"),
      headers: {
        "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    
    return null;
  }

  /// Envia as contagens offline para o SAP (Sincronização)
  static Future<bool> postInventoryCounting(List<Map<String, dynamic>> contagens) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return false;

    final payload = {
      "CountDate": DateTime.now().toIso8601String().split('T')[0],
      "InventoryCountingLines": contagens.map((c) => {
        "ItemCode": c['itemCode'],
        "CountedQuantity": c['quantidade'],
        "WarehouseCode": "01" // Altere se o armazém padrão for outro
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/InventoryCountings"),
        headers: {
          "Content-Type": "application/json",
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
        },
        body: jsonEncode(payload),
      );

      return response.statusCode == 201; // 201 Created significa sucesso no SAP
    } catch (e) {
      return false;
    }
  }
}