import '../../../core/database/app_database.dart';
import '../../../services/bill_reminder_service.dart';
import '../domain/bill_model.dart';

class BillRepository {
  BillRepository._();
  static final instance = BillRepository._();

  Future<List<Bill>> list({bool includePaid = false, String? type}) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (!includePaid) {
      where.add("status = 'pending'");
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }

    final rows = await db.query(
      'bills',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'due_date ASC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<int> create(Bill bill) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('bills', bill.toMap());
    await BillReminderService.instance.sync(_withId(bill, id));
    return id;
  }

  Future<void> update(Bill bill) async {
    if (bill.id == null) return;
    final db = await AppDatabase.instance.database;
    await db.update('bills', bill.toMap(),
        where: 'id = ?', whereArgs: [bill.id]);
    await BillReminderService.instance.sync(bill);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
    await BillReminderService.instance.cancel(id);
  }

  /// Marca a conta como paga e registra a transação correspondente.
  ///
  /// Retorna `true` se o pagamento foi efetivado e `false` se a conta já
  /// estava paga (ou não existe mais). A validação de estado é feita dentro
  /// da transação, relendo o registro no banco, para impedir pagamentos
  /// duplicados mesmo em chamadas simultâneas — a flag de UI não é a única
  /// proteção.
  Future<bool> markPaid(Bill bill) async {
    if (bill.id == null) return false;
    final db = await AppDatabase.instance.database;
    int? nextId;
    Bill? nextBill;
    var paid = false;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'bills',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [bill.id],
        limit: 1,
      );

      // Conta inexistente ou já paga: não cria transação nem duplica.
      if (rows.isEmpty || rows.first['status'] == 'paid') {
        return;
      }

      await txn.update(
        'bills',
        {'status': 'paid'},
        where: 'id = ?',
        whereArgs: [bill.id],
      );

      final now = DateTime.now().toIso8601String();
      await txn.insert('transactions', {
        'type': bill.isIncome ? 'income' : 'expense',
        'amount': bill.amount,
        'description': bill.name,
        'category': bill.category,
        'transaction_date': now,
        'notes': bill.isIncome ? 'Receita recebida' : 'Conta paga',
        'created_at': now,
        'updated_at': now,
      });

      final nextDate = _nextDate(bill.dueDate, bill.recurrence);
      if (nextDate != null) {
        final next = Bill(
          name: bill.name,
          amount: bill.amount,
          dueDate: nextDate,
          category: bill.category,
          recurrence: bill.recurrence,
          reminderDays: bill.reminderDays,
          notes: bill.notes,
          type: bill.type,
        );
        nextId = await txn.insert('bills', next.toMap());
        nextBill = _withId(next, nextId!);
      }

      paid = true;
    });

    if (!paid) return false;

    await BillReminderService.instance.cancel(bill.id!);
    if (nextBill != null) {
      await BillReminderService.instance.sync(nextBill!);
    }
    return true;
  }

  Bill _withId(Bill bill, int id) => Bill(
    id: id,
    name: bill.name,
    amount: bill.amount,
    dueDate: bill.dueDate,
    category: bill.category,
    recurrence: bill.recurrence,
    reminderDays: bill.reminderDays,
    status: bill.status,
    notes: bill.notes,
    type: bill.type,
  );

  DateTime? _nextDate(DateTime date, String recurrence) {
    switch (recurrence) {
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(date.year, date.month + 1, date.day);
      case 'yearly':
        return DateTime(date.year + 1, date.month, date.day);
      default:
        return null;
    }
  }

  Future<Map<String, int>> counts({String? type}) async {
    final bills = await list(type: type);
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    int overdue = 0;
    int todayCount = 0;

    for (final bill in bills) {
      final due = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      if (due.isBefore(current)) overdue++;
      if (due == current) todayCount++;
    }

    return {
      'pending': bills.length,
      'overdue': overdue,
      'today': todayCount,
    };
  }
}

