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
    const intType = 'INTEGER NOT NULL';

    // Criação da tabela com a coluna de syncStatus (0: Pendente, 1: Sincronizado, 2: Erro)
    await db.execute('''
      CREATE TABLE contagens (
        id $idType,
        itemCode $textType,
        quantidade $realType,
        dataHora $textType,
        syncStatus $intType DEFAULT 0
      )
    ''');

    // Criação de índices para otimizar buscas em tabelas volumosas
    await db.execute('CREATE INDEX idx_itemCode ON contagens (itemCode)');
    await db.execute('CREATE INDEX idx_syncStatus ON contagens (syncStatus)');
  }

  // --- MÉTODOS DE OPERAÇÃO ---

  Future<int> inserirContagem(
    String itemCode,
    double quantidade, {
    String warehouseCode = '01',
  }) async {
    final db = await instance.database;
    final data = {
      'itemCode':      itemCode.toUpperCase(),
      'quantidade':    quantidade,
      'dataHora':      DateTime.now().toIso8601String(),
      'syncStatus':    0,
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
        'dataHora': DateTime.now().toIso8601String(), // Atualiza a hora da edição
        'syncStatus': 0, // Retorna para pendente, pois o valor foi alterado
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> atualizarStatusSincronizacao(int id, int novoStatus) async {
    final db = await instance.database;
    return await db.update(
      'contagens',
      {
        'syncStatus': novoStatus,
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

  Future<List<Map<String, dynamic>>> buscarContagensPendentes() async {
    final db = await instance.database;
    // Busca apenas as contagens que não foram enviadas ou deram erro
    return await db.query(
      'contagens',
      where: 'syncStatus IN (?, ?)',
      whereArgs: [0, 2],
      orderBy: 'dataHora ASC', // FIFO: envia as mais antigas primeiro
    );
  }

  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) as total FROM contagens WHERE itemCode = ?',
      [itemCode.toUpperCase()]
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

  Future<void> limparContagensSincronizadas() async {
    final db = await instance.database;
    // Exclui apenas as contagens que já foram confirmadas pelo SAP (status 1)
    await db.delete(
      'contagens',
      where: 'syncStatus = ?',
      whereArgs: [1],
    );
  }

  Future close() async {
    final db = await instance.database;
    _database = null; // Limpa a referência para segurança
    await db.close();
  }
}