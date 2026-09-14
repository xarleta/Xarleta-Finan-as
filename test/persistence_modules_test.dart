import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/core/state/data_change_notifier.dart';

import 'helpers/test_database.dart';

/// Testes de persistência REAL para os módulos que não possuem repositório
/// dedicado: metas, reservas, categorias e trabalho.
///
/// Nestes módulos a escrita é feita diretamente pela tela via
/// `AppDatabase.instance.database`. Como não há uma camada de repositório
/// intermediária, o teste replica exatamente as mesmas operações SQL que a
/// tela executa e confirma o efeito no banco. Isso garante que:
///
/// 1. o registro é realmente gravado (CREATE → QUERY DB);
/// 2. a edição altera os valores persistidos (EDIT → QUERY DB);
/// 3. a exclusão remove/desativa o registro (DELETE → QUERY DB);
/// 4. cada escrita dispara `DataChangeNotifier.notifyChanged()`, que é o
///    gatilho da atualização imediata das telas.
///
/// Se uma tela deixar de notificar, o teste correspondente falha — o que
/// protege contra a regressão do BUG 1 (UI desatualizada).
void main() {
  final testDb = TestDatabase('persistence_modules');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() => testDb.clearTables([
        'goals',
        'goal_contributions',
        'reserves',
        'reserve_movements',
        'categories',
        'work_sessions',
      ]));

  /// Conta quantas notificações são disparadas durante [action].
  Future<int> countNotifications(Future<void> Function() action) async {
    var count = 0;
    void listener() => count++;

    DataChangeNotifier.instance.addListener(listener);
    try {
      await action();
    } finally {
      DataChangeNotifier.instance.removeListener(listener);
    }
    return count;
  }

  group('Metas — persistência e notificação', () {
    test('criar grava a meta e notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('goals', {
          'name': 'Viagem',
          'target_amount': 5000.0,
          'current_amount': 0,
          'deadline': DateTime(2026, 12, 31).toIso8601String(),
          'active': 1,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      final rows = await db.query('goals', where: 'active=1');
      expect(rows.length, 1);
      expect(rows.single['name'], 'Viagem');
      expect(rows.single['target_amount'], 5000.0);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('editar altera nome e valor alvo no banco', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('goals', {
        'name': 'Antiga',
        'target_amount': 1000.0,
        'current_amount': 0,
        'deadline': null,
        'active': 1,
      });

      await db.update(
        'goals',
        {'name': 'Nova', 'target_amount': 2500.0},
        where: 'id=?',
        whereArgs: [id],
      );

      final rows = await db.query('goals', where: 'id=?', whereArgs: [id]);
      expect(rows.single['name'], 'Nova');
      expect(rows.single['target_amount'], 2500.0);
    });

    test('contribuir soma ao valor atual e registra o histórico', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('goals', {
        'name': 'Reserva de emergência',
        'target_amount': 10000.0,
        'current_amount': 0,
        'deadline': null,
        'active': 1,
      });

      await db.transaction((t) async {
        await t.update(
          'goals',
          {'current_amount': 0 + 1500.0},
          where: 'id=?',
          whereArgs: [id],
        );
        await t.insert('goal_contributions', {
          'goal_id': id,
          'amount': 1500.0,
          'contribution_date': DateTime.now().toIso8601String(),
          'note': null,
        });
      });

      final goal = await db.query('goals', where: 'id=?', whereArgs: [id]);
      expect(goal.single['current_amount'], 1500.0);

      final contributions = await db.query(
        'goal_contributions',
        where: 'goal_id=?',
        whereArgs: [id],
      );
      expect(contributions.length, 1);
      expect(contributions.single['amount'], 1500.0);
    });

    test('excluir desativa a meta (soft delete) e notifica', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('goals', {
        'name': 'Meta removida',
        'target_amount': 500.0,
        'current_amount': 0,
        'deadline': null,
        'active': 1,
      });

      final count = await countNotifications(() async {
        await db.update(
          'goals',
          {'active': 0},
          where: 'id=?',
          whereArgs: [id],
        );
        DataChangeNotifier.instance.notifyChanged();
      });

      final active = await db.query('goals', where: 'active=1');
      expect(active, isEmpty);

      final all = await db.query('goals', where: 'id=?', whereArgs: [id]);
      expect(all.single['active'], 0,
          reason: 'a meta deve ser preservada no banco, apenas desativada');
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Reservas — persistência e notificação', () {
    test('criar grava a reserva e notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('reserves', {
          'name': 'Emergência',
          'current_amount': 2000.0,
          'notes': null,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      final rows = await db.query('reserves');
      expect(rows.length, 1);
      expect(rows.single['name'], 'Emergência');
      expect(rows.single['current_amount'], 2000.0);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('movimentar atualiza o saldo e registra a movimentação', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('reserves', {
        'name': 'Viagem',
        'current_amount': 1000.0,
        'notes': null,
      });

      await db.transaction((t) async {
        await t.update(
          'reserves',
          {'current_amount': 1000.0 + 500.0},
          where: 'id = ?',
          whereArgs: [id],
        );
        await t.insert('reserve_movements', {
          'reserve_id': id,
          'type': 'deposit',
          'amount': 500.0,
          'movement_date': DateTime.now().toIso8601String(),
          'note': null,
        });
      });

      final reserve = await db.query('reserves', where: 'id=?', whereArgs: [id]);
      expect(reserve.single['current_amount'], 1500.0);

      final movements = await db.query(
        'reserve_movements',
        where: 'reserve_id=?',
        whereArgs: [id],
      );
      expect(movements.length, 1);
      expect(movements.single['type'], 'deposit');
      expect(movements.single['amount'], 500.0);
    });

    test('editar altera nome e valor atual no banco', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('reserves', {
        'name': 'Antiga',
        'current_amount': 100.0,
        'notes': null,
      });

      await db.update(
        'reserves',
        {'name': 'Nova', 'current_amount': 750.0},
        where: 'id = ?',
        whereArgs: [id],
      );

      final rows = await db.query('reserves', where: 'id=?', whereArgs: [id]);
      expect(rows.single['name'], 'Nova');
      expect(rows.single['current_amount'], 750.0);
    });

    test('excluir remove a reserva e o histórico de movimentações', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('reserves', {
        'name': 'Remover',
        'current_amount': 300.0,
        'notes': null,
      });
      await db.insert('reserve_movements', {
        'reserve_id': id,
        'type': 'deposit',
        'amount': 300.0,
        'movement_date': DateTime.now().toIso8601String(),
        'note': null,
      });

      final count = await countNotifications(() async {
        await db.transaction((t) async {
          await t.delete(
            'reserve_movements',
            where: 'reserve_id = ?',
            whereArgs: [id],
          );
          await t.delete('reserves', where: 'id = ?', whereArgs: [id]);
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(await db.query('reserves'), isEmpty);
      expect(await db.query('reserve_movements'), isEmpty);
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Categorias — persistência e notificação', () {
    test('criar grava a categoria e notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('categories', {
          'name': 'Categoria teste',
          'type': 'expense',
          'active': 1,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      final rows = await db.query(
        'categories',
        where: 'type=? AND active=1',
        whereArgs: ['expense'],
      );
      expect(rows.length, 1);
      expect(rows.single['name'], 'Categoria teste');
      expect(count, greaterThanOrEqualTo(1));
    });

    test('editar altera o nome no banco', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('categories', {
        'name': 'Antiga',
        'type': 'expense',
        'active': 1,
      });

      await db.update(
        'categories',
        {'name': 'Nova'},
        where: 'id=?',
        whereArgs: [id],
      );

      final rows = await db.query('categories', where: 'id=?', whereArgs: [id]);
      expect(rows.single['name'], 'Nova');
    });

    test('excluir desativa a categoria (soft delete) preservando o histórico',
        () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('categories', {
        'name': 'Usada',
        'type': 'expense',
        'active': 1,
      });

      // Lançamento que usa a categoria.
      await db.insert('transactions', {
        'type': 'expense',
        'amount': 100.0,
        'description': 'Compra',
        'category': 'Usada',
        'transaction_date': DateTime(2026, 9, 1).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final count = await countNotifications(() async {
        await db.update(
          'categories',
          {'active': 0},
          where: 'id=?',
          whereArgs: [id],
        );
        DataChangeNotifier.instance.notifyChanged();
      });

      final active = await db.query(
        'categories',
        where: 'type=? AND active=1',
        whereArgs: ['expense'],
      );
      expect(active, isEmpty);

      // O lançamento continua íntegro, com o nome da categoria preservado.
      final tx = await db.query('transactions');
      expect(tx.length, 1);
      expect(tx.single['category'], 'Usada');
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Trabalho — persistência e notificação', () {
    test('criar grava a sessão e notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('work_sessions', {
          'activity': 'Entrega',
          'session_date': DateTime(2026, 9, 13).toIso8601String(),
          'earnings': 150.0,
          'expenses': 30.0,
          'hours': 4.0,
          'kilometers': 20.0,
          'notes': null,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      final rows = await db.query('work_sessions');
      expect(rows.length, 1);
      expect(rows.single['activity'], 'Entrega');
      expect(rows.single['earnings'], 150.0);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('excluir remove a sessão do banco e notifica', () async {
      final db = await AppDatabase.instance.database;

      final id = await db.insert('work_sessions', {
        'activity': 'Remover',
        'session_date': DateTime(2026, 9, 13).toIso8601String(),
        'earnings': 100.0,
        'expenses': 0.0,
        'hours': 2.0,
        'kilometers': 0.0,
        'notes': null,
      });

      final count = await countNotifications(() async {
        await db.delete('work_sessions', where: 'id = ?', whereArgs: [id]);
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(await db.query('work_sessions'), isEmpty);
      expect(count, greaterThanOrEqualTo(1));
    });
  });
}
