import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SapService {
  // ==========================================
  // CONFIGURAÇÃO DE CLIENTE (SSL) E URL
  // ==========================================

  static Future<http.Client> _getClient() async {
    final prefs = await SharedPreferences.getInstance();
    final permitirInseguro = prefs.getBool('sap_allow_untrusted') ?? true;

    if (permitirInseguro) {
      final ioClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  static String _prepareUrl(String url) {
    if (url.isEmpty) return "";
    return url.endsWith('/') ? url : '$url/';
  }

  // ==========================================
  // MÉTODOS DE AUTENTICAÇÃO
  // ==========================================

  static Future<bool> login({required String usuario, required String senha}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final company = prefs.getString('sap_company');

    if (baseUrl == null || company == null) return false;

    try {
      final client = await _getClient();
      final fullUrl = "${_prepareUrl(baseUrl)}Login";
      
      final response = await client.post(
        Uri.parse(fullUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "CompanyDB": company,
          "UserName": usuario,
          "Password": senha,
          "Language": 29
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sessionId = data['SessionId'];
        if (sessionId != null) await prefs.setString('B1SESSION', sessionId);

        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          final routeIdMatch = RegExp(r'ROUTEID=([^;]+)').firstMatch(rawCookie);
          if (routeIdMatch != null) {
            await prefs.setString('ROUTEID', routeIdMatch.group(1)!);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Erro no login: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');

    if (baseUrl != null && session != null) {
      try {
        final client = await _getClient();
        await client.post(
          Uri.parse("${_prepareUrl(baseUrl)}Logout"),
          headers: {"Cookie": "B1SESSION=$session"},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await prefs.remove('B1SESSION');
    await prefs.remove('ROUTEID');
  }

  // ==========================================
  // MÉTODOS DE CONSULTA
  // ==========================================

  static Future<List<dynamic>> searchItems(String termo) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return [];

    try {
      final client = await _getClient();
      final filter = "\$filter=contains(ItemCode, '$termo') or contains(ItemName, '$termo')";
      final fullUri = Uri.parse("${_prepareUrl(baseUrl)}Items?\$select=ItemCode,ItemName&$filter");

      final response = await client.get(
        fullUri,
        headers: {
          "Cookie": "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['value'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint("💥 Erro searchItems: $e");
    }
    return [];
  }

  /// NOVO: Método que estava faltando e causando erro no terminal
  static Future<Map<String, dynamic>?> getDetailedItem(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return null;

    try {
      final client = await _getClient();
      final cleanCode = itemCode.trim().toUpperCase();
      
      // Busca detalhes específicos incluindo estoque e flags de status
      const fields = "ItemCode,ItemName,InventoryUOM,InventoryItem,SalesItem,PurchaseItem,Frozen,ItemWarehouseInfoCollection";
      final url = "${_prepareUrl(baseUrl)}Items('$cleanCode')?\$select=$fields";
      
      final response = await client.get(
        Uri.parse(url),
        headers: {
          "Cookie": "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("💥 Erro getDetailedItem: $e");
    }
    return null;
  }

  // ==========================================
  // MÉTODOS DE INVENTÁRIO
  // ==========================================

  static Future<String?> postInventoryCounting(List<Map<String, dynamic>> contagens) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return "Sessão expirada.";

    final payload = {
      "CountDate": DateTime.now().toIso8601String().split('T')[0],
      "InventoryCountingLines": contagens.map((c) {
        final code = c['itemCode'].toString().trim().toUpperCase();
        final qtd = double.tryParse(c['quantidade'].toString()) ?? 0.0;

        return {
          "ItemCode": code,
          "WarehouseCode": "01",
          "CountedQuantity": qtd,
          "Counted": "tYES",
          "InventoryCountingBatchNumbers": [
            {
              "BatchNumber": code, // No caso do algodão, o código costuma ser o próprio lote
              "Quantity": qtd,
            }
          ]
        };
      }).toList(),
    };

    try {
      final client = await _getClient();
      final response = await client.post(
        Uri.parse("${_prepareUrl(baseUrl)}InventoryCountings"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Cookie": "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}",
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; 
      } else {
        return response.body;
      }
    } catch (e) {
      return "Falha de comunicação: $e";
    }
  }
}