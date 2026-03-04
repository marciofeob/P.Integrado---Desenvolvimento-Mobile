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
    const realType = 'REAL NOT NULL'; // REAL suporta decimais, ideal para estoque

    await db.execute('''
CREATE TABLE contagens (
  id $idType,
  itemCode $textType,
  quantidade $realType,
  dataHora $textType
)
''');
  }

  Future<int> inserirContagem(String itemCode, double quantidade) async {
    final db = await instance.database;
    final data = {
      'itemCode': itemCode,
      'quantidade': quantidade,
      'dataHora': DateTime.now().toIso8601String(),
    };
    return await db.insert('contagens', data);
  }

  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await instance.database;
    return await db.query('contagens', orderBy: 'dataHora DESC');
  }

  Future<void> limparContagens() async {
    final db = await instance.database;
    await db.delete('contagens');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}