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

  /// Cria um cliente que ignora certificados inválidos (comum em servidores SAP locais)
  static Future<http.Client> _getClient() async {
    final prefs = await SharedPreferences.getInstance();
    final permitirInseguro = prefs.getBool('sap_allow_untrusted') ?? true;

    if (permitirInseguro) {
      final ioClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  /// Garante que a URL termine com barra para evitar erros de concatenação
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

        if (sessionId != null) {
          await prefs.setString('B1SESSION', sessionId);
        }

        // Captura do ROUTEID para suporte a Load Balancer do SAP
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
      debugPrint("❌ Erro de conexão no login: $e");
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
        final fullUrl = "${_prepareUrl(baseUrl)}Logout";
        await client.post(
          Uri.parse(fullUrl),
          headers: {"Cookie": "B1SESSION=$session"},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await prefs.remove('B1SESSION');
    await prefs.remove('ROUTEID');
  }

  // ==========================================
  // MÉTODOS DE CONSULTA (ITEM)
  // ==========================================

  /// Busca rápida para a lista de pesquisa
  static Future<List<dynamic>> searchItems(String termo) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return [];

    try {
      final client = await _getClient();
      final formattedUrl = _prepareUrl(baseUrl);
      
      final filter = "\$filter=ItemCode eq '$termo' or contains(ItemName, '$termo')";
      final select = "\$select=ItemCode,ItemName";
      final fullUri = Uri.parse("${formattedUrl}Items?$filter&$select");

      final response = await client.get(
        fullUri,
        headers: {
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['value'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("💥 Exceção ao pesquisar itens: $e");
      return [];
    }
  }

  /// Busca todos os detalhes de um item específico (Estoque por armazém, etc)
  static Future<Map<String, dynamic>?> getDetailedItem(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return null;

    try {
      final client = await _getClient();
      final formattedUrl = _prepareUrl(baseUrl);
      final cleanCode = itemCode.trim().toUpperCase();
      
      const fields = "ItemCode,ItemName,InventoryUOM,ItemWarehouseInfoCollection";
      final endpoint = "Items('$cleanCode')?\$select=$fields";
      
      final response = await client.get(
        Uri.parse("$formattedUrl$endpoint"),
        headers: {
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("💥 Exceção na busca detalhada: $e");
    }
    return null;
  }

  // ==========================================
  // MÉTODOS DE INVENTÁRIO (SINCRO)
  // ==========================================

  static Future<String?> postInventoryCounting(List<Map<String, dynamic>> contagens) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return "Sessão expirada. Faça login novamente.";

    final payload = {
      "CountDate": DateTime.now().toIso8601String().split('T')[0],
      "InventoryCountingLines": contagens.map((c) {
        return {
          "ItemCode": c['itemCode'].toString().toUpperCase(),
          "WarehouseCode": "01",
          "CountedQuantity": double.tryParse(c['quantidade'].toString()) ?? 0.0,
          "Counted": "tYES",
        };
      }).toList(),
    };

    try {
      final client = await _getClient();
      final fullUri = Uri.parse("${_prepareUrl(baseUrl)}InventoryCountings");

      final response = await client.post(
        fullUri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; // Sucesso
      } else {
        // RETORNA O JSON BRUTO para a HomePage identificar o erro -1310 ou 1470000497
        return response.body;
      }
    } catch (e) {
      return "Falha de comunicação: $e";
    }
  }
}