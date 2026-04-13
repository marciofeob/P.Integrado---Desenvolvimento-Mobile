import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton de acesso ao banco SQLite local do STOX.
///
/// Gerencia o ciclo de vida do banco, migrations e operações CRUD
/// das tabelas `contagens`, `envios` e `logs`.
///
/// Campos de controle — tabela `contagens`:
/// - `syncStatus`: 0 = Pendente, 1 = Sincronizado, 2 = Erro no envio.
/// - `countingMode`: `'single'` | `'single_doc'` | `'multiple'`.
/// - `counterID`: `InternalKey` SAP do contador (`null` = modo simples).
/// - `envioId`: referência ao registro de envio (`null` = ainda não enviado).
///
/// Campos de controle — tabela `envios`:
/// - `status`: 0 = Pendente, 1 = Sucesso, 2 = Erro.
///
/// Campos de controle — tabela `logs`:
/// - `nivel`: `'info'` | `'sucesso'` | `'aviso'` | `'erro'`.
/// - `categoria`: `'sync'` | `'auth'` | `'import'` | `'sistema'`.
///
/// Uso:
/// ```dart
/// final db = DatabaseHelper.instance;
/// await db.inserirContagem('PROD001', 10.0, warehouseCode: '01');
/// final lista = await db.buscarContagens();
/// ```
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Future de inicialização compartilhada — evita race condition
  /// quando múltiplas chamadas a [database] ocorrem simultaneamente.
  static Future<Database>? _initFuture;

  /// Nome do arquivo físico do banco.
  static const String _nomeArquivo = 'stox_offline.db';

  /// Versão atual do schema (incrementar ao adicionar migrations).
  static const int _versao = 4;

  /// Retenção máxima de logs em dias.
  /// Logs mais antigos são removidos automaticamente na inicialização.
  static const int _retencaoLogsDias = 90;

  DatabaseHelper._init();

  // ── Inicialização ─────────────────────────────────────────────────────────

  /// Retorna a instância do banco, criando-a se necessário.
  ///
  /// Chamadas simultâneas aguardam a mesma Future de inicialização,
  /// garantindo que apenas um banco seja aberto.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await (_initFuture ??= _initDB());
    return _database!;
  }

  Future<Database> _initDB() async {
    final caminho = join(await getDatabasesPath(), _nomeArquivo);
    final db = await openDatabase(
      caminho,
      version: _versao,
      onCreate: _criarTabelas,
      onUpgrade: _migrar,
    );

    // Auto-prune: remove logs com mais de 90 dias
    await _podarLogsAntigos(db);

    return db;
  }

  /// Cria o schema completo na primeira instalação.
  Future<void> _criarTabelas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contagens (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode      TEXT    NOT NULL,
        quantidade    REAL    NOT NULL,
        dataHora      TEXT    NOT NULL,
        syncStatus    INTEGER NOT NULL DEFAULT 0,
        warehouseCode TEXT    NOT NULL DEFAULT '01',
        countingMode  TEXT    NOT NULL DEFAULT 'single',
        counterID     INTEGER,
        counterName   TEXT,
        envioId       INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE envios (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        dataEnvio     TEXT    NOT NULL,
        modo          TEXT    NOT NULL,
        docEntry      INTEGER,
        docNumber     INTEGER,
        status        INTEGER NOT NULL DEFAULT 0,
        mensagemErro  TEXT,
        totalItens    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        dataHora   TEXT    NOT NULL,
        nivel      TEXT    NOT NULL,
        categoria  TEXT    NOT NULL,
        titulo     TEXT    NOT NULL,
        mensagem   TEXT,
        detalhes   TEXT
      )
    ''');

    // Índices — contagens
    await db.execute(
        'CREATE INDEX idx_itemCode     ON contagens (itemCode)');
    await db.execute(
        'CREATE INDEX idx_syncStatus   ON contagens (syncStatus)');
    await db.execute(
        'CREATE INDEX idx_counterID    ON contagens (counterID)');
    await db.execute(
        'CREATE INDEX idx_countingMode ON contagens (countingMode)');
    await db.execute(
        'CREATE INDEX idx_envioId      ON contagens (envioId)');

    // Índices — envios
    await db.execute(
        'CREATE INDEX idx_envios_status ON envios (status)');

    // Índices — logs
    await db.execute(
        'CREATE INDEX idx_logs_dataHora  ON logs (dataHora)');
    await db.execute(
        'CREATE INDEX idx_logs_nivel     ON logs (nivel)');
    await db.execute(
        'CREATE INDEX idx_logs_categoria ON logs (categoria)');
  }

  /// Aplica migrations incrementais para usuários que já tinham o banco.
  Future<void> _migrar(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE contagens ADD COLUMN warehouseCode "
        "TEXT NOT NULL DEFAULT '01'",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE contagens ADD COLUMN countingMode "
        "TEXT NOT NULL DEFAULT 'single'",
      );
      await db.execute(
        'ALTER TABLE contagens ADD COLUMN counterID INTEGER',
      );
      await db.execute(
        'ALTER TABLE contagens ADD COLUMN counterName TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_counterID ON contagens (counterID)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_countingMode '
        'ON contagens (countingMode)',
      );
    }
    if (oldVersion < 4) {
      // v3 → v4: rastreabilidade de envios + sistema de logs

      // Envios (fix bug de duplicação na sincronização)
      await db.execute(
        'ALTER TABLE contagens ADD COLUMN envioId INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envioId ON contagens (envioId)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS envios (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          dataEnvio     TEXT    NOT NULL,
          modo          TEXT    NOT NULL,
          docEntry      INTEGER,
          docNumber     INTEGER,
          status        INTEGER NOT NULL DEFAULT 0,
          mensagemErro  TEXT,
          totalItens    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envios_status ON envios (status)',
      );

      // Logs (registro de atividades do app)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logs (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          dataHora   TEXT    NOT NULL,
          nivel      TEXT    NOT NULL,
          categoria  TEXT    NOT NULL,
          titulo     TEXT    NOT NULL,
          mensagem   TEXT,
          detalhes   TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logs_dataHora ON logs (dataHora)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logs_nivel ON logs (nivel)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logs_categoria ON logs (categoria)',
      );
    }
    // Para futuras versões: if (oldVersion < 5) { ... }
  }

  /// Remove logs com mais de [_retencaoLogsDias] dias.
  ///
  /// Executado automaticamente na abertura do banco.
  /// Silencia erros para não impedir a inicialização do app.
  Future<void> _podarLogsAntigos(Database db) async {
    try {
      final corte = DateTime.now()
          .subtract(const Duration(days: _retencaoLogsDias))
          .toIso8601String();
      final removidos = await db.delete(
        'logs',
        where: 'dataHora < ?',
        whereArgs: [corte],
      );
      if (removidos > 0 && kDebugMode) {
        debugPrint('DatabaseHelper: $removidos logs antigos removidos '
            '(>${_retencaoLogsDias}d)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DatabaseHelper._podarLogsAntigos: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── CONTAGENS ─────────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  // ── Inserção e atualização ────────────────────────────────────────────────

  /// Insere uma nova contagem com status Pendente (0).
  ///
  /// Para modo simples, [counterID] e [counterName] são opcionais.
  /// Para modo múltiplo, informar obrigatoriamente o contador.
  ///
  /// Retorna o `id` da linha inserida.
  Future<int> inserirContagem(
    String itemCode,
    double quantidade, {
    String warehouseCode = '01',
    String countingMode = 'single',
    int? counterID,
    String? counterName,
  }) async {
    final db = await database;
    return db.insert('contagens', {
      'itemCode': itemCode.toUpperCase(),
      'quantidade': quantidade,
      'dataHora': DateTime.now().toIso8601String(),
      'syncStatus': 0,
      'warehouseCode': warehouseCode.toUpperCase(),
      'countingMode': countingMode,
      'counterID': counterID,
      'counterName': counterName,
    });
  }

  /// Atualiza a quantidade e redefine o status para Pendente (0).
  ///
  /// Também atualiza [dataHora] para o momento atual.
  /// Retorna o número de linhas afetadas (0 ou 1).
  Future<int> atualizarContagem(int id, double novaQuantidade) async {
    final db = await database;
    return db.update(
      'contagens',
      {
        'quantidade': novaQuantidade,
        'dataHora': DateTime.now().toIso8601String(),
        'syncStatus': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atualiza o status de sincronização de uma contagem.
  ///
  /// Valores válidos: 0 = Pendente, 1 = Sincronizado, 2 = Erro no envio.
  Future<int> atualizarStatusSincronizacao(int id, int novoStatus) async {
    final db = await database;
    return db.update(
      'contagens',
      {'syncStatus': novoStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Vincula um conjunto de contagens a um envio e atualiza o syncStatus.
  ///
  /// Usado após sincronização — marca cada contagem com o [envioId]
  /// e o [status] (1 = Sucesso, 2 = Erro).
  /// Usa batch para performance em listas grandes.
  Future<void> vincularContagensAoEnvio(
    List<int> ids,
    int envioId,
    int status,
  ) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'contagens',
        {'envioId': envioId, 'syncStatus': status},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Exclusão ──────────────────────────────────────────────────────────────

  /// Remove uma contagem pelo [id].
  ///
  /// Retorna o número de linhas afetadas (0 ou 1).
  Future<int> excluirContagem(int id) async {
    final db = await database;
    return db.delete('contagens', where: 'id = ?', whereArgs: [id]);
  }

  /// Remove todas as contagens (usado após sincronização bem-sucedida).
  Future<void> limparContagens() async {
    final db = await database;
    await db.delete('contagens');
  }

  /// Remove apenas as contagens com status Sincronizado (1).
  Future<void> limparContagensSincronizadas() async {
    final db = await database;
    await db.delete('contagens', where: 'syncStatus = ?', whereArgs: [1]);
  }

  // ── Consultas ─────────────────────────────────────────────────────────────

  /// Retorna todas as contagens, da mais recente para a mais antiga.
  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await database;
    return db.query('contagens', orderBy: 'dataHora DESC');
  }

  /// Retorna contagens filtradas por [counterID] (modo múltiplo).
  Future<List<Map<String, dynamic>>> buscarContagensPorContador(
    int counterID,
  ) async {
    final db = await database;
    return db.query(
      'contagens',
      where: 'counterID = ?',
      whereArgs: [counterID],
      orderBy: 'dataHora DESC',
    );
  }

  /// Retorna contagens filtradas por modo de contagem.
  Future<List<Map<String, dynamic>>> buscarContagensPorModo(
    String modo,
  ) async {
    final db = await database;
    return db.query(
      'contagens',
      where: 'countingMode = ?',
      whereArgs: [modo],
      orderBy: 'dataHora DESC',
    );
  }

  /// Retorna contagens Pendentes (0) ou com Erro (2), no formato FIFO.
  ///
  /// Ordem ASC garante que contagens mais antigas sejam sincronizadas primeiro.
  Future<List<Map<String, dynamic>>> buscarContagensPendentes() async {
    final db = await database;
    return db.query(
      'contagens',
      where: 'syncStatus IN (?, ?)',
      whereArgs: [0, 2],
      orderBy: 'dataHora ASC',
    );
  }

  /// Retorna os IDs distintos de contadores que participaram da contagem.
  Future<List<Map<String, dynamic>>> buscarContadoresDistintos() async {
    final db = await database;
    return db.rawQuery('''
      SELECT DISTINCT counterID, counterName
      FROM contagens
      WHERE countingMode = 'multiple' AND counterID IS NOT NULL
      ORDER BY counterID ASC
    ''');
  }

  /// Calcula a soma total de quantidade para um [itemCode] específico.
  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) AS total FROM contagens WHERE itemCode = ?',
      [itemCode.toUpperCase()],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── ENVIOS (rastreabilidade de sincronizações) ────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  /// Cria um registro de envio no início de uma sincronização.
  Future<int> criarEnvio({
    required String modo,
    required int totalItens,
    int? docEntry,
    int? docNumber,
  }) async {
    final db = await database;
    return db.insert('envios', {
      'dataEnvio': DateTime.now().toIso8601String(),
      'modo': modo,
      'docEntry': docEntry,
      'docNumber': docNumber,
      'status': 0,
      'totalItens': totalItens,
    });
  }

  /// Atualiza o resultado de um envio após a resposta do SAP.
  Future<void> finalizarEnvio(
    int envioId, {
    required int status,
    String? mensagemErro,
  }) async {
    final db = await database;
    await db.update(
      'envios',
      {'status': status, 'mensagemErro': mensagemErro},
      where: 'id = ?',
      whereArgs: [envioId],
    );
  }

  /// Retorna os envios mais recentes.
  Future<List<Map<String, dynamic>>> buscarEnvios({int limite = 50}) async {
    final db = await database;
    return db.query('envios', orderBy: 'dataEnvio DESC', limit: limite);
  }

  /// Remove todos os envios.
  Future<void> limparEnvios() async {
    final db = await database;
    await db.delete('envios');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── LOGS (registro de atividades do sistema) ──────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  /// Registra um evento no log do sistema.
  ///
  /// [nivel]: `'info'` | `'sucesso'` | `'aviso'` | `'erro'`.
  /// [categoria]: `'sync'` | `'auth'` | `'import'` | `'sistema'`.
  /// [titulo]: resumo curto do evento (ex: "Sincronização concluída").
  /// [mensagem]: detalhes legíveis para o operador.
  /// [detalhes]: informação técnica (ex: resposta do SAP, stack trace).
  ///
  /// Silencia erros — o log nunca deve impedir o funcionamento do app.
  Future<void> registrarLog({
    required String nivel,
    required String categoria,
    required String titulo,
    String? mensagem,
    String? detalhes,
  }) async {
    try {
      final db = await database;
      await db.insert('logs', {
        'dataHora': DateTime.now().toIso8601String(),
        'nivel': nivel,
        'categoria': categoria,
        'titulo': titulo,
        'mensagem': mensagem,
        'detalhes': detalhes,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('DatabaseHelper.registrarLog: $e');
    }
  }

  /// Atalhos de log por nível.
  Future<void> logInfo(String categoria, String titulo,
          {String? mensagem, String? detalhes}) =>
      registrarLog(
          nivel: 'info',
          categoria: categoria,
          titulo: titulo,
          mensagem: mensagem,
          detalhes: detalhes);

  Future<void> logSucesso(String categoria, String titulo,
          {String? mensagem, String? detalhes}) =>
      registrarLog(
          nivel: 'sucesso',
          categoria: categoria,
          titulo: titulo,
          mensagem: mensagem,
          detalhes: detalhes);

  Future<void> logAviso(String categoria, String titulo,
          {String? mensagem, String? detalhes}) =>
      registrarLog(
          nivel: 'aviso',
          categoria: categoria,
          titulo: titulo,
          mensagem: mensagem,
          detalhes: detalhes);

  Future<void> logErro(String categoria, String titulo,
          {String? mensagem, String? detalhes}) =>
      registrarLog(
          nivel: 'erro',
          categoria: categoria,
          titulo: titulo,
          mensagem: mensagem,
          detalhes: detalhes);

  /// Retorna logs filtrados por [nivel] e/ou [categoria].
  ///
  /// Sem filtros, retorna todos. Limitado a [limite] registros.
  Future<List<Map<String, dynamic>>> buscarLogs({
    String? nivel,
    String? categoria,
    int limite = 200,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <dynamic>[];

    if (nivel != null) {
      where.add('nivel = ?');
      args.add(nivel);
    }
    if (categoria != null) {
      where.add('categoria = ?');
      args.add(categoria);
    }

    return db.query(
      'logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'dataHora DESC',
      limit: limite,
    );
  }

  /// Retorna a quantidade total de logs por nível.
  ///
  /// Resultado: `{'info': 42, 'sucesso': 15, 'aviso': 3, 'erro': 2}`.
  Future<Map<String, int>> contarLogsPorNivel() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT nivel, COUNT(*) AS total FROM logs GROUP BY nivel',
    );
    final mapa = <String, int>{};
    for (final row in result) {
      mapa[row['nivel'] as String] = row['total'] as int;
    }
    return mapa;
  }

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  /// Fecha o banco e limpa as referências internas.
  ///
  /// Seguro para chamar mesmo que o banco nunca tenha sido aberto.
  @visibleForTesting
  Future<void> close() async {
    final db = _database;
    _database = null;
    _initFuture = null;
    await db?.close();
  }
}