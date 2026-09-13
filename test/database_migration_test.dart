import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';

import 'helpers/test_database.dart';

void main() {
  final testDb = TestDatabase('migration');

  // Não abre a base no setUpAll: este teste precisa criar um banco legado
  // (versão 2) antes que o `AppDatabase` abra o arquivo, para validar a
  // migração até a versão 9.
  setUpAll(() => testDb.setUpAll(openDatabase: false));
  tearDownAll(testDb.tearDownAll);

  test('migra uma base legada para a versao 9 sem apagar transacoes', () async {
    // O helper já inicializou a fábrica FFI e definiu um diretório temporário
    // exclusivo para este arquivo. Cria-se aqui uma base legada (versão 2)
    // no mesmo caminho para validar a migração até a versão 9.
    final databasePath = testDb.databasePath;

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
    expect(await upgraded.getVersion(), 9);
    expect(
      (await upgraded.query('transactions')).single['description'],
      'Registro legado',
    );

    // A migração v9 adiciona a coluna `type` em `bills` para representar
    // receita recorrente reutilizando a arquitetura de recorrência existente.
    final billColumns = await upgraded.rawQuery('PRAGMA table_info(bills)');
    expect(
      billColumns.map((c) => c['name']),
      contains('type'),
      reason: 'a coluna type deve existir após a migração v9',
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

    // Fecha o handle e limpa o singleton; a remoção do arquivo temporário é
    // responsabilidade do `tearDownAll` do helper.
    await AppDatabase.instance.closeForTesting();
  });
}
