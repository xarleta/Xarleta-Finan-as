import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';

void main() {
  test('migra uma base legada para a versao 8 sem apagar transacoes', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final databasePath = join(
      await getDatabasesPath(),
      'xarleta_financas.db',
    );
    await deleteDatabase(databasePath);
    await Directory(dirname(databasePath)).create(recursive: true);

    final legacy = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE transactions ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'type TEXT NOT NULL, amount REAL NOT NULL, '
          'description TEXT NOT NULL, category TEXT NOT NULL, '
          'transaction_date TEXT NOT NULL, notes TEXT, '
          'created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
      },
    );
    await legacy.insert('transactions', {
      'type': 'income',
      'amount': 100.0,
      'description': 'Registro legado',
      'category': 'Salario',
      'transaction_date': '2026-01-01T00:00:00.000',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    await legacy.close();

    final upgraded = await AppDatabase.instance.database;
    expect(await upgraded.getVersion(), 8);
    expect(
      (await upgraded.query('transactions')).single['description'],
      'Registro legado',
    );

    for (final table in [
      'bills',
      'installments',
      'work_sessions',
      'goals',
      'reserves',
      'categories',
      'goal_contributions',
      'reserve_movements',
      'app_settings',
    ]) {
      await upgraded.query(table);
    }

    await upgraded.close();
    await deleteDatabase(databasePath);
  });
}
