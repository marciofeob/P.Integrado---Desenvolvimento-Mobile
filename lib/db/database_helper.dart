import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('stox_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ✅ FIX: era 1, agora 2 (adicionamos warehouseCode)
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // ✅ FIX: handler de migração adicionado
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE contagens (
        id $idType,
        itemCode $textType,
        quantidade $realType,
        dataHora $textType,
        syncStatus $intType DEFAULT 0,
        warehouseCode $textType DEFAULT '01'
      )
    ''');

    await db.execute('CREATE INDEX idx_itemCode ON contagens (itemCode)');
    await db.execute('CREATE INDEX idx_syncStatus ON contagens (syncStatus)');
  }

  // ✅ FIX: Migração segura — quem tinha v1 recebe a nova coluna sem perder dados
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE contagens ADD COLUMN warehouseCode TEXT NOT NULL DEFAULT '01'",
      );
    }
    // Aqui você pode adicionar futuros blocos: if (oldVersion < 3) { ... }
  }

  // --- MÉTODOS DE OPERAÇÃO ---

  // ✅ FIX: warehouseCode agora é parâmetro nomeado opcional (não quebra callers antigos)
  Future<int> inserirContagem(
    String itemCode,
    double quantidade, {
    String warehouseCode = '01',
  }) async {
    final db = await instance.database;
    final data = {
      'itemCode': itemCode.toUpperCase(),
      'quantidade': quantidade,
      'dataHora': DateTime.now().toIso8601String(),
      'syncStatus': 0,
      'warehouseCode': warehouseCode.toUpperCase(),
    };
    return await db.insert('contagens', data);
  }

  Future<int> atualizarContagem(int id, double novaQuantidade) async {
    final db = await instance.database;
    return await db.update(
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

  Future<int> atualizarStatusSincronizacao(int id, int novoStatus) async {
    final db = await instance.database;
    return await db.update(
      'contagens',
      {'syncStatus': novoStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> excluirContagem(int id) async {
    final db = await instance.database;
    return await db.delete('contagens', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await instance.database;
    return await db.query('contagens', orderBy: 'dataHora DESC');
  }

  Future<List<Map<String, dynamic>>> buscarContagensPendentes() async {
    final db = await instance.database;
    return await db.query(
      'contagens',
      where: 'syncStatus IN (?, ?)',
      whereArgs: [0, 2],
      orderBy: 'dataHora ASC',
    );
  }

  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) as total FROM contagens WHERE itemCode = ?',
      [itemCode.toUpperCase()],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }

  Future<void> limparContagens() async {
    final db = await instance.database;
    await db.delete('contagens');
  }

  Future<void> limparContagensSincronizadas() async {
    final db = await instance.database;
    await db.delete('contagens', where: 'syncStatus = ?', whereArgs: [1]);
  }

  Future close() async {
    final db = await instance.database;
    _database = null;
    await db.close();
  }
}