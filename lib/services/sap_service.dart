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

    if (baseUrl == null || company == null || baseUrl.isEmpty || company.isEmpty) return false;

    http.Client? client;
    try {
      client = await _getClient();
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

        // Extração segura dos cookies (B1SESSION e ROUTEID)
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
    } finally {
      client?.close(); // Essencial para evitar vazamento de sockets em produção
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');

    if (baseUrl != null && session != null && baseUrl.isNotEmpty) {
      http.Client? client;
      try {
        client = await _getClient();
        await client.post(
          Uri.parse("${_prepareUrl(baseUrl)}Logout"),
          headers: {"Cookie": "B1SESSION=$session"},
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("Aviso ao fazer logout no SAP: $e");
      } finally {
        client?.close();
      }
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

    if (baseUrl == null || session == null || baseUrl.isEmpty) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final termoLimpo = termo.replaceAll("'", "''"); // Previne quebra na query OData
      final filter = "\$filter=contains(ItemCode, '$termoLimpo') or contains(ItemName, '$termoLimpo')";
      final fullUri = Uri.parse("${_prepareUrl(baseUrl)}Items?\$select=ItemCode,ItemName&$filter");

      final cookieHeader = "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}";

      final response = await client.get(
        fullUri,
        headers: {
          "Cookie": cookieHeader,
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['value'] as List<dynamic>;
      } else if (response.statusCode == 401) {
        // Sessão expirou
        await logout();
      }
    } catch (e) {
      debugPrint("💥 Erro searchItems: $e");
    } finally {
      client?.close();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getDetailedItem(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null || baseUrl.isEmpty) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final cleanCode = itemCode.trim().toUpperCase().replaceAll("'", "''");
      
      const fields = "ItemCode,ItemName,InventoryUOM,InventoryItem,SalesItem,PurchaseItem,Frozen,ItemWarehouseInfoCollection";
      final url = "${_prepareUrl(baseUrl)}Items('$cleanCode')?\$select=$fields";
      
      final cookieHeader = "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}";

      final response = await client.get(
        Uri.parse(url),
        headers: {
          "Cookie": cookieHeader,
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await logout();
      }
    } catch (e) {
      debugPrint("💥 Erro getDetailedItem: $e");
    } finally {
      client?.close();
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

    if (baseUrl == null || session == null || baseUrl.isEmpty) return "Sessão expirada. Faça login novamente.";

    final payload = {
      "CountDate": DateTime.now().toIso8601String().split('T')[0],
      "InventoryCountingLines": contagens.map((c) {
        final code = c['itemCode'].toString().trim().toUpperCase();
        final qtd = double.tryParse(c['quantidade'].toString()) ?? 0.0;

        return {
          "ItemCode": code,
          "WarehouseCode": "01", // Depósito fixo conforme regra de negócio (ajustar se for dinâmico)
          "CountedQuantity": qtd,
          "Counted": "tYES",
          "InventoryCountingBatchNumbers": [
            {
              "BatchNumber": code, // Código usado como Lote no cenário do Agrobusiness
              "Quantity": qtd,
            }
          ]
        };
      }).toList(),
    };

    http.Client? client;
    try {
      client = await _getClient();
      final cookieHeader = "B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}";

      final response = await client.post(
        Uri.parse("${_prepareUrl(baseUrl)}InventoryCountings"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Cookie": cookieHeader,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; // Sucesso
      } else if (response.statusCode == 401) {
        await logout();
        return "Sessão expirada. Faça login novamente no SAP.";
      } else {
        // Tenta extrair a mensagem de erro da API do SAP
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return errorData['error']['message']['value'].toString();
          }
        } catch (_) {}
        return response.body; // Retorna o body bruto se não conseguir fazer o parse
      }
    } catch (e) {
      return "Falha de comunicação: $e";
    } finally {
      client?.close();
    }
  }
}