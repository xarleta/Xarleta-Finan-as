import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'xarleta_financas.db');
    _database = await openDatabase(
      path,
      version: 9,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  /// Fecha o handle aberto e limpa o singleton.
  ///
  /// Existe exclusivamente para uso em testes: como [instance] é um singleton
  /// de processo, sem este método o handle permaneceria aberto entre arquivos
  /// de teste executados no mesmo isolate, vazando estado e impedindo a
  /// remoção do arquivo temporário. Não deve ser chamado em produção.
  Future<void> closeForTesting() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('CREATE TABLE IF NOT EXISTS installments (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,total_amount REAL NOT NULL,installment_amount REAL NOT NULL,total_installments INTEGER NOT NULL,paid_installments INTEGER NOT NULL DEFAULT 0,first_due_date TEXT NOT NULL,category TEXT NOT NULL,status TEXT NOT NULL DEFAULT "active",reminder_days INTEGER NOT NULL DEFAULT 1,notes TEXT)');
    }
    if (oldVersion < 5) {
      await db.execute('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,type TEXT NOT NULL,icon TEXT,active INTEGER NOT NULL DEFAULT 1)');
      await db.execute('CREATE TABLE IF NOT EXISTS goal_contributions (id INTEGER PRIMARY KEY AUTOINCREMENT,goal_id INTEGER NOT NULL,amount REAL NOT NULL,contribution_date TEXT NOT NULL,note TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS reserve_movements (id INTEGER PRIMARY KEY AUTOINCREMENT,reserve_id INTEGER NOT NULL,type TEXT NOT NULL,amount REAL NOT NULL,movement_date TEXT NOT NULL,note TEXT)');
      await _seedCategories(db);
    }
    if (oldVersion < 7) {
      await db.execute('CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type, transaction_date)');
    }
    // Versão 8 garante que bancos criados por versões intermediárias
    // contenham todas as tabelas usadas pelas telas atuais.
    if (oldVersion < 8) {
      await db.execute('CREATE TABLE IF NOT EXISTS bills (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,amount REAL NOT NULL CHECK(amount > 0),due_date TEXT NOT NULL,category TEXT NOT NULL,recurrence TEXT NOT NULL DEFAULT "once",reminder_days INTEGER NOT NULL DEFAULT 1,status TEXT NOT NULL DEFAULT "pending",notes TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS work_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT,activity TEXT NOT NULL,session_date TEXT NOT NULL,earnings REAL NOT NULL DEFAULT 0,expenses REAL NOT NULL DEFAULT 0,hours REAL NOT NULL DEFAULT 0,kilometers REAL NOT NULL DEFAULT 0,notes TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS goals (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,target_amount REAL NOT NULL CHECK(target_amount > 0),current_amount REAL NOT NULL DEFAULT 0,deadline TEXT,active INTEGER NOT NULL DEFAULT 1)');
      await db.execute('CREATE TABLE IF NOT EXISTS reserves (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,current_amount REAL NOT NULL DEFAULT 0,notes TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS goal_contributions (id INTEGER PRIMARY KEY AUTOINCREMENT,goal_id INTEGER NOT NULL,amount REAL NOT NULL,contribution_date TEXT NOT NULL,note TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS reserve_movements (id INTEGER PRIMARY KEY AUTOINCREMENT,reserve_id INTEGER NOT NULL,type TEXT NOT NULL,amount REAL NOT NULL,movement_date TEXT NOT NULL,note TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,type TEXT NOT NULL,icon TEXT,active INTEGER NOT NULL DEFAULT 1)');
      await _seedCategories(db);
    }
    // Versão 9 adiciona o tipo (receita/despesa) às contas recorrentes,
    // permitindo representar receita recorrente reutilizando a mesma
    // arquitetura de recorrência já existente. Registros antigos recebem
    // 'expense' como padrão, preservando o comportamento anterior.
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE bills ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount REAL NOT NULL CHECK(amount > 0),description TEXT NOT NULL,category TEXT NOT NULL,transaction_date TEXT NOT NULL,notes TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,amount REAL NOT NULL CHECK(amount > 0),due_date TEXT NOT NULL,category TEXT NOT NULL,recurrence TEXT NOT NULL DEFAULT "once",reminder_days INTEGER NOT NULL DEFAULT 1,status TEXT NOT NULL DEFAULT "pending",notes TEXT,type TEXT NOT NULL DEFAULT "expense")');
    await db.execute('CREATE TABLE installments (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,total_amount REAL NOT NULL,installment_amount REAL NOT NULL,total_installments INTEGER NOT NULL,paid_installments INTEGER NOT NULL DEFAULT 0,first_due_date TEXT NOT NULL,category TEXT NOT NULL,status TEXT NOT NULL DEFAULT "active",reminder_days INTEGER NOT NULL DEFAULT 1,notes TEXT)');
    await db.execute('CREATE TABLE work_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT,activity TEXT NOT NULL,session_date TEXT NOT NULL,earnings REAL NOT NULL DEFAULT 0,expenses REAL NOT NULL DEFAULT 0,hours REAL NOT NULL DEFAULT 0,kilometers REAL NOT NULL DEFAULT 0,notes TEXT)');
    await db.execute('CREATE TABLE goals (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,target_amount REAL NOT NULL CHECK(target_amount > 0),current_amount REAL NOT NULL DEFAULT 0,deadline TEXT,active INTEGER NOT NULL DEFAULT 1)');
    await db.execute('CREATE TABLE reserves (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,current_amount REAL NOT NULL DEFAULT 0,notes TEXT)');
    await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,type TEXT NOT NULL,icon TEXT,active INTEGER NOT NULL DEFAULT 1)');
    await db.execute('CREATE TABLE goal_contributions (id INTEGER PRIMARY KEY AUTOINCREMENT,goal_id INTEGER NOT NULL,amount REAL NOT NULL,contribution_date TEXT NOT NULL,note TEXT)');
    await db.execute('CREATE TABLE reserve_movements (id INTEGER PRIMARY KEY AUTOINCREMENT,reserve_id INTEGER NOT NULL,type TEXT NOT NULL,amount REAL NOT NULL,movement_date TEXT NOT NULL,note TEXT)');
    await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE INDEX idx_bills_due_date ON bills(due_date)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_type_date ON transactions(type, transaction_date)');
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    const defaults = [
      ['Salário','income'],['Uber','income'],['99','income'],['Entregas','income'],['Motoboy','income'],['Música','income'],['Vendas','income'],['Freelance','income'],
      ['Alimentação','expense'],['Mercado','expense'],['Combustível','expense'],['Moradia','expense'],['Internet','expense'],['Telefone','expense'],['Academia','expense'],['Assinaturas','expense'],['Trabalho','expense'],['Lazer','expense'],['Outros','expense']
    ];
    for (final item in defaults) {
      await db.insert('categories', {'name': item[0], 'type': item[1], 'active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

