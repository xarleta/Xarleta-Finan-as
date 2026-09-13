import '../../../core/database/app_database.dart';
import '../domain/transaction_model.dart';

class TransactionRepository {
  TransactionRepository._();
  static final instance = TransactionRepository._();

  Future<int> create(FinanceTransaction item) async {
    final db = await AppDatabase.instance.database;
    return db.insert('transactions', item.toMap());
  }

  Future<List<FinanceTransaction>> list({
    String? query,
    TransactionType? type,
  }) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      where.add('(description LIKE ? OR category LIKE ?)');
      args.add('%${query.trim()}%');
      args.add('%${query.trim()}%');
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }

    final rows = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'transaction_date DESC, id DESC',
    );
    return rows.map(FinanceTransaction.fromMap).toList();
  }

  Future<void> update(FinanceTransaction item) async {
    if (item.id == null) return;
    final db = await AppDatabase.instance.database;
    final map = item.toMap()..remove('created_at');
    await db.update('transactions', map, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> summary() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) expense
      FROM transactions
    ''');
    final row = rows.first;
    return {
      'income': (row['income'] as num).toDouble(),
      'expense': (row['expense'] as num).toDouble(),
    };
  }
}

