import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/categories/data/category_repository.dart';

/// Testes do repositório de categorias: garantem que os formulários usam as
/// categorias cadastradas no banco (não listas fixas), respeitando o tipo
/// (`income`/`expense`) e apenas as ativas.
///
/// Cada arquivo de teste usa um diretório próprio para evitar contenção entre
/// os isolates executados em paralelo pelo `flutter test`.
void main() {
  late String databasePath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = join(
      Directory.systemTemp.path,
      'xarleta_test_categories',
    );
    await databaseFactory.setDatabasesPath(dir);
    databasePath = join(dir, 'xarleta_financas.db');
    await deleteDatabase(databasePath);
    await Directory(dir).create(recursive: true);

    await AppDatabase.instance.database;
  });

  tearDownAll(() async {
    final db = await AppDatabase.instance.database;
    await db.close();
    await deleteDatabase(databasePath);
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('categories');
  });

  test('retorna apenas categorias ativas do tipo informado', () async {
    final db = await AppDatabase.instance.database;
    await db.insert('categories', {
      'name': 'Salário',
      'type': 'income',
      'active': 1,
    });
    await db.insert('categories', {
      'name': 'Antiga',
      'type': 'income',
      'active': 0,
    });
    await db.insert('categories', {
      'name': 'Mercado',
      'type': 'expense',
      'active': 1,
    });

    final income = await CategoryRepository.instance.namesByType('income');
    final expense = await CategoryRepository.instance.namesByType('expense');

    expect(income, ['Salário']);
    expect(expense, ['Mercado']);
  });

  test('ordena as categorias alfabeticamente', () async {
    final db = await AppDatabase.instance.database;
    for (final name in ['Zebra', 'Alimentação', 'Mercado']) {
      await db.insert('categories', {
        'name': name,
        'type': 'expense',
        'active': 1,
      });
    }

    final names = await CategoryRepository.instance.namesByType('expense');

    expect(names, ['Alimentação', 'Mercado', 'Zebra']);
  });

  test('ignora nomes vazios', () async {
    final db = await AppDatabase.instance.database;
    await db.insert('categories', {
      'name': '   ',
      'type': 'expense',
      'active': 1,
    });
    await db.insert('categories', {
      'name': 'Lazer',
      'type': 'expense',
      'active': 1,
    });

    final names = await CategoryRepository.instance.namesByType('expense');

    expect(names, ['Lazer']);
  });

  test('retorna lista vazia quando não há categorias do tipo', () async {
    final names = await CategoryRepository.instance.namesByType('income');

    expect(names, isEmpty);
  });
}
