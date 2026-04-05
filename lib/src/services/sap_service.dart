import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camada de acesso ao SAP Business One Service Layer (OData v2).
///
/// Todos os métodos são estáticos — a classe não deve ser instanciada.
/// A sessão é mantida via cookies `B1SESSION`/`ROUTEID` em [SharedPreferences].
class SapService {
  SapService._();

  static const _timeoutLeitura = Duration(seconds: 15);
  static const _timeoutEscrita = Duration(seconds: 30);

  // ── Campos que NÃO devem ser enviados no PATCH ────────────────────────────
  //
  // Inclui campos calculados/somente-leitura E campos de consistência que
  // causam erro 234000012 quando enviados com valor diferente entre linhas
  // (ex: Remarks, que o SAP compara linha a linha e rejeita divergências).
  static const _camposExcluirPatch = {
    // Calculados / somente-leitura
    'DocumentEntry',
    'ItemDescription',
    'Freeze',
    'BinEntry',
    'InWarehouseQuantity',
    'Variance',
    'VariancePercentage',
    'VisualOrder',
    'TargetEntry',
    'TargetLine',
    'TargetType',
    'TargetReference',
    'Manufacturer',
    'SupplierCatalogNo',
    'PreferredVendor',
    'LineStatus',
    'MultipleCounterRole',
    'InventoryCountingLineUoMs',
    'InventoryCountingSerialNumbers',
    'InventoryCountingBatchNumbers',
    'UoMCountedQuantity',
    'ItemsPerUnit',
    // Campos de texto livre — SAP preserva automaticamente se omitidos;
    // enviá-los causa erro 234000012 quando valores diferem entre linhas.
    'Remarks',
  };

  /// Constrói o mapa de campos de uma linha seguro para enviar no PATCH.
  ///
  /// Copia os campos escalares da linha original excluindo os campos em
  /// [_camposExcluirPatch]. Valores `null` são preservados como `null`
  /// (não convertidos para `''`) para evitar divergências de consistência.
  static Map<String, dynamic> _linhaParaPatch(Map<String, dynamic> linha) {
    final resultado = <String, dynamic>{};
    for (final entry in linha.entries) {
      if (_camposExcluirPatch.contains(entry.key)) continue;
      final v = entry.value;
      // Inclui apenas escalares (String, num, bool, null)
      // Listas e mapas aninhados são excluídos implicitamente
      if (v == null || v is String || v is num || v is bool) {
        resultado[entry.key] = v; // null permanece null — não converter para ''
      }
    }
    return resultado;
  }

  // ── Cliente HTTP ──────────────────────────────────────────────────────────

  static Future<http.Client> _getClient() async {
    final prefs = await SharedPreferences.getInstance();
    final permitirInseguro = prefs.getBool('sap_allow_untrusted') ?? true;

    if (permitirInseguro) {
      final ioClient = HttpClient()
        ..connectionTimeout = _timeoutLeitura
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

  // ── Contexto de sessão ────────────────────────────────────────────────────

  static Future<_SapContext?> _obterContexto() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url') ?? '';
    final session = prefs.getString('B1SESSION') ?? '';
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl.isEmpty || session.isEmpty) return null;

    return _SapContext(
      prefs: prefs,
      baseUrl: _baseUrl(baseUrl),
      session: session,
      routeId: routeId,
    );
  }

  static Map<String, String> _headersGet(_SapContext ctx) => {
        'Cookie': _cookie(ctx.session, ctx.routeId),
        'Accept': 'application/json',
      };

  // ── Autenticação ──────────────────────────────────────────────────────────

