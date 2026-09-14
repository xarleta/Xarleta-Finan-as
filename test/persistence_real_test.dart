import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/installments/data/installment_repository.dart';
import 'package:xarleta_financas/features/installments/domain/installment_model.dart';
import 'package:xarleta_financas/features/transactions/data/transaction_repository.dart';
import 'package:xarleta_financas/features/transactions/domain/transaction_model.dart';

import 'helpers/test_database.dart';

/// Testes de persistência REAL no banco de dados.
///
/// Diferente de testes de widget (que apenas simulam toques), estes testes
/// verificam o efeito no SQLite: criam o registro, executam a operação e
/// consultam a tabela novamente para confirmar que a mudança foi persistida.
///
/// Cobrem os bugs relatados no uso real do app:
///
/// - BUG 1: exclusão de lançamento deve remover a linha de `transactions`;
/// - BUG 2: despesa/receita avulsa futura deve aparecer em "Contas e
///   vencimentos" (listagem unificada), sem duplicar registros;
/// - BUG 3: edição deve alterar os valores persistidos.
void main() {
  final testDb = TestDatabase('persistence_real');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() => testDb.clearTables(['transactions', 'bills', 'installments']));

  group('BUG 1 — exclusão de lançamento persiste no banco', () {
    test('delete remove a linha de transactions', () async {
      final db = await AppDatabase.instance.database;

      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      // Confirma que existe antes de excluir.
      final before = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(before.length, 1);

      await TransactionRepository.instance.delete(id);

      // Confirma que a linha foi realmente removida do banco.
      final after = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(after, isEmpty,
          reason: 'a exclusão deve remover a linha de transactions');

      // Confirma que não aparece mais na listagem ativa.
      final list = await TransactionRepository.instance.list();
      expect(list.where((t) => t.id == id), isEmpty);
    });

    test('delete não afeta outros lançamentos', () async {
      final db = await AppDatabase.instance.database;

      final keepId = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.income,
          amount: 2900.0,
          description: 'Freelance',
          category: 'Freelance',
          date: DateTime(2026, 9, 26),
        ),
      );
      final removeId = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Temporário',
          category: 'Outros',
          date: DateTime(2026, 9, 27),
        ),
      );

      await TransactionRepository.instance.delete(removeId);

      final remaining = await db.query('transactions');
      expect(remaining.length, 1);
      expect(remaining.single['id'], keepId);
    });
  });

  group('BUG 3 — edição persiste no banco', () {
    test('update altera nome, valor, data e categoria', () async {
      final db = await AppDatabase.instance.database;

      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Nome antigo',
          category: 'Outros',
          date: DateTime(2026, 9, 1),
        ),
      );

      await TransactionRepository.instance.update(
        FinanceTransaction(
          id: id,
          type: TransactionType.expense,
          amount: 250.0,
          description: 'Nome novo',
          category: 'Moradia',
          date: DateTime(2026, 9, 15),
        ),
      );

      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows.length, 1);
      expect(rows.single['description'], 'Nome novo');
      expect(rows.single['amount'], 250.0);
      expect(rows.single['category'], 'Moradia');
      expect(
        DateTime.parse(rows.single['transaction_date'] as String),
        DateTime(2026, 9, 15),
      );
    });

    test('update preserva created_at e não duplica a linha', () async {
      final db = await AppDatabase.instance.database;

      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 50.0,
          description: 'Original',
          category: 'Outros',
          date: DateTime(2026, 9, 1),
        ),
      );

      final createdBefore =
          (await db.query('transactions', where: 'id = ?', whereArgs: [id]))
              .single['created_at'];

      await TransactionRepository.instance.update(
        FinanceTransaction(
          id: id,
          type: TransactionType.expense,
          amount: 75.0,
          description: 'Editado',
          category: 'Outros',
          date: DateTime(2026, 9, 1),
        ),
      );

      final rows = await db.query('transactions');
      expect(rows.length, 1, reason: 'edição não deve criar nova linha');
      expect(rows.single['created_at'], createdBefore);
    });
  });

  group('BUG 2 — Contas e vencimentos unifica as fontes', () {
    test('despesa avulsa futura aparece como pendente', () async {
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      expect(pending.length, 1);
      expect(pending.single.bill.name, 'ALUGUEL APARTAMENTO');
      expect(pending.single.bill.amount, 3500.0);
      expect(pending.single.source, BillSource.transaction);
      expect(pending.single.isIncome, isFalse);
    });

    test('receita avulsa futura aparece como pendente de recebimento',
        () async {
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.income,
          amount: 2900.0,
          description: 'Freelance futuro',
          category: 'Freelance',
          date: DateTime(2026, 9, 26),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      expect(pending.length, 1);
      expect(pending.single.isIncome, isTrue);
      expect(pending.single.source, BillSource.transaction);
    });

    test('lançamento passado não aparece como pendente', () async {
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Compra passada',
          category: 'Outros',
          date: DateTime(2020, 1, 1),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      expect(pending, isEmpty,
          reason: 'lançamentos passados já foram realizados');
    });

    test('conta recorrente, parcelamento e lançamento futuro coexistem',
        () async {
      await BillRepository.instance.create(
        Bill(
          name: 'Internet',
          amount: 120.0,
          dueDate: DateTime(2026, 9, 20),
          category: 'Internet',
          recurrence: 'monthly',
          type: 'expense',
        ),
      );

      await InstallmentRepository.instance.create(
        Installment(
          name: 'Notebook',
          totalAmount: 2400.0,
          installmentAmount: 200.0,
          totalInstallments: 12,
          firstDueDate: DateTime(2026, 9, 25),
          category: 'Outros',
        ),
      );

      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      expect(pending.length, 3);

      final sources = pending.map((p) => p.source).toSet();
      expect(sources, containsAll(<BillSource>[
        BillSource.bill,
        BillSource.installment,
        BillSource.transaction,
      ]));

      // Ordenado por vencimento crescente.
      expect(pending.first.bill.name, 'Internet');
      expect(pending.last.bill.name, 'ALUGUEL APARTAMENTO');
    });

    test('não duplica: cada origem gera exatamente um item', () async {
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      expect(pending.length, 1);

      // Nenhuma conta foi criada na tabela bills.
      final db = await AppDatabase.instance.database;
      final bills = await db.query('bills');
      expect(bills, isEmpty,
          reason: 'não deve criar Bill para exibir uma Transaction');
    });

    test('contadores classificam vencidas, hoje e pendentes', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Conta vencida (2 dias atrás) e conta que vence hoje: contam em
      // vencidas/hoje, pois possuem vencimento explícito.
      await BillRepository.instance.create(
        Bill(
          name: 'Conta vencida',
          amount: 100.0,
          dueDate: today.subtract(const Duration(days: 2)),
          category: 'Outros',
          recurrence: 'once',
          type: 'expense',
        ),
      );
      await BillRepository.instance.create(
        Bill(
          name: 'Conta de hoje',
          amount: 200.0,
          dueDate: today,
          category: 'Outros',
          recurrence: 'once',
          type: 'expense',
        ),
      );

      // Lançamento avulso futuro: pendente, mas não vencido nem de hoje.
      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 300.0,
          description: 'Futura',
          category: 'Outros',
          date: today.add(const Duration(days: 5)),
        ),
      );

      final counts = await BillRepository.instance.pendingCounts();
      expect(counts['pending'], 3);
      expect(counts['overdue'], 1);
      expect(counts['today'], 1);
    });

    test('lançamento avulso passado não conta como vencido', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100.0,
          description: 'Compra passada',
          category: 'Outros',
          date: today.subtract(const Duration(days: 2)),
        ),
      );

      final counts = await BillRepository.instance.pendingCounts();
      expect(counts['pending'], 0,
          reason: 'lançamento avulso passado já é um fato realizado');
      expect(counts['overdue'], 0);
    });

    test('pagar lançamento futuro o remove das pendências', () async {
      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      final pending = await BillRepository.instance.listPending();
      final item = pending.single;

      final paid = await BillRepository.instance.markPendingPaid(item);
      expect(paid, isTrue);

      // A transação continua existindo (é um lançamento realizado), mas deixa
      // de ser pendente porque a data passou para hoje.
      final after = await BillRepository.instance.listPending();
      expect(after, isEmpty);

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows.length, 1);
    });

    test('excluir item de lançamento futuro remove a transação', () async {
      final id = await TransactionRepository.instance.create(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 3500.0,
          description: 'ALUGUEL APARTAMENTO',
          category: 'Moradia',
          date: DateTime(2026, 9, 28),
        ),
      );

      final item = (await BillRepository.instance.listPending()).single;
      await BillRepository.instance.deletePending(item);

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, isEmpty);
      expect(await BillRepository.instance.listPending(), isEmpty);
    });

    test('excluir item de parcelamento remove o parcelamento', () async {
      final id = await InstallmentRepository.instance.create(
        Installment(
          name: 'Notebook',
          totalAmount: 2400.0,
          installmentAmount: 200.0,
          totalInstallments: 12,
          firstDueDate: DateTime(2026, 9, 25),
          category: 'Outros',
        ),
      );

      final item = (await BillRepository.instance.listPending()).single;
      expect(item.source, BillSource.installment);

      await BillRepository.instance.deletePending(item);

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'installments',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, isEmpty);
    });

    test('pagar item de parcelamento avança a parcela', () async {
      await InstallmentRepository.instance.create(
        Installment(
          name: 'Notebook',
          totalAmount: 2400.0,
          installmentAmount: 200.0,
          totalInstallments: 12,
          firstDueDate: DateTime(2026, 9, 25),
          category: 'Outros',
        ),
      );

      final item = (await BillRepository.instance.listPending()).single;
      final paid = await BillRepository.instance.markPendingPaid(item);
      expect(paid, isTrue);

      final db = await AppDatabase.instance.database;
      final rows = await db.query('installments');
      expect(rows.single['paid_installments'], 1);

      // Gera a transação correspondente à parcela paga.
      final transactions = await db.query('transactions');
      expect(transactions.length, 1);
      expect(transactions.single['type'], 'expense');
    });
  });
}
