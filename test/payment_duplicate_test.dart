import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/installments/data/installment_repository.dart';
import 'package:xarleta_financas/features/installments/domain/installment_model.dart';

import 'helpers/test_database.dart';

/// Testes críticos de pagamento: garantem que a validação de estado é feita
/// no banco (dentro da transação) e que pagamentos duplicados não geram
/// transações duplicadas, mesmo quando a UI é contornada.
///
/// O banco é preparado pelo helper compartilhado [TestDatabase], que usa um
/// diretório temporário exclusivo por arquivo e limpa o singleton ao final,
/// evitando vazamento de estado entre os isolates paralelos do `flutter test`.
void main() {
  final testDb = TestDatabase('payments');

  setUpAll(testDb.setUpAll);
  tearDownAll(testDb.tearDownAll);

  setUp(() => testDb.clearTables(['transactions', 'bills', 'installments']));

  group('BillRepository.markPaid', () {
    test('paga uma conta uma única vez e cria apenas uma transação', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('bills', {
        'name': 'Internet',
        'amount': 120.0,
        'due_date': '2026-02-10T00:00:00.000',
        'category': 'Internet',
        'recurrence': 'once',
        'reminder_days': 1,
        'status': 'pending',
        'notes': null,
      });

      final bill = Bill(
        id: id,
        name: 'Internet',
        amount: 120.0,
        dueDate: DateTime(2026, 2, 10),
        category: 'Internet',
      );

      final first = await BillRepository.instance.markPaid(bill);
      final second = await BillRepository.instance.markPaid(bill);

      expect(first, isTrue, reason: 'primeiro pagamento deve efetivar');
      expect(second, isFalse, reason: 'segundo pagamento deve ser recusado');

      final transactions = await db.query('transactions');
      expect(transactions.length, 1,
          reason: 'não pode haver transação duplicada');

      final rows = await db.query('bills', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['status'], 'paid');
    });

    test('chamadas simultâneas de markPaid criam apenas uma transação',
        () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('bills', {
        'name': 'Água',
        'amount': 80.0,
        'due_date': '2026-03-05T00:00:00.000',
        'category': 'Moradia',
        'recurrence': 'once',
        'reminder_days': 1,
        'status': 'pending',
        'notes': null,
      });

      final bill = Bill(
        id: id,
        name: 'Água',
        amount: 80.0,
        dueDate: DateTime(2026, 3, 5),
        category: 'Moradia',
      );

      final results = await Future.wait([
        BillRepository.instance.markPaid(bill),
        BillRepository.instance.markPaid(bill),
      ]);

      expect(results.where((r) => r).length, 1,
          reason: 'apenas uma chamada concorrente deve efetivar o pagamento');

      final transactions = await db.query('transactions');
      expect(transactions.length, 1);
    });

    test('não paga conta inexistente', () async {
      final db = await AppDatabase.instance.database;
      final bill = Bill(
        id: 9999,
        name: 'Fantasma',
        amount: 10.0,
        dueDate: DateTime(2026, 4, 1),
        category: 'Outros',
      );

      final result = await BillRepository.instance.markPaid(bill);

      expect(result, isFalse);
      expect((await db.query('transactions')).isEmpty, isTrue);
    });

    test('conta recorrente gera a próxima ocorrência sem duplicar', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('bills', {
        'name': 'Academia',
        'amount': 90.0,
        'due_date': '2026-05-10T00:00:00.000',
        'category': 'Academia',
        'recurrence': 'monthly',
        'reminder_days': 1,
        'status': 'pending',
        'notes': null,
      });

      final bill = Bill(
        id: id,
        name: 'Academia',
        amount: 90.0,
        dueDate: DateTime(2026, 5, 10),
        category: 'Academia',
        recurrence: 'monthly',
      );

      final first = await BillRepository.instance.markPaid(bill);
      final second = await BillRepository.instance.markPaid(bill);

      expect(first, isTrue);
      expect(second, isFalse);

      final transactions = await db.query('transactions');
      expect(transactions.length, 1);

      final bills = await db.query('bills');
      expect(bills.length, 2, reason: 'original paga + próxima ocorrência');
      expect(
        bills.where((b) => b['status'] == 'pending').length,
        1,
        reason: 'apenas a próxima ocorrência deve ficar pendente',
      );
    });
  });

  group('InstallmentRepository.payNext', () {
    test('paga parcelas até finalizar sem duplicar transações', () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('installments', {
        'name': 'Celular',
        'total_amount': 300.0,
        'installment_amount': 100.0,
        'total_installments': 3,
        'paid_installments': 0,
        'first_due_date': '2026-01-15T00:00:00.000',
        'category': 'Outros',
        'status': 'active',
        'reminder_days': 1,
        'notes': null,
      });

      final item = Installment(
        id: id,
        name: 'Celular',
        totalAmount: 300.0,
        installmentAmount: 100.0,
        totalInstallments: 3,
        firstDueDate: DateTime(2026, 1, 15),
        category: 'Outros',
      );

      expect(await InstallmentRepository.instance.payNext(item), isTrue);
      expect(await InstallmentRepository.instance.payNext(item), isTrue);
      expect(await InstallmentRepository.instance.payNext(item), isTrue);

      // Já finalizado: não deve pagar novamente.
      expect(await InstallmentRepository.instance.payNext(item), isFalse);

      final transactions = await db.query('transactions');
      expect(transactions.length, 3,
          reason: 'uma transação por parcela, sem duplicidade');

      final rows =
          await db.query('installments', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['paid_installments'], 3);
      expect(rows.single['status'], 'finished');
    });

    test('chamadas simultâneas de payNext não duplicam a mesma parcela',
        () async {
      final db = await AppDatabase.instance.database;
      final id = await db.insert('installments', {
        'name': 'Notebook',
        'total_amount': 200.0,
        'installment_amount': 100.0,
        'total_installments': 2,
        'paid_installments': 0,
        'first_due_date': '2026-01-20T00:00:00.000',
        'category': 'Outros',
        'status': 'active',
        'reminder_days': 1,
        'notes': null,
      });

      final item = Installment(
        id: id,
        name: 'Notebook',
        totalAmount: 200.0,
        installmentAmount: 100.0,
        totalInstallments: 2,
        firstDueDate: DateTime(2026, 1, 20),
        category: 'Outros',
      );

      final results = await Future.wait([
        InstallmentRepository.instance.payNext(item),
        InstallmentRepository.instance.payNext(item),
      ]);

      expect(results.where((r) => r).length, 2,
          reason: 'as duas chamadas devem pagar parcelas distintas');

      final transactions = await db.query('transactions');
      expect(transactions.length, 2);

      final rows =
          await db.query('installments', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['paid_installments'], 2);
      expect(rows.single['status'], 'finished');
    });

    test('não paga parcelamento inexistente', () async {
      final db = await AppDatabase.instance.database;
      final item = Installment(
        id: 9999,
        name: 'Inexistente',
        totalAmount: 100.0,
        installmentAmount: 50.0,
        totalInstallments: 2,
        firstDueDate: DateTime(2026, 1, 1),
        category: 'Outros',
      );

      final result = await InstallmentRepository.instance.payNext(item);

      expect(result, isFalse);
      expect((await db.query('transactions')).isEmpty, isTrue);
    });
  });
}