  static Future<bool> login({
    required String usuario,
    required String senha,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url') ?? '';
    final company = prefs.getString('sap_company') ?? '';

    if (baseUrl.isEmpty || company.isEmpty) return false;

    http.Client? client;
    try {
      client = await _getClient();
      final response = await client
          .post(
            Uri.parse('${_baseUrl(baseUrl)}Login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CompanyDB': company,
              'UserName': usuario,
              'Password': senha,
              'Language': 29,
            }),
          )
          .timeout(_timeoutLeitura);

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
      await prefs.setString('sap_user_code', usuario);

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('SapService.login: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  static Future<String?> _buscarNomeOperador(String userCode) async {
    final ctx = await _obterContexto();
    if (ctx == null) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final codigo = userCode.trim().replaceAll("'", "''");
      final uri = Uri.parse(
        '${ctx.baseUrl}Users?'
        '\$select=UserName,InternalKey&'
        "\$filter=UserCode eq '$codigo'",
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

      if (response.statusCode == 200) {
        final lista = (jsonDecode(response.body)['value'] as List?) ?? [];
        if (lista.isNotEmpty) {
          final user = lista.first as Map<String, dynamic>;
          final internalKey = user['InternalKey'] as int?;
          if (internalKey != null) {
            await ctx.prefs.setInt('sap_user_internal_key', internalKey);
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

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url') ?? '';
    final session = prefs.getString('B1SESSION') ?? '';

    if (baseUrl.isNotEmpty && session.isNotEmpty) {
      http.Client? client;
      try {
        client = await _getClient();
        await client
            .post(
              Uri.parse('${_baseUrl(baseUrl)}Logout'),
              headers: {'Cookie': 'B1SESSION=$session'},
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        if (kDebugMode) debugPrint('SapService.logout: $e');
      } finally {
        client?.close();
      }
    }

    await Future.wait([
      prefs.remove('B1SESSION'),
      prefs.remove('ROUTEID'),
      prefs.remove('UserName'),
      prefs.remove('sap_user_internal_key'),
    ]);
  }

  // ── Consultas ─────────────────────────────────────────────────────────────

  static Future<bool> verificarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('sap_url') ?? '').isNotEmpty &&
        (prefs.getString('B1SESSION') ?? '').isNotEmpty;
  }

  static Future<List<dynamic>> searchItems(String termo) async {
    final ctx = await _obterContexto();
    if (ctx == null) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final t = termo.replaceAll("'", "''");
      final uri = Uri.parse(
        '${ctx.baseUrl}Items?'
        '\$select=ItemCode,ItemName&'
        "\$filter=contains(ItemCode,'$t') or contains(ItemName,'$t')",
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

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

  static Future<List<dynamic>> buscarUsuariosSap() async {
    final ctx = await _obterContexto();
    if (ctx == null) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
        '${ctx.baseUrl}Users?\$select=InternalKey,UserName,UserCode',
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

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

  static Future<Map<String, dynamic>?> getDetailedItem(
    String itemCode,
  ) async {
    final ctx = await _obterContexto();
    if (ctx == null) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final code = itemCode.trim().toUpperCase().replaceAll("'", "''");

      const fields = 'ItemCode,ItemName,ForeignName,InventoryUOM,'
          'InventoryItem,SalesItem,PurchaseItem,Frozen,'
          'BarCode,SWW,ItemsGroupCode,NCMCode,'
          'MinInventory,MaxInventory,MinOrderQuantity,'
          'ManageBatchNumbers,ManageSerialNumbers,'
          'SalesUnitWeight,SalesUnitHeight,SalesUnitWidth,SalesUnitLength,'
          'SalesUnit,SalesPackagingUnit,'
          'AvgStdPrice,MovingAveragePrice,'
          'QuantityOnStock,QuantityOrderedFromVendors,'
          'QuantityOrderedByCustomers,'
          'Mainsupplier,Manufacturer,'
          'ItemWarehouseInfoCollection,ItemPreferredVendors,ItemPrices';

      final uri = Uri.parse(
        "${ctx.baseUrl}Items('$code')?\$select=$fields",
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

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

  // ── Inventário — Contador Simples ─────────────────────────────────────────

  /// Cria um **novo** documento de contagem no SAP (modo contador simples).
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro legível.
  /// Regra de negócio Agrobusiness: `BatchNumber = ItemCode`.
  static Future<String?> postInventoryCounting(
    List<Map<String, dynamic>> contagens,
  ) async {
    final ctx = await _obterContexto();
    if (ctx == null) return 'Sessão expirada. Faça login novamente.';

    final payload = {
      'CountDate': DateTime.now().toIso8601String().split('T')[0],
      'CountingType': 'ctSingleCounter',
      'InventoryCountingLines': contagens.map((c) {
        final code = c['itemCode'].toString().trim().toUpperCase();
        final qtd = double.tryParse(c['quantidade'].toString()) ?? 0.0;
        return {
          'ItemCode': code,
          'WarehouseCode': c['warehouseCode']?.toString() ?? '01',
          'CountedQuantity': qtd,
          'Counted': 'tNO',
          'InventoryCountingBatchNumbers': [
            {'BatchNumber': code, 'Quantity': qtd},
          ],
        };
      }).toList(),
    };

    return _enviarRequest(ctx, 'POST', 'InventoryCountings', payload);
  }

  /// Atualiza um documento de contagem **simples** existente via PATCH.
  ///
  /// Regra: só atualiza linhas que ainda não foram aprovadas pelo gerente
  /// (`Counted = tNO`). Linhas com `Counted = tYES` são preservadas como
  /// estão — o gerente já aprovou e não deve ser sobrescrito.
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro legível.
  static Future<String?> patchSingleCounting({
    required int documentEntry,
    required List<Map<String, dynamic>> contagens,
  }) async {
    final ctx = await _obterContexto();
    if (ctx == null) return 'Sessão expirada. Faça login novamente.';

    final doc = await buscarDetalhesDocumento(documentEntry);
    if (doc == null) {
      return 'Não foi possível carregar o documento #$documentEntry do SAP.';
    }

    final linhasDoc = (doc['InventoryCountingLines'] as List?) ?? [];
    if (linhasDoc.isEmpty) {
      return 'O documento #$documentEntry não possui linhas de contagem.';
    }

    final contagensMap = <String, double>{};
    for (final c in contagens) {
      final code = c['itemCode'].toString().trim().toUpperCase();
      final qtd = double.tryParse(c['quantidade'].toString()) ?? 0.0;
      contagensMap[code] = qtd;
    }

    final todasLinhas = <Map<String, dynamic>>[];
    int atualizadas = 0;

    for (final linha in linhasDoc) {
      final raw = linha as Map<String, dynamic>;
      final code = (raw['ItemCode'] as String? ?? '').toUpperCase();
      if (code.isEmpty) continue;

      final base = _linhaParaPatch(raw);
      final jaAprovado = (raw['Counted'] as String?) == 'tYES';

      if (!jaAprovado && contagensMap.containsKey(code)) {
        // Linha ainda não aprovada + temos contagem → atualizar
        todasLinhas.add({
          ...base,
          'CountedQuantity': contagensMap[code]!,
          'Counted': 'tNO',
        });
        atualizadas++;
      } else {
        // Linha aprovada pelo gerente (tYES) ou sem contagem → preservar
        todasLinhas.add(base);
      }
    }

    if (atualizadas == 0) {
      final faltando = contagensMap.keys.toList();
      return 'Nenhum item pendente foi encontrado no documento SAP.\n'
          'Os itens já podem ter sido aprovados pelo gerente (Contado = SIM).\n'
          'Itens: ${faltando.join(', ')}.';
    }

    return _enviarRequest(
      ctx,
      'PATCH',
      'InventoryCountings($documentEntry)',
      {'InventoryCountingLines': todasLinhas},
    );
  }

  // ── Inventário — Contadores Múltiplos ─────────────────────────────────────

  /// Busca documentos de contagem **abertos** no SAP (`DocumentStatus = cdsOpen`).
  static Future<List<dynamic>> buscarDocumentosAbertos() async {
    final ctx = await _obterContexto();
    if (ctx == null) return [];

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
        '${ctx.baseUrl}InventoryCountings?'
        '\$select=DocumentEntry,DocumentNumber,CountDate,'
        'CountingType,Remarks,IndividualCounters&'
        "\$filter=DocumentStatus eq 'cdsOpen'&"
        '\$orderby=DocumentEntry desc',
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

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

  static Future<Map<String, dynamic>?> buscarDetalhesDocumento(
    int documentEntry,
  ) async {
    final ctx = await _obterContexto();
    if (ctx == null) return null;

    http.Client? client;
    try {
      client = await _getClient();
      final uri = Uri.parse(
        '${ctx.baseUrl}InventoryCountings($documentEntry)',
      );

      final response = await client
          .get(uri, headers: _headersGet(ctx))
          .timeout(_timeoutLeitura);

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
  /// Regras de negócio:
  /// - Envia APENAS as linhas do [counterID] atual (evita erro 234000035).
  /// - Usa `_linhaParaPatch` para copiar campos originais sem converter null
  ///   (evita erro 234000012 em campos como OcrCode, ProjCode, etc.).
  /// - Pula linhas já aprovadas pelo gerente (`Counted = tYES`) — o gerente
  ///   já finalizou a aprovação, não sobrescrever.
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro legível.
  static Future<String?> patchInventoryCounting({
    required int documentEntry,
    required List<Map<String, dynamic>> contagens,
    required int counterID,
  }) async {
    final ctx = await _obterContexto();
    if (ctx == null) return 'Sessão expirada. Faça login novamente.';

    // 1. GET o documento completo
    final doc = await buscarDetalhesDocumento(documentEntry);
    if (doc == null) {
      return 'Não foi possível carregar o documento #$documentEntry do SAP.';
    }

    // Verifica se o documento ainda está aberto
    final status = doc['DocumentStatus'] as String? ?? '';
    if (status == 'cdsClosed') {
      return 'O documento #$documentEntry já está fechado no SAP.\n'
          'Selecione um documento aberto (Status: Aberto) para sincronizar.';
    }

    final linhasDoc = (doc['InventoryCountingLines'] as List?) ?? [];
    if (linhasDoc.isEmpty) {
      return 'O documento #$documentEntry não possui linhas de contagem.';
    }

    // Mapa: ItemCode (uppercase) → quantidade contada pelo operador
    final contagensMap = <String, double>{};
    for (final c in contagens) {
      final code = c['itemCode'].toString().trim().toUpperCase();
      final qtd = double.tryParse(c['quantidade'].toString()) ?? 0.0;
      contagensMap[code] = qtd;
    }

    // 2. Filtra apenas as linhas deste contador.
    //    - Pula linhas de outros contadores (evita 234000035).
    //    - Pula linhas já aprovadas pelo gerente (Counted = tYES).
    //    - Usa _linhaParaPatch para preservar todos os campos de consistência.
    final linhasDoContador = <Map<String, dynamic>>[];
    int atualizadas = 0;
    int ignoradasAprovadas = 0;

    for (final linha in linhasDoc) {
      final raw = linha as Map<String, dynamic>;
      final cid = raw['CounterID'] as int? ?? 0;
      final code = (raw['ItemCode'] as String? ?? '').toUpperCase();
      final jaAprovado = (raw['Counted'] as String?) == 'tYES';

      // Pula linhas sem ItemCode ou de outros contadores
      if (code.isEmpty || cid != counterID) continue;

      // Pula linhas já aprovadas pelo gerente (não sobrescrever tYES)
      if (jaAprovado) {
        ignoradasAprovadas++;
        continue;
      }

      final base = _linhaParaPatch(raw);

      if (contagensMap.containsKey(code)) {
        // Linha do nosso contador com contagem → atualizar
        linhasDoContador.add({
          ...base,
          'CountedQuantity': contagensMap[code]!,
          'Counted': 'tNO', // Só o gerente marca tYES no SAP
        });
        atualizadas++;
      } else {
        // Linha do nosso contador sem contagem → preservar como está
        linhasDoContador.add(base);
      }
    }

    if (atualizadas == 0) {
      if (ignoradasAprovadas > 0) {
        return 'Todos os itens da sua contagem já foram aprovados pelo gerente.\n'
            'Nenhuma atualização necessária.';
      }
      final faltando = contagensMap.keys.toList();
      return 'Nenhum item da sua contagem foi encontrado no documento SAP.\n'
          'Itens: ${faltando.join(', ')}.\n'
          'Verifique se o documento correto foi selecionado.';
    }

    // 3. PATCH apenas com as linhas deste contador
    return _enviarRequest(
      ctx,
      'PATCH',
      'InventoryCountings($documentEntry)',
      {'InventoryCountingLines': linhasDoContador},
    );
  }

  /// Retorna o `InternalKey` do usuário logado (salvo no login).
  ///
  /// Usado como `CounterID` na contagem múltipla.
  static Future<int?> getCounterID() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('sap_user_internal_key');
    if (stored != null) return stored;

    final userCode = prefs.getString('sap_user_code') ?? '';
    if (userCode.isNotEmpty) {
      await _buscarNomeOperador(userCode);
      return prefs.getInt('sap_user_internal_key');
    }
    return null;
  }

  // ── Request genérico ──────────────────────────────────────────────────────

  static Future<String?> _enviarRequest(
    _SapContext ctx,
    String metodo,
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    http.Client? client;
    try {
      client = await _getClient();

      final uri = Uri.parse('${ctx.baseUrl}$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': _cookie(ctx.session, ctx.routeId),
      };
      final body = jsonEncode(payload);

      final response = metodo == 'PATCH'
          ? await client
              .patch(uri, headers: headers, body: body)
              .timeout(_timeoutEscrita)
          : await client
              .post(uri, headers: headers, body: body)
              .timeout(_timeoutEscrita);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return null;
      }

      if (response.statusCode == 401) {
        await logout();
        return 'Sessão expirada. Faça login novamente no SAP.';
      }

      return _extrairMensagemErro(response.body);
    } catch (e) {
      return 'Falha de comunicação: $e';
    } finally {
      client?.close();
    }
  }

  static String _extrairMensagemErro(String responseBody) {
    try {
      final err = jsonDecode(responseBody);
      return err['error']?['message']?['value']?.toString() ?? responseBody;
    } catch (_) {
      return responseBody;
    }
  }
}

/// Contexto de sessão SAP — agrupa dados que se repetiam em todos os métodos.
class _SapContext {
  final SharedPreferences prefs;
  final String baseUrl;
  final String session;
  final String? routeId;

  const _SapContext({
    required this.prefs,
    required this.baseUrl,
    required this.session,
    this.routeId,
  });
}