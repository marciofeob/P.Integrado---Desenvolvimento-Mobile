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

  /// Cria um cliente HTTP que respeita a configuração de SSL do usuário
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

  /// Helper para garantir que a URL base termina com '/'
  static String _prepareUrl(String url) {
    if (url.isEmpty) return "";
    return url.endsWith('/') ? url : '$url/';
  }

  // ==========================================
  // MÉTODOS DE AUTENTICAÇÃO
  // ==========================================

  static Future<bool> login({
    required String usuario,
    required String senha,
  }) async {
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
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sessionId = data['SessionId'];

        if (sessionId != null) {
          await prefs.setString('B1SESSION', sessionId);
        }

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

  /// NOVO MÉTODO: Busca itens por código ou nome (contém texto)
  static Future<List<dynamic>> searchItems(String termo) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return [];

    try {
      final client = await _getClient();
      final formattedUrl = _prepareUrl(baseUrl);
      
      // Filtro OData: Busca exata pelo código OU se o nome contém o termo
      // Nota: 'contains' diferencia maiúsculas/minúsculas dependendo da config do BD SAP, 
      // mas geralmente funciona bem para buscas rápidas.
      final filter = "\$filter=ItemCode eq '$termo' or contains(ItemName, '$termo')";
      final select = "\$select=ItemCode,ItemName";
      
      final fullUri = Uri.parse("${formattedUrl}Items?$filter&$select");

      debugPrint("🔍 Buscando lista de itens em: $fullUri");

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
      } else {
        debugPrint("❌ Erro na busca SAP: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("💥 Exceção ao pesquisar itens: $e");
      return [];
    }
  }

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
      
      const fields = "ItemCode,ItemName,InventoryItem,SalesItem,PurchaseItem,InventoryUOM,PurchaseUnit,SalesUnit,SalesPackagingUnit,Frozen,ItemWarehouseInfoCollection";
      
      final endpoint = "Items('$cleanCode')?\$select=$fields";
      final fullUri = Uri.parse("$formattedUrl$endpoint");
      
      debugPrint("🔍 Efetuando busca dinâmica em: $fullUri");

      final response = await client.get(
        fullUri,
        headers: {
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint("❌ Erro SAP (${response.statusCode}): ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("💥 Exceção na busca detalhada: $e");
      return null;
    }
  }

  // ==========================================
  // MÉTODOS DE INVENTÁRIO (SINCRO)
  // ==========================================

  static Future<String?> postInventoryCounting(
    List<Map<String, dynamic>> contagens,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return "Sessão expirada ou configuração ausente.";

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
      final formattedUrl = _prepareUrl(baseUrl);
      final fullUri = Uri.parse("${formattedUrl}InventoryCountings");

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
        return null;
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          String sapMessage = errorBody['error']['message']['value'] ?? 
                               errorBody['error']['message'].toString();
          return "SAP diz: $sapMessage";
        } catch (_) {
          return "Erro servidor (${response.statusCode})";
        }
      }
    } catch (e) {
      debugPrint("Exceção na sincronização: $e");
      return "Falha de comunicação. Verifique o Wi-Fi.";
    }
  }
}