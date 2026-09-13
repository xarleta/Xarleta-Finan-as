import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/dashboard/data/dashboard_preferences_repository.dart';

/// Testes da personalização do dashboard.
///
/// Garantem que a configuração (ordem e visibilidade dos cards) é persistida
/// na tabela `app_settings`, sobrevive a uma nova leitura (simulando fechar e
/// reabrir o app) e que a restauração do padrão funciona.
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
      'xarleta_test_dashboard_prefs',
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
    await db.delete('app_settings');
  });

  test('sem configuração salva retorna o padrão com todos visíveis', () async {
    final prefs = await DashboardPreferencesRepository.instance.load();

    expect(prefs.order, DashboardWidget.values);
    expect(prefs.hidden, isEmpty);
    expect(prefs.visibleOrder, DashboardWidget.values);
  });

  test('persiste a ordem e a visibilidade e recarrega corretamente', () async {
    final custom = DashboardPreferences(
      order: const [
        DashboardWidget.tip,
        DashboardWidget.balance,
        DashboardWidget.expense,
        DashboardWidget.income,
      ],
      hidden: const {DashboardWidget.income},
    );

    await DashboardPreferencesRepository.instance.save(custom);

    // Nova leitura simula reabrir o aplicativo.
    final loaded = await DashboardPreferencesRepository.instance.load();

    expect(loaded.order, [
      DashboardWidget.tip,
      DashboardWidget.balance,
      DashboardWidget.expense,
      DashboardWidget.income,
    ]);
    expect(loaded.hidden, {DashboardWidget.income});
    expect(loaded.isVisible(DashboardWidget.income), isFalse);
    expect(loaded.visibleOrder, [
      DashboardWidget.tip,
      DashboardWidget.balance,
      DashboardWidget.expense,
    ]);
  });

  test('salvar duas vezes atualiza a mesma chave (idempotente)', () async {
    await DashboardPreferencesRepository.instance.save(
      DashboardPreferences.defaults.copyWith(
        hidden: const {DashboardWidget.tip},
      ),
    );
    await DashboardPreferencesRepository.instance.save(
      DashboardPreferences.defaults.copyWith(
        hidden: const {DashboardWidget.balance},
      ),
    );

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['dashboard_preferences'],
    );

    expect(rows.length, 1);

    final loaded = await DashboardPreferencesRepository.instance.load();
    expect(loaded.hidden, {DashboardWidget.balance});
  });

  test('reset remove a configuração e volta ao padrão', () async {
    await DashboardPreferencesRepository.instance.save(
      DashboardPreferences.defaults.copyWith(
        hidden: const {DashboardWidget.tip, DashboardWidget.expense},
      ),
    );

    await DashboardPreferencesRepository.instance.reset();

    final loaded = await DashboardPreferencesRepository.instance.load();
    expect(loaded.order, DashboardWidget.values);
    expect(loaded.hidden, isEmpty);
  });

  test('ignora ids desconhecidos e completa widgets ausentes', () async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {
        'key': 'dashboard_preferences',
        'value': '{"order":["tip","inexistente"],"hidden":["nao_existe"]}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final loaded = await DashboardPreferencesRepository.instance.load();

    // Widgets ausentes são acrescentados; desconhecidos são ignorados.
    expect(loaded.order.length, DashboardWidget.values.length);
    expect(loaded.order.first, DashboardWidget.tip);
    expect(loaded.order.toSet(), DashboardWidget.values.toSet());
    expect(loaded.hidden, isEmpty);
  });

  test('valor inválido no banco não lança e retorna o padrão', () async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {'key': 'dashboard_preferences', 'value': 'isto-nao-e-json'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final loaded = await DashboardPreferencesRepository.instance.load();

    expect(loaded.order, DashboardWidget.values);
    expect(loaded.hidden, isEmpty);
  });
}
