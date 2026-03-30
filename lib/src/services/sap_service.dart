import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camada de acesso ao SAP Business One Service Layer (OData v2).
///
/// Todos os métodos são estáticos — a classe não deve ser instanciada.
/// A sessão é mantida via cookies B1SESSION/ROUTEID em [SharedPreferences].
class SapService {
  SapService._();

  // ── Cliente HTTP ──────────────────────────────────────────────────────────

  /// Cria um cliente HTTP respeitando a preferência de SSL do usuário.
  /// Sempre feche o cliente no bloco `finally` para evitar vazamento de sockets.
  static Future<http.Client> _getClient() async {
    final prefs            = await SharedPreferences.getInstance();
    final permitirInseguro = prefs.getBool('sap_allow_untrusted') ?? true;

    if (permitirInseguro) {
      final ioClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  static String _baseUrl(String url) =>
      url.isEmpty ? '' : (url.endsWith('/') ? url : '$url/');

  static String _cookie(String session, String? routeId) =>
      'B1SESSION=$session${routeId != null ? '; ROUTEID=$routeId' : ''}';

  // ── Autenticação ──────────────────────────────────────────────────────────

  /// Autentica o usuário no SAP e salva a sessão localmente.
  /// Retorna `true` em caso de sucesso.
  static Future<bool> login({
    required String usuario,
    required String senha,
  }) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')     ?? '';
    final company = prefs.getString('sap_company') ?? '';

    if (baseUrl.isEmpty || company.isEmpty) return false;

    http.Client? client;
    try {
      client = await _getClient();
      final response = await client.post(
        Uri.parse('${_baseUrl(baseUrl)}Login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'CompanyDB': company,
          'UserName':  usuario,
          'Password':  senha,
          'Language':  29,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final sessionId = data['SessionId'] as String?;
      if (sessionId != null) await prefs.setString('B1SESSION', sessionId);

      final rawCookie = response.headers['set-cookie'];
      if (rawCookie != null) {
        final match = RegExp(r'ROUTEID=([^;]+)').firstMatch(rawCookie);
        if (match != null) await prefs.setString('ROUTEID', match.group(1)!);
      }

      final nome = await _buscarNomeOperador(usuario);
      await prefs.setString('UserName', nome ?? usuario);

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.login: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  /// Busca o nome completo e InternalKey do operador pelo código de usuário SAP.
  ///
  /// Salva `InternalKey` em SharedPreferences como `sap_user_internal_key`.
  /// Esse valor é usado como `CounterID` na contagem múltipla.
  static Future<String?> _buscarNomeOperador(String userCode) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')     ?? '';
    final session = prefs.getString('B1SESSION')   ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final codigo = userCode.trim().replaceAll("'", "''");
      final uri    = Uri.parse(
          '${_baseUrl(baseUrl)}Users?\$select=UserName,InternalKey&\$filter=UserCode eq \'$codigo\'');

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final lista = (jsonDecode(response.body)['value'] as List?) ?? [];
        if (lista.isNotEmpty) {
          final user = lista.first as Map<String, dynamic>;
          // Salva InternalKey para uso como CounterID na contagem múltipla
          final internalKey = user['InternalKey'] as int?;
          if (internalKey != null) {
            await prefs.setInt('sap_user_internal_key', internalKey);
          }
          return user['UserName'] as String?;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SapService._buscarNomeOperador: $e');
    } finally {
      client?.close();
    }
    return null;
  }

  /// Invalida a sessão no servidor e limpa os dados locais.
  static Future<void> logout() async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';

    if (baseUrl.isNotEmpty && session.isNotEmpty) {
      http.Client? client;
      try {
        client = await _getClient();
        await client.post(
          Uri.parse('${_baseUrl(baseUrl)}Logout'),
          headers: {'Cookie': 'B1SESSION=$session'},
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        if (kDebugMode) debugPrint('SapService.logout: $e');
      } finally {
        client?.close();
      }
    }

    await prefs.remove('B1SESSION');
    await prefs.remove('ROUTEID');
    await prefs.remove('UserName');
    await prefs.remove('sap_user_internal_key');
  }

  // ── Consulta ──────────────────────────────────────────────────────────────

  /// Verifica se há sessão ativa sem fazer requisição de rede.
  static Future<bool> verificarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('sap_url')     ?? '').isNotEmpty &&
           (prefs.getString('B1SESSION')   ?? '').isNotEmpty;
  }

  /// Busca itens por código ou nome (máx. 20 resultados pelo OData padrão).
  static Future<List<dynamic>> searchItems(String termo) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final t   = termo.replaceAll("'", "''");
      final uri = Uri.parse(
          "${_baseUrl(baseUrl)}Items?\$select=ItemCode,ItemName"
          "&\$filter=contains(ItemCode,'$t') or contains(ItemName,'$t')");

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['value'] as List<dynamic>;
      }
      if (response.statusCode == 401) await logout();
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.searchItems: $e');
    } finally {
      client?.close();
    }
    return [];
  }

  /// Busca usuários SAP para configuração da equipe de contagem múltipla.
  ///
  /// Retorna lista de `{InternalKey, UserName, UserCode}` para seleção.
  static Future<List<dynamic>> buscarUsuariosSap() async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
          '${_baseUrl(baseUrl)}Users?\$select=InternalKey,UserName,UserCode');

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['value'] as List<dynamic>;
      }
      if (response.statusCode == 401) await logout();
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.buscarUsuariosSap: $e');
    } finally {
      client?.close();
    }
    return [];
  }

  /// Retorna os detalhes completos de um item, incluindo estoque por depósito
  /// e listas de preço. Campos confirmados com JSON real do SAP B1.
  static Future<Map<String, dynamic>?> getDetailedItem(String itemCode) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final code = itemCode.trim().toUpperCase().replaceAll("'", "''");

      const fields =
          'ItemCode,ItemName,ForeignName,InventoryUOM,'
          'InventoryItem,SalesItem,PurchaseItem,Frozen,'
          'BarCode,SWW,ItemsGroupCode,NCMCode,'
          'MinInventory,MaxInventory,MinOrderQuantity,'
          'ManageBatchNumbers,ManageSerialNumbers,'
          'SalesUnitWeight,SalesUnitHeight,SalesUnitWidth,SalesUnitLength,'
          'SalesUnit,SalesPackagingUnit,'
          'AvgStdPrice,MovingAveragePrice,'
          'QuantityOnStock,QuantityOrderedFromVendors,QuantityOrderedByCustomers,'
          'Mainsupplier,Manufacturer,'
          'ItemWarehouseInfoCollection,ItemPreferredVendors,ItemPrices';

      final uri = Uri.parse(
          "${_baseUrl(baseUrl)}Items('$code')?\$select=$fields");

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) await logout();
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.getDetailedItem: $e');
    } finally {
      client?.close();
    }
    return null;
  }

  // ── Inventário — Contador Simples ───────────────────────────────────────

  /// Cria um **novo** documento de contagem no SAP (modo contador simples).
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro legível.
  static Future<String?> postInventoryCounting(
    List<Map<String, dynamic>> contagens,
  ) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) {
      return 'Sessão expirada. Faça login novamente.';
    }

    final payload = {
      'CountDate': DateTime.now().toIso8601String().split('T')[0],
      'CountingType': 'ctSingleCounter',
      'InventoryCountingLines': contagens.map((c) {
        final code = c['itemCode'].toString().trim().toUpperCase();
        final qtd  = double.tryParse(c['quantidade'].toString()) ?? 0.0;
        return {
          'ItemCode':       code,
          'WarehouseCode':  c['warehouseCode']?.toString() ?? '01',
          'CountedQuantity': qtd,
          'Counted':        'tYES',
          'InventoryCountingBatchNumbers': [
            {'BatchNumber': code, 'Quantity': qtd},
          ],
        };
      }).toList(),
    };

    return _enviarRequest(baseUrl, session, routeId, 'POST',
        'InventoryCountings', payload);
  }

  // ── Inventário — Contadores Múltiplos ─────────────────────────────────

  /// Busca documentos de contagem **abertos** no SAP.
  ///
  /// Retorna a lista de documentos com `DocumentStatus eq 'cdsOpen'`.
  /// Cada item contém: `DocumentEntry`, `DocumentNumber`, `CountDate`,
  /// `CountingType`, `Remarks`, e a lista de `IndividualCounters`.
  static Future<List<dynamic>> buscarDocumentosAbertos() async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
          '${_baseUrl(baseUrl)}InventoryCountings'
          '?\$select=DocumentEntry,DocumentNumber,CountDate,CountingType,Remarks,IndividualCounters'
          "&\$filter=DocumentStatus eq 'cdsOpen'"
          '&\$orderby=DocumentEntry desc');

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['value'] as List?) ?? [];
      }
      if (response.statusCode == 401) await logout();
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.buscarDocumentosAbertos: $e');
    } finally {
      client?.close();
    }
    return [];
  }

  /// Busca os detalhes completos de um documento de contagem (linhas + contadores).
  ///
  /// Usa o [documentEntry] (chave primária, não confundir com DocumentNumber).
  static Future<Map<String, dynamic>?> buscarDetalhesDocumento(
      int documentEntry) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
          '${_baseUrl(baseUrl)}InventoryCountings($documentEntry)');

      final response = await client.get(uri, headers: {
        'Cookie': _cookie(session, routeId),
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) await logout();
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.buscarDetalhesDocumento: $e');
    } finally {
      client?.close();
    }
    return null;
  }

  /// Atualiza um documento de contagem **existente** via PATCH (modo múltiplo).
  ///
  /// O SAP B1 valida consistência entre linhas do mesmo `LineNumber`:
  /// todas devem ter o mesmo `Counted` (Y ou N). Por isso o PATCH precisa
  /// enviar **TODAS** as linhas do documento — atualizando as deste
  /// [counterID] e mantendo as dos outros contadores inalteradas.
  ///
  /// Fluxo:
  /// 1. GET o documento completo
  /// 2. Para cada linha: se é do nosso counterID e temos contagem → atualiza
  /// 3. Envia TODAS as linhas no PATCH
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro legível.
  static Future<String?> patchInventoryCounting({
    required int documentEntry,
    required List<Map<String, dynamic>> contagens,
    required int counterID,
  }) async {
    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url')   ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) {
      return 'Sessão expirada. Faça login novamente.';
    }

    // 1. GET o documento completo
    final doc = await buscarDetalhesDocumento(documentEntry);
    if (doc == null) {
      return 'Não foi possível carregar o documento #$documentEntry do SAP.';
    }

    final linhasDoc = (doc['InventoryCountingLines'] as List?) ?? [];
    if (linhasDoc.isEmpty) {
      return 'O documento #$documentEntry não possui linhas de contagem.';
    }

    // Mapa das contagens do operador: ItemCode (uppercase) → quantidade
    final contagensMap = <String, double>{};
    for (final c in contagens) {
      final code = c['itemCode'].toString().trim().toUpperCase();
      final qtd  = double.tryParse(c['quantidade'].toString()) ?? 0.0;
      contagensMap[code] = qtd;
    }

    // 2. Reconstrói TODAS as linhas do documento
    final todasLinhas = <Map<String, dynamic>>[];
    int atualizadas = 0;

    for (final linha in linhasDoc) {
      final cid      = linha['CounterID'] as int? ?? 0;
      final code     = (linha['ItemCode'] as String? ?? '').toUpperCase();
      final lineNum  = linha['LineNumber'] as int? ?? 0;

      // É a linha deste contador E temos contagem para este item?
      if (cid == counterID && contagensMap.containsKey(code)) {
        final qtd = contagensMap[code]!;
        todasLinhas.add({
          'LineNumber':      lineNum,
          'CounterID':       counterID,
          'CounterType':     'ctUser',
          'CountedQuantity': qtd,
          'Counted':         'tNO',
        });
        atualizadas++;
      } else {
        // Linha de outro contador ou item que não contamos → manda como está
        todasLinhas.add({
          'LineNumber':      lineNum,
          'CounterID':       cid,
          'CounterType':     linha['CounterType'] ?? 'ctUser',
          'CountedQuantity': linha['CountedQuantity'] ?? 0.0,
          'Counted':         linha['Counted'] ?? 'tNO',
        });
      }
    }

    if (atualizadas == 0) {
      final faltando = contagensMap.keys.toList();
      return 'Nenhum item da sua contagem foi encontrado no documento SAP.\n'
          'Itens: ${faltando.join(', ')}.\n'
          'Verifique se o documento correto foi selecionado.';
    }

    // 3. PATCH com TODAS as linhas
    final payload = {
      'InventoryCountingLines': todasLinhas,
    };

    return _enviarRequest(baseUrl, session, routeId, 'PATCH',
        'InventoryCountings($documentEntry)', payload);
  }

  /// Retorna o `InternalKey` do usuário logado (salvo no login).
  ///
  /// Usado como `CounterID` na contagem múltipla.
  static Future<int?> getCounterID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('sap_user_internal_key');
  }

  // ── Request genérico ──────────────────────────────────────────────────

  /// Envia POST ou PATCH para o Service Layer e trata a resposta.
  static Future<String?> _enviarRequest(
    String baseUrl,
    String session,
    String? routeId,
    String metodo,
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    http.Client? client;
    try {
      client = await _getClient();

      final uri     = Uri.parse('${_baseUrl(baseUrl)}$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'Cookie':       _cookie(session, routeId),
      };
      final body = jsonEncode(payload);

      final response = metodo == 'PATCH'
          ? await client.patch(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30))
          : await client.post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));

      // 200, 201 = sucesso POST; 204 = sucesso PATCH
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return null;
      }

      if (response.statusCode == 401) {
        await logout();
        return 'Sessão expirada. Faça login novamente no SAP.';
      }

      try {
        final err = jsonDecode(response.body);
        return err['error']?['message']?['value']?.toString() ?? response.body;
      } catch (_) {
        return response.body;
      }
    } catch (e) {
      return 'Falha de comunicação: $e';
    } finally {
      client?.close();
    }
  }
}