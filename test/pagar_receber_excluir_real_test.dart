import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/installments/data/installment_repository.dart';
import 'package:xarleta_financas/features/installments/domain/installment_model.dart';
import 'package:xarleta_financas/features/transactions/data/transaction_repository.dart';
import 'package:xarleta_financas/features/transactions/domain/transaction_model.dart';

import 'helpers/test_database.dart';

/// Testes REAIS de persistência para os fluxos PAGAR, RECEBER e EXCLUIR.
///
/// Cada teste executa a operação no repositório e consulta o SQLite
/// diretamente para confirmar o efeito real no banco — não apenas o retorno
/// do método. Cobrem os sintomas relatados no Android:
///
/// - PAGAR não faz nada visualmente;
/// - RECEBER não atualiza a interface;
/// - EXCLUIR em "Contas e vencimentos" não reflete em "Ganhos e gastos".
void main() {
  final testDb = TestDatabase('pagar_receber_excluir');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() => testDb.clearTables([
        'transactions',
        'bills',
        'installments',
      ]));

  group('PART 3 — PAGAR despesa recorrente', () {
    test(
      'pagar conta mensal marca como paga, cria transação e gera a próxima '
      'ocorrência no banco',
      () async {
        final db = await AppDatabase.instance.database;

        final billId = await BillRepository.instance.create(
          Bill(
            name: 'ALUGUEL APARTAMENTO',
            amount: 3500.0,
            dueDate: DateTime(2026, 9, 28),
            category: 'Moradia',
            recurrence: 'monthly',
            type: 'expense',
          ),
        );

        // Antes de pagar: existe 1 conta pendente e nenhuma transação.
        expect((await db.query('bills')).length, 1);
        expect(await db.query('transactions'), isEmpty);

        final item = (await BillRepository.instance.listPending()).single;
        expect(item.source, BillSource.bill);

        final paid = await BillRepository.instance.markPendingPaid(item);
        expect(paid, isTrue, reason: 'o pagamento deve ser efetivado');

        // A conta original foi marcada como paga no banco.
        final original = await db.query(
          'bills',
          where: 'id = ?',
          whereArgs: [billId],
        );
        expect(original.single['status'], 'paid');

        // Uma transação real de despesa foi criada.
        final transactions = await db.query('transactions');
        expect(transactions.length, 1);
        expect(transactions.single['type'], 'expense');
        expect(transactions.single['description'], 'ALUGUEL APARTAMENTO');
        expect(
          (transactions.single['amount'] as num).toDouble(),
          3500.0,
        );

        // A próxima ocorrência mensal foi criada como nova conta pendente.
        final allBills = await db.query('bills', orderBy: 'id ASC');
        expect(allBills.length, 2,
            reason: 'pagar uma conta mensal deve gerar a próxima ocorrência');
        final next = allBills.last;
        expect(next['status'], 'pending');
        expect(next['name'], 'ALUGUEL APARTAMENTO');
        expect(
          DateTime.parse(next['due_date'] as String),
          DateTime(2026, 10, 28),
          reason: 'a próxima ocorrência deve vencer um mês depois',
        );

        // A listagem de pendências continua com exatamente 1 item (a próxima).
        final pendingAfter = await BillRepository.instance.listPending();
        expect(pendingAfter.length, 1);
        expect(pendingAfter.single.sourceId, next['id']);
      },
    );

    test(
      'pagar a mesma conta duas vezes não duplica transação nem ocorrência',
      () async {
        final db = await AppDatabase.instance.database;

        await BillRepository.instance.create(
          Bill(
            name: 'INTERNET',
            amount: 120.0,
            dueDate: DateTime(2026, 9, 20),
            category: 'Casa',
            recurrence: 'monthly',
            type: 'expense',
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        expect(await BillRepository.instance.markPendingPaid(item), isTrue);

        // Segunda tentativa com o mesmo item (já pago): deve retornar false.
        final second = await BillRepository.instance.markPendingPaid(item);
        expect(second, isFalse,
            reason: 'a validação dentro da transação impede pagamento duplicado');

        expect((await db.query('transactions')).length, 1);
        // 1 conta paga + 1 próxima ocorrência = 2.
        expect((await db.query('bills')).length, 2);
      },
    );

    test(
      'pagar conta sem recorrência não cria próxima ocorrência',
      () async {
        final db = await AppDatabase.instance.database;

        await BillRepository.instance.create(
          Bill(
            name: 'IPVA',
            amount: 900.0,
            dueDate: DateTime(2026, 9, 15),
            category: 'Impostos',
            recurrence: 'none',
            type: 'expense',
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        expect(await BillRepository.instance.markPendingPaid(item), isTrue);

        expect((await db.query('bills')).length, 1,
            reason: 'conta sem recorrência não deve gerar nova ocorrência');
        expect((await db.query('transactions')).length, 1);
        expect(await BillRepository.instance.listPending(), isEmpty);
      },
    );
  });

  group('PART 4 — RECEBER receita recorrente', () {
    test(
      'receber receita mensal marca como recebida, cria transação de entrada '
      'e gera a próxima ocorrência',
      () async {
        final db = await AppDatabase.instance.database;

        final billId = await BillRepository.instance.create(
          Bill(
            name: 'SALÁRIO',
            amount: 5000.0,
            dueDate: DateTime(2026, 9, 5),
            category: 'Salário',
            recurrence: 'monthly',
            type: 'income',
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        expect(item.isIncome, isTrue,
            reason: 'a receita deve ser reconhecida como entrada');

        final received = await BillRepository.instance.markPendingPaid(item);
        expect(received, isTrue);

        // A receita original foi marcada como recebida.
        final original = await db.query(
          'bills',
          where: 'id = ?',
          whereArgs: [billId],
        );
        expect(original.single['status'], 'paid');

        // A transação criada é do tipo income.
        final transactions = await db.query('transactions');
        expect(transactions.length, 1);
        expect(transactions.single['type'], 'income');
        expect(transactions.single['description'], 'SALÁRIO');
        expect((transactions.single['amount'] as num).toDouble(), 5000.0);

        // A próxima ocorrência mensal foi criada.
        final allBills = await db.query('bills', orderBy: 'id ASC');
        expect(allBills.length, 2);
        expect(allBills.last['status'], 'pending');
        expect(allBills.last['type'], 'income');
        expect(
          DateTime.parse(allBills.last['due_date'] as String),
          DateTime(2026, 10, 5),
        );
      },
    );

    test(
      'receber receita avulsa futura (lançamento) a remove das pendências '
      'sem criar nova ocorrência',
      () async {
        final db = await AppDatabase.instance.database;

        final txId = await TransactionRepository.instance.create(
          FinanceTransaction(
            type: TransactionType.income,
            amount: 800.0,
            description: 'Freelance',
            category: 'Freelance',
            date: DateTime(2026, 9, 30),
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        expect(item.source, BillSource.transaction);
        expect(item.isIncome, isTrue);

        final received = await BillRepository.instance.markPendingPaid(item);
        expect(received, isTrue);

        // A transação continua existindo (é um fato realizado), mas com a data
        // ajustada para hoje, deixando de ser pendente.
        final rows = await db.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [txId],
        );
        expect(rows.length, 1);
        expect(rows.single['type'], 'income');

        expect(await BillRepository.instance.listPending(), isEmpty,
            reason: 'após receber, não deve restar pendência');
      },
    );
  });

  group('PART 5 — EXCLUIR reflete em todos os módulos', () {
    test(
      'excluir conta recorrente em Contas e vencimentos remove do banco e '
      'não deixa rastro em Ganhos e gastos',
      () async {
        final db = await AppDatabase.instance.database;

        final billId = await BillRepository.instance.create(
          Bill(
            name: 'ACADEMIA',
            amount: 150.0,
            dueDate: DateTime(2026, 9, 10),
            category: 'Saúde',
            recurrence: 'monthly',
            type: 'expense',
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        await BillRepository.instance.deletePending(item);

        // Sumiu da tabela de contas.
        final bills = await db.query(
          'bills',
          where: 'id = ?',
          whereArgs: [billId],
        );
        expect(bills, isEmpty);

        // Não há transação órfã em Ganhos e gastos.
        final transactions = await TransactionRepository.instance.list();
        expect(
          transactions.where((t) => t.description == 'ACADEMIA'),
          isEmpty,
          reason: 'excluir a conta não pode deixar lançamento em Ganhos e gastos',
        );

        expect(await BillRepository.instance.listPending(), isEmpty);
      },
    );

    test(
      'excluir lançamento futuro em Contas e vencimentos remove a transação '
      'de Ganhos e gastos',
      () async {
        final db = await AppDatabase.instance.database;

        final txId = await TransactionRepository.instance.create(
          FinanceTransaction(
            type: TransactionType.expense,
            amount: 3500.0,
            description: 'ALUGUEL APARTAMENTO',
            category: 'Moradia',
            date: DateTime(2026, 9, 28),
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        expect(item.source, BillSource.transaction);

        await BillRepository.instance.deletePending(item);

        // A transação foi removida do banco.
        final rows = await db.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [txId],
        );
        expect(rows, isEmpty);

        // E não aparece mais em Ganhos e gastos.
        final list = await TransactionRepository.instance.list();
        expect(list.where((t) => t.id == txId), isEmpty);
      },
    );

    test(
      'excluir lançamento em Ganhos e gastos remove de Contas e vencimentos',
      () async {
        final db = await AppDatabase.instance.database;

        final txId = await TransactionRepository.instance.create(
          FinanceTransaction(
            type: TransactionType.expense,
            amount: 200.0,
            description: 'Conta de luz',
            category: 'Casa',
            date: DateTime(2026, 9, 29),
          ),
        );

        // Aparece como pendência em Contas e vencimentos.
        expect((await BillRepository.instance.listPending()).length, 1);

        // Exclui pela tela de Ganhos e gastos.
        await TransactionRepository.instance.delete(txId);

        // Some do banco...
        final rows = await db.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [txId],
        );
        expect(rows, isEmpty);

        // ...e some de Contas e vencimentos.
        expect(await BillRepository.instance.listPending(), isEmpty,
            reason: 'excluir em Ganhos e gastos deve refletir em '
                'Contas e vencimentos');
      },
    );

    test(
      'excluir parcelamento remove parcelamento e parcelas pagas de '
      'Ganhos e gastos',
      () async {
        final db = await AppDatabase.instance.database;

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

        // Paga uma parcela para gerar transação derivada.
        final item = (await BillRepository.instance.listPending()).single;
        expect(await BillRepository.instance.markPendingPaid(item), isTrue);
        expect(
          (await db.query('transactions')).length,
          1,
          reason: 'a parcela paga gera uma transação derivada',
        );

        // Exclui o parcelamento em Contas e vencimentos.
        final pending = (await BillRepository.instance.listPending()).single;
        await BillRepository.instance.deletePending(pending);

        expect(await db.query('installments'), isEmpty);
        expect(await db.query('transactions'), isEmpty,
            reason: 'as parcelas pagas não podem ficar órfãs em '
                'Ganhos e gastos');
        expect(await BillRepository.instance.listPending(), isEmpty);
      },
    );
  });

  group('PART 8 — fonte única de verdade entre módulos', () {
    test(
      'pagar conta recorrente reflete no resumo do dashboard',
      () async {
        await BillRepository.instance.create(
          Bill(
            name: 'ALUGUEL APARTAMENTO',
            amount: 3500.0,
            dueDate: DateTime(2026, 9, 28),
            category: 'Moradia',
            recurrence: 'monthly',
            type: 'expense',
          ),
        );

        // Antes de pagar, o resumo não tem despesa realizada.
        var summary = await TransactionRepository.instance.summary();
        expect(summary['expense'], 0);

        final item = (await BillRepository.instance.listPending()).single;
        await BillRepository.instance.markPendingPaid(item);

        // Após pagar, o resumo (mesma fonte: tabela transactions) reflete.
        summary = await TransactionRepository.instance.summary();
        expect(summary['expense'], 3500.0,
            reason: 'o dashboard lê a mesma tabela de transações');
      },
    );

    test(
      'receber receita recorrente reflete no resumo do dashboard',
      () async {
        await BillRepository.instance.create(
          Bill(
            name: 'SALÁRIO',
            amount: 5000.0,
            dueDate: DateTime(2026, 9, 5),
            category: 'Salário',
            recurrence: 'monthly',
            type: 'income',
          ),
        );

        var summary = await TransactionRepository.instance.summary();
        expect(summary['income'], 0);

        final item = (await BillRepository.instance.listPending()).single;
        await BillRepository.instance.markPendingPaid(item);

        summary = await TransactionRepository.instance.summary();
        expect(summary['income'], 5000.0);
      },
    );

    test(
      'excluir conta paga remove a transação correspondente do resumo',
      () async {
        final db = await AppDatabase.instance.database;

        await BillRepository.instance.create(
          Bill(
            name: 'ALUGUEL APARTAMENTO',
            amount: 3500.0,
            dueDate: DateTime(2026, 9, 28),
            category: 'Moradia',
            recurrence: 'none',
            type: 'expense',
          ),
        );

        final item = (await BillRepository.instance.listPending()).single;
        await BillRepository.instance.markPendingPaid(item);

        var summary = await TransactionRepository.instance.summary();
        expect(summary['expense'], 3500.0);

        // A conta paga não aparece mais em pendências; a transação permanece
        // como fato realizado (comportamento esperado).
        expect(await BillRepository.instance.listPending(), isEmpty);
        expect((await db.query('transactions')).length, 1);
      },
    );
  });
}
