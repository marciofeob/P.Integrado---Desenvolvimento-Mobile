import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton de acesso ao banco SQLite local do STOX.
///
/// Gerencia o ciclo de vida do banco, migrations e operações CRUD
/// da tabela `contagens`.
///
/// Campos de controle:
/// - `syncStatus`: 0 = Pendente, 1 = Sincronizado, 2 = Erro no envio.
/// - `countingMode`: `'single'` = Contador simples, `'multiple'` = Contadores múltiplos.
/// - `counterID`: `InternalKey` SAP do contador (`null` = modo simples).
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
  static const int _versao = 3;

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
    return openDatabase(
      caminho,
      version: _versao,
      onCreate: _criarTabelas,
      onUpgrade: _migrar,
    );
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
        counterName   TEXT
      )
    ''');

    // Índices para queries frequentes
    await db.execute(
        'CREATE INDEX idx_itemCode     ON contagens (itemCode)');
    await db.execute(
        'CREATE INDEX idx_syncStatus   ON contagens (syncStatus)');
    await db.execute(
        'CREATE INDEX idx_counterID    ON contagens (counterID)');
    await db.execute(
        'CREATE INDEX idx_countingMode ON contagens (countingMode)');
  }

  /// Aplica migrations incrementais para usuários que já tinham o banco.
  ///
  /// Cada bloco `if (oldVersion < N)` é executado uma única vez.
  /// Ao adicionar nova migration, incrementar [_versao] e adicionar bloco aqui.
  Future<void> _migrar(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: adição da coluna warehouseCode
      await db.execute(
        "ALTER TABLE contagens ADD COLUMN warehouseCode "
        "TEXT NOT NULL DEFAULT '01'",
      );
    }
    if (oldVersion < 3) {
      // v2 → v3: suporte a contadores múltiplos
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
    // Para futuras versões: if (oldVersion < 4) { ... }
  }

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

  /// Retorna contagens filtradas por modo de contagem (`'single'`/`'multiple'`).
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
  ///
  /// Útil para montar o bloco `IndividualCounters` do payload SAP.
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
  ///
  /// Retorna `0.0` se o item não existir no banco.
  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) AS total FROM contagens WHERE itemCode = ?',
      [itemCode.toUpperCase()],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
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