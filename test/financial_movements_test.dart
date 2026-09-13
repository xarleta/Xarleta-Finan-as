import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/categories/data/category_repository.dart';
import 'package:xarleta_financas/features/installments/data/installment_repository.dart';
import 'package:xarleta_financas/features/installments/domain/installment_model.dart';
import 'package:xarleta_financas/features/transactions/data/transaction_repository.dart';
import 'package:xarleta_financas/features/transactions/domain/transaction_model.dart';
import 'package:xarleta_financas/services/backup_service.dart';

import 'helpers/test_database.dart';

/// Testes dos tipos de movimentação financeira introduzidos no fluxo de
/// "Nova Movimentação":
///
/// - receita única (transação)
/// - despesa única (transação)
/// - despesa recorrente (conta recorrente)
/// - despesa parcelada (parcelamento)
/// - receita recorrente (conta recorrente com `type = income`)
///
/// O banco é preparado pelo helper compartilhado [TestDatabase], que usa um
/// diretório temporário exclusivo por arquivo e limpa o singleton ao final,
/// evitando vazamento de estado entre os isolates paralelos do `flutter test`.
void main() {
  final testDb = TestDatabase('movements');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() => testDb.clearTables(['transactions', 'bills', 'installments']));

  group('Receita única', () {
    test('salva, persiste e entra no resumo como entrada', () async {
      final db = await AppDatabase.instance.database;

      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.income,
          amount: 1500.0,
          description: 'Salário de janeiro',
          category: 'Salário',
          date: DateTime(2026, 1, 5),
          notes: 'Pagamento mensal',
        ),
      );

      expect(id, greaterThan(0));

      final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['type'], 'income');
      expect(rows.single['description'], 'Salário de janeiro');

      final summary = await TransactionRepository.instance.summary();
      expect(summary['income'], 1500.0);
      expect(summary['expense'], 0.0);
    });
  });

  group('Despesa única', () {
    test('salva, persiste e entra no resumo como saída', () async {
      final db = await AppDatabase.instance.database;

      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 250.0,
          description: 'Mercado da semana',
          category: 'Mercado',
          date: DateTime(2026, 1, 6),
        ),
      );

      expect(id, greaterThan(0));

      final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['type'], 'expense');

      final summary = await TransactionRepository.instance.summary();
      expect(summary['income'], 0.0);
      expect(summary['expense'], 250.0);
    });
  });

  group('Despesa recorrente', () {
    test('cria conta recorrente do tipo expense e persiste', () async {
      final id = await BillRepository.instance.create(
        Bill(
          name: 'Aluguel',
          amount: 1200.0,
          dueDate: DateTime(2026, 2, 10),
          category: 'Moradia',
          recurrence: 'monthly',
          type: 'expense',
        ),
      );

      expect(id, greaterThan(0));

      final bills = await BillRepository.instance.list(type: 'expense');
      expect(bills.length, 1);
      expect(bills.single.isIncome, isFalse);
      expect(bills.single.recurrence, 'monthly');
    });

    test('pagamento gera despesa e próxima ocorrência sem duplicar', () async {
      final db = await AppDatabase.instance.database;

      final id = await BillRepository.instance.create(
        Bill(
          name: 'Internet',
          amount: 120.0,
          dueDate: DateTime(2026, 2, 10),
          category: 'Internet',
          recurrence: 'monthly',
          type: 'expense',
        ),
      );

      final bill = (await BillRepository.instance.list()).single;
      expect(bill.id, id);

      final first = await BillRepository.instance.markPaid(bill);
      final second = await BillRepository.instance.markPaid(bill);

      expect(first, isTrue);
      expect(second, isFalse);

      final transactions = await db.query('transactions');
      expect(transactions.length, 1);
      expect(transactions.single['type'], 'expense');

      final bills = await db.query('bills');
      expect(bills.length, 2, reason: 'original paga + próxima ocorrência');
      expect(
        bills.where((b) => b['status'] == 'pending').length,
        1,
      );
    });
  });

  group('Despesa parcelada', () {
    test('cria parcelamento com valor por parcela correto', () async {
      final id = await InstallmentRepository.instance.create(
        Installment(
          name: 'Notebook',
          totalAmount: 2400.0,
          installmentAmount: 200.0,
          totalInstallments: 12,
          firstDueDate: DateTime(2026, 3, 1),
          category: 'Outros',
        ),
      );

      expect(id, greaterThan(0));

      final items = await InstallmentRepository.instance.list();
      expect(items.length, 1);
      expect(items.single.totalInstallments, 12);
      expect(items.single.installmentAmount, 200.0);
      expect(items.single.remaining, 12);
      expect(items.single.remainingAmount, 2400.0);
    });

    test('paga parcelas até finalizar sem duplicar transações', () async {
      final db = await AppDatabase.instance.database;

      await InstallmentRepository.instance.create(
        Installment(
          name: 'Celular',
          totalAmount: 300.0,
          installmentAmount: 100.0,
          totalInstallments: 3,
          firstDueDate: DateTime(2026, 1, 15),
          category: 'Outros',
        ),
      );

      final item = (await InstallmentRepository.instance.list()).single;

      expect(await InstallmentRepository.instance.payNext(item), isTrue);
      expect(await InstallmentRepository.instance.payNext(item), isTrue);
      expect(await InstallmentRepository.instance.payNext(item), isTrue);
      expect(await InstallmentRepository.instance.payNext(item), isFalse);

      final transactions = await db.query('transactions');
      expect(transactions.length, 3);
      expect(transactions.every((t) => t['type'] == 'expense'), isTrue);

      final rows = await db.query('installments', where: 'id = ?', whereArgs: [item.id]);
      expect(rows.single['paid_installments'], 3);
      expect(rows.single['status'], 'finished');
    });
  });

  group('Receita recorrente', () {
    test('cria receita recorrente do tipo income e persiste', () async {
      final id = await BillRepository.instance.create(
        Bill(
          name: 'Aluguel recebido',
          amount: 1800.0,
          dueDate: DateTime(2026, 2, 5),
          category: 'Vendas',
          recurrence: 'monthly',
          type: 'income',
        ),
      );

      expect(id, greaterThan(0));

      final incomes = await BillRepository.instance.list(type: 'income');
      expect(incomes.length, 1);
      expect(incomes.single.isIncome, isTrue);
      expect(incomes.single.recurrence, 'monthly');

      // Não deve aparecer na listagem de despesas.
      final expenses = await BillRepository.instance.list(type: 'expense');
      expect(expenses, isEmpty);
    });

    test('recebimento gera receita e próxima ocorrência sem duplicar', () async {
      final db = await AppDatabase.instance.database;

      await BillRepository.instance.create(
        Bill(
          name: 'Freelance mensal',
          amount: 900.0,
          dueDate: DateTime(2026, 2, 20),
          category: 'Freelance',
          recurrence: 'monthly',
          type: 'income',
        ),
      );

      final bill = (await BillRepository.instance.list(type: 'income')).single;

      final first = await BillRepository.instance.markPaid(bill);
      final second = await BillRepository.instance.markPaid(bill);

      expect(first, isTrue);
      expect(second, isFalse);

      final transactions = await db.query('transactions');
      expect(transactions.length, 1);
      expect(transactions.single['type'], 'income',
          reason: 'receita recorrente deve gerar transação de entrada');

      final summary = await TransactionRepository.instance.summary();
      expect(summary['income'], 900.0);

      final bills = await db.query('bills');
      expect(bills.length, 2);
      final pending = bills.where((b) => b['status'] == 'pending').toList();
      expect(pending.length, 1);
      expect(pending.single['type'], 'income',
          reason: 'a próxima ocorrência deve manter o tipo income');
    });

    test('frequência é preservada na próxima ocorrência', () async {
      final db = await AppDatabase.instance.database;

      await BillRepository.instance.create(
        Bill(
          name: 'Consultoria semanal',
          amount: 300.0,
          dueDate: DateTime(2026, 2, 2),
          category: 'Freelance',
          recurrence: 'weekly',
          type: 'income',
        ),
      );

      final bill = (await BillRepository.instance.list(type: 'income')).single;
      await BillRepository.instance.markPaid(bill);

      final pending = (await db.query('bills', where: "status = 'pending'")).single;
      expect(pending['recurrence'], 'weekly');
      expect(
        DateTime.parse(pending['due_date'] as String),
        DateTime(2026, 2, 9),
        reason: 'recorrência semanal avança 7 dias',
      );
    });

    test('edição altera valor e cancelamento remove a receita recorrente',
        () async {
      await BillRepository.instance.create(
        Bill(
          name: 'Bolsa',
          amount: 500.0,
          dueDate: DateTime(2026, 2, 1),
          category: 'Outros',
          recurrence: 'monthly',
          type: 'income',
        ),
      );

      final bill = (await BillRepository.instance.list(type: 'income')).single;

      await BillRepository.instance.update(
        Bill(
          id: bill.id,
          name: bill.name,
          amount: 650.0,
          dueDate: bill.dueDate,
          category: bill.category,
          recurrence: bill.recurrence,
          type: bill.type,
        ),
      );

      final updated = (await BillRepository.instance.list(type: 'income')).single;
      expect(updated.amount, 650.0);

      await BillRepository.instance.delete(updated.id!);
      expect(await BillRepository.instance.list(type: 'income'), isEmpty);
    });
  });

  group('Categorias por tipo', () {
    test('receita usa apenas categorias de entrada', () async {
      final names = await CategoryRepository.instance.namesByType('income');
      expect(names, isNotEmpty);
      expect(names, contains('Salário'));
      expect(names, isNot(contains('Mercado')));
    });

    test('despesa usa apenas categorias de saída', () async {
      final names = await CategoryRepository.instance.namesByType('expense');
      expect(names, isNotEmpty);
      expect(names, contains('Mercado'));
      expect(names, isNot(contains('Salário')));
    });
  });

  group('Cálculos consolidados', () {
    test('resumo soma receitas e despesas sem duplicar', () async {
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.income,
          amount: 1000.0,
          description: 'Entrada',
          category: 'Salário',
          date: DateTime(2026, 1, 1),
        ),
      );
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 400.0,
          description: 'Saída',
          category: 'Mercado',
          date: DateTime(2026, 1, 2),
        ),
      );

      final summary = await TransactionRepository.instance.summary();
      expect(summary['income'], 1000.0);
      expect(summary['expense'], 400.0);
    });

    test('conta recorrente pendente não entra no resumo antes do pagamento',
        () async {
      await BillRepository.instance.create(
        Bill(
          name: 'Luz',
          amount: 200.0,
          dueDate: DateTime(2026, 2, 15),
          category: 'Moradia',
          recurrence: 'monthly',
          type: 'expense',
        ),
      );

      final summary = await TransactionRepository.instance.summary();
      expect(summary['expense'], 0.0,
          reason: 'conta pendente não é despesa realizada');
    });
  });

  group('Backup e restauração', () {
    test('receita recorrente sobrevive ao exportar e restaurar', () async {
      final db = await AppDatabase.instance.database;

      await BillRepository.instance.create(
        Bill(
          name: 'Aluguel recebido',
          amount: 1800.0,
          dueDate: DateTime(2026, 2, 5),
          category: 'Vendas',
          recurrence: 'monthly',
          type: 'income',
        ),
      );

      final backup = await BackupService.instance.createJson();
      expect(backup, contains('"type": "income"'));

      // Limpa e restaura a partir do backup.
      await db.delete('bills');
      expect(await BillRepository.instance.list(type: 'income'), isEmpty);

      await BackupService.instance.restoreJson(backup);

      final restored = await BillRepository.instance.list(type: 'income');
      expect(restored.length, 1);
      expect(restored.single.isIncome, isTrue);
      expect(restored.single.amount, 1800.0);
    });
  });
}
