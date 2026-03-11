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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE contagens (
        id $idType,
        itemCode $textType,
        quantidade $realType,
        dataHora $textType
      )
    ''');
  }

  // --- MÉTODOS DE OPERAÇÃO ---

  Future<int> inserirContagem(String itemCode, double quantidade) async {
    final db = await instance.database;
    final data = {
      'itemCode': itemCode.toUpperCase(), // Garante consistência no código
      'quantidade': quantidade,
      'dataHora': DateTime.now().toIso8601String(),
    };
    return await db.insert('contagens', data);
  }

  Future<int> atualizarContagem(int id, double novaQuantidade) async {
    final db = await instance.database;
    return await db.update(
      'contagens',
      {
        'quantidade': novaQuantidade,
        'dataHora': DateTime.now().toIso8601String(), // Atualiza a hora da edição
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> excluirContagem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'contagens',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await instance.database;
    // Retorna ordenado pela data mais recente
    return await db.query('contagens', orderBy: 'dataHora DESC');
  }

  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) as total FROM contagens WHERE itemCode = ?',
      [itemCode]
    );
    // Tratamento para garantir que retorne double mesmo se for nulo
    final total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }

  Future<void> limparContagens() async {
    final db = await instance.database;
    await db.delete('contagens');
  }

  Future close() async {
    final db = await instance.database;
    _database = null; // Limpa a referência para segurança
    await db.close();
  }
}