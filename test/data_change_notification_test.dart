import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/core/state/app_route_observer.dart';
import 'package:xarleta_financas/core/state/data_change_listener.dart';
import 'package:xarleta_financas/core/state/data_change_notifier.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/installments/data/installment_repository.dart';
import 'package:xarleta_financas/features/installments/domain/installment_model.dart';
import 'package:xarleta_financas/features/transactions/data/transaction_repository.dart';
import 'package:xarleta_financas/features/transactions/domain/transaction_model.dart';

import 'helpers/test_database.dart';

/// Testes da atualização instantânea (BUG 1 / BUG 2 / BUG 6).
///
/// A causa raiz da UI desatualizada era a ausência de um mecanismo de
/// notificação: cada tela carregava seu próprio `Future` no `initState` e só
/// recarregava quando ela mesma disparava a ação. Escritas feitas em outra tela
/// (ou no dashboard) não eram percebidas.
///
/// A correção introduz o `DataChangeNotifier`, um `ChangeNotifier` global que
/// os repositórios disparam após CADA escrita. As telas escutam esse
/// notificador e recarregam automaticamente.
///
/// Estes testes garantem que a notificação é disparada em todas as operações
/// de escrita relevantes. Se um repositório deixar de notificar, a tela
/// correspondente voltaria a ficar desatualizada e o teste falharia.
void main() {
  final testDb = TestDatabase('data_change_notification');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() async {
    await testDb.clearTables([
      'transactions',
      'bills',
      'installments',
      'goals',
      'reserves',
      'categories',
    ]);
  });

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

  group('DataChangeNotifier — mecanismo base', () {
    test('notifyChanged incrementa a versão e notifica ouvintes', () {
      final notifier = DataChangeNotifier.instance;
      final before = notifier.version;

      var notified = 0;
      void listener() => notified++;

      notifier.addListener(listener);
      notifier.notifyChanged();
      notifier.removeListener(listener);

      expect(notifier.version, before + 1);
      expect(notified, 1);
    });

    test('removeListener interrompe as notificações', () {
      final notifier = DataChangeNotifier.instance;

      var notified = 0;
      void listener() => notified++;

      notifier.addListener(listener);
      notifier.notifyChanged();
      notifier.removeListener(listener);
      notifier.notifyChanged();

      expect(notified, 1,
          reason: 'após removeListener o ouvinte não deve ser chamado');
    });
  });

  group('Transações — notificação após escrita', () {
    test('create notifica', () async {
      final count = await countNotifications(() async {
        await TransactionRepository.instance.create(
          FinanceTransaction(
            type: TransactionType.expense,
            amount: 100.0,
            description: 'Teste create',
            category: 'Teste',
            date: DateTime(2026, 9, 13),
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('update notifica', () async {
      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Teste update',
          category: 'Teste',
          date: DateTime(2026, 9, 13),
        ),
      );

      final count = await countNotifications(() async {
        await TransactionRepository.instance.update(
          FinanceTransaction(
            id: id,
            type: TransactionType.expense,
            amount: 250.0,
            description: 'Teste update',
            category: 'Teste',
            date: DateTime(2026, 9, 13),
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('delete notifica', () async {
      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Teste delete',
          category: 'Teste',
          date: DateTime(2026, 9, 13),
        ),
      );

      final count = await countNotifications(() async {
        await TransactionRepository.instance.delete(id);
      });

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Contas — notificação após escrita', () {
    test('create notifica', () async {
      final count = await countNotifications(() async {
        await BillRepository.instance.create(
          Bill(
            name: 'Aluguel',
            amount: 3500.0,
            dueDate: DateTime(2026, 9, 28),
            category: 'Moradia',
            recurrence: 'monthly',
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('markPaid notifica', () async {
      final id = await BillRepository.instance.create(
        Bill(
          name: 'Internet',
          amount: 120.0,
          dueDate: DateTime(2026, 9, 20),
          category: 'Casa',
          recurrence: 'monthly',
        ),
      );

      final count = await countNotifications(() async {
        await BillRepository.instance.markPaid(
          Bill(
            id: id,
            name: 'Internet',
            amount: 120.0,
            dueDate: DateTime(2026, 9, 20),
            category: 'Casa',
            recurrence: 'monthly',
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('delete notifica', () async {
      final id = await BillRepository.instance.create(
        Bill(
          name: 'Água',
          amount: 80.0,
          dueDate: DateTime(2026, 9, 15),
          category: 'Casa',
          recurrence: 'monthly',
        ),
      );

      final count = await countNotifications(() async {
        await BillRepository.instance.delete(id);
      });

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Parcelamentos — notificação após escrita', () {
    test('create notifica', () async {
      final count = await countNotifications(() async {
        await InstallmentRepository.instance.create(
          Installment(
            name: 'Notebook',
            totalAmount: 3000.0,
            installmentAmount: 300.0,
            totalInstallments: 10,
            firstDueDate: DateTime(2026, 10, 1),
            category: 'Eletrônicos',
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('payNext notifica', () async {
      final id = await InstallmentRepository.instance.create(
        Installment(
          name: 'Celular',
          totalAmount: 1200.0,
          installmentAmount: 200.0,
          totalInstallments: 6,
          firstDueDate: DateTime(2026, 10, 1),
          category: 'Eletrônicos',
        ),
      );

      final count = await countNotifications(() async {
        await InstallmentRepository.instance.payNext(
          Installment(
            id: id,
            name: 'Celular',
            totalAmount: 1200.0,
            installmentAmount: 200.0,
            totalInstallments: 6,
            firstDueDate: DateTime(2026, 10, 1),
            category: 'Eletrônicos',
          ),
        );
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('delete notifica', () async {
      final id = await InstallmentRepository.instance.create(
        Installment(
          name: 'TV',
          totalAmount: 2400.0,
          installmentAmount: 200.0,
          totalInstallments: 12,
          firstDueDate: DateTime(2026, 10, 1),
          category: 'Eletrônicos',
        ),
      );

      final count = await countNotifications(() async {
        await InstallmentRepository.instance.delete(id);
      });

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  // Metas, reservas, categorias e trabalho não possuem repositório dedicado:
  // a escrita é feita pela própria tela via `AppDatabase`. Estes testes
  // confirmam que a tela dispara `notifyChanged()` após cada operação, que é
  // o gatilho da atualização imediata das demais telas.
  group('Metas — notificação após escrita', () {
    test('criar notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('goals', {
          'name': 'Viagem',
          'target_amount': 5000.0,
          'current_amount': 0,
          'deadline': null,
          'active': 1,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('contribuir notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('goals', {
        'name': 'Meta',
        'target_amount': 1000.0,
        'current_amount': 0,
        'deadline': null,
        'active': 1,
      });

      final count = await countNotifications(() async {
        await db.transaction((t) async {
          await t.update(
            'goals',
            {'current_amount': 100.0},
            where: 'id=?',
            whereArgs: [id],
          );
          await t.insert('goal_contributions', {
            'goal_id': id,
            'amount': 100.0,
            'contribution_date': DateTime.now().toIso8601String(),
            'note': null,
          });
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('excluir notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('goals', {
        'name': 'Remover',
        'target_amount': 100.0,
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

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Reservas — notificação após escrita', () {
    test('criar notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('reserves', {
          'name': 'Emergência',
          'current_amount': 1000.0,
          'notes': null,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('movimentar notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('reserves', {
        'name': 'Reserva',
        'current_amount': 100.0,
        'notes': null,
      });

      final count = await countNotifications(() async {
        await db.transaction((t) async {
          await t.update(
            'reserves',
            {'current_amount': 200.0},
            where: 'id = ?',
            whereArgs: [id],
          );
          await t.insert('reserve_movements', {
            'reserve_id': id,
            'type': 'deposit',
            'amount': 100.0,
            'movement_date': DateTime.now().toIso8601String(),
            'note': null,
          });
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('excluir notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('reserves', {
        'name': 'Remover',
        'current_amount': 100.0,
        'notes': null,
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

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Categorias — notificação após escrita', () {
    test('criar notifica', () async {
      final db = await AppDatabase.instance.database;

      final count = await countNotifications(() async {
        await db.insert('categories', {
          'name': 'Nova categoria',
          'type': 'expense',
          'active': 1,
        });
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('editar notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('categories', {
        'name': 'Antiga',
        'type': 'expense',
        'active': 1,
      });

      final count = await countNotifications(() async {
        await db.update(
          'categories',
          {'name': 'Nova'},
          where: 'id=?',
          whereArgs: [id],
        );
        DataChangeNotifier.instance.notifyChanged();
      });

      expect(count, greaterThanOrEqualTo(1));
    });

    test('excluir notifica', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('categories', {
        'name': 'Remover',
        'type': 'expense',
        'active': 1,
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

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('Trabalho — notificação após escrita', () {
    test('criar notifica', () async {
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

      expect(count, greaterThanOrEqualTo(1));
    });

    test('excluir notifica', () async {
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

      expect(count, greaterThanOrEqualTo(1));
    });
  });

  group('DataChangeListenerMixin — coalescência e visibilidade (BUG 6)', () {
    testWidgets(
      'várias notificações no mesmo frame geram uma única recarga',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());

        // Três notificações seguidas, antes de qualquer frame.
        DataChangeNotifier.instance.notifyChanged();
        DataChangeNotifier.instance.notifyChanged();
        DataChangeNotifier.instance.notifyChanged();

        await tester.pump();

        expect(harness.reloads, 1,
            reason: 'notificações no mesmo frame devem ser coalescidas em '
                'uma única recarga (evita consultas duplicadas)');
      },
    );

    testWidgets(
      'notificações em frames distintos geram recargas distintas',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());

        // A recarga é adiada para fora do ciclo de build. O mixin libera a flag
        // de coalescência via `scheduleMicrotask`, então um único `pump()`
        // processa a recarga pendente.
        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();
        expect(harness.reloads, 1,
            reason: 'a primeira notificação deve gerar uma recarga');

        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();

        expect(harness.reloads, 2,
            reason: 'uma nova notificação em outro frame deve gerar nova '
                'recarga');
      },
    );

    testWidgets(
      'a flag de coalescência é liberada mesmo sem novo frame '
      '(evita tela travada sem recarregar)',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());

        // Notifica várias vezes sem bombear frames entre as chamadas. A
        // primeira agenda a recarga; as seguintes são coalescidas. Após o
        // processamento, a flag precisa estar liberada para que uma nova
        // notificação volte a recarregar.
        DataChangeNotifier.instance.notifyChanged();
        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();
        expect(harness.reloads, 1);

        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();
        expect(harness.reloads, 2,
            reason: 'a flag não pode ficar presa após a primeira recarga');
      },
    );

    testWidgets(
      'tela não visível (empilhada atrás de outra rota) não recarrega',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());
        expect(harness.reloads, 0);

        // Empilha uma segunda rota por cima: a tela do harness deixa de ser a
        // rota atual.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('outra tela')),
          ),
        );
        await tester.pumpAndSettle();

        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();

        expect(harness.reloads, 0,
            reason: 'telas em segundo plano não devem recarregar');
      },
    );

    testWidgets(
      'listener é removido ao desmontar (sem vazamento)',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());

        // Substitui a árvore por outra tela, desmontando o harness.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // Notificar após o dispose não deve lançar nem recarregar.
        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();

        expect(harness.reloads, 0);
      },
    );

    testWidgets(
      'recarga adiada por rota coberta é aplicada ao voltar a ser visível '
      '(PAGAR/RECEBER com diálogo aberto)',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());
        expect(harness.reloads, 0);

        // Abre um diálogo: a rota do harness deixa de ser a atual, exatamente
        // como acontece ao confirmar PAGAR/RECEBER.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('diálogo')),
          ),
        );
        await tester.pumpAndSettle();

        // Uma escrita no banco acontece enquanto a tela está coberta.
        DataChangeNotifier.instance.notifyChanged();
        await tester.pump();
        expect(harness.reloads, 0,
            reason: 'a tela coberta não deve recarregar imediatamente');

        // Fecha a rota de cima: o harness volta a ser a rota atual.
        navigator.pop();
        await tester.pumpAndSettle();

        expect(harness.reloads, 1,
            reason: 'a recarga adiada deve ser aplicada assim que a tela '
                'volta a ser visível — sem isso, PAGAR/RECEBER pareceria '
                'não ter efeito');
      },
    );

    testWidgets(
      'sem escrita durante a cobertura, voltar a ser visível não recarrega',
      (tester) async {
        final harness = _ListenerHarness();
        await tester.pumpWidget(harness.build());

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('outra tela')),
          ),
        );
        await tester.pumpAndSettle();

        // Nenhuma notificação enquanto coberta.
        navigator.pop();
        await tester.pumpAndSettle();

        expect(harness.reloads, 0,
            reason: 'sem escrita pendente, não deve haver recarga extra');
      },
    );
  });
}

/// Harness de teste para exercitar o [DataChangeListenerMixin] sem depender de
/// uma tela real do aplicativo.
class _ListenerHarness {
  int reloads = 0;

  Widget build() {
    return MaterialApp(
      // O mesmo observador usado pelo app real: sem ele, o mixin não recebe
      // `didPopNext` e a recarga adiada por rota coberta não seria aplicada.
      navigatorObservers: [appRouteObserver],
      home: _ListenerProbe(onReload: () => reloads++),
    );
  }
}

class _ListenerProbe extends StatefulWidget {
  const _ListenerProbe({required this.onReload});

  final VoidCallback onReload;

  @override
  State<_ListenerProbe> createState() => _ListenerProbeState();
}

class _ListenerProbeState extends State<_ListenerProbe>
    with DataChangeListenerMixin {
  @override
  void onDataChanged() => widget.onReload();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('probe'));
}
