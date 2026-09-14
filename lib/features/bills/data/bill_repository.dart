import '../../../core/database/app_database.dart';
import '../../../core/state/data_change_notifier.dart';
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
    DataChangeNotifier.instance.notifyChanged();
    return id;
  }

  Future<void> update(Bill bill) async {
    if (bill.id == null) return;
    final db = await AppDatabase.instance.database;
    await db.update('bills', bill.toMap(),
        where: 'id = ?', whereArgs: [bill.id]);
    await BillReminderService.instance.sync(bill);
    DataChangeNotifier.instance.notifyChanged();
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
    await BillReminderService.instance.cancel(id);
    DataChangeNotifier.instance.notifyChanged();
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
    DataChangeNotifier.instance.notifyChanged();
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

  /// Lista unificada para "Contas e vencimentos".
  ///
  /// Reúne, sem duplicar dados, as três fontes de movimentações pendentes:
  ///
  /// - contas recorrentes pendentes (`bills`, `status = 'pending'`);
  /// - parcelamentos ativos (`installments`, `status = 'active'`), exibidos
  ///   pela próxima parcela a vencer;
  /// - despesas/receitas avulsas com vencimento futuro (`transactions` com
  ///   `transaction_date` posterior a hoje), que antes não apareciam nesta
  ///   tela.
  ///
  /// Cada item preserva a origem ([PendingItem.source]) para que o pagamento
  /// ou a exclusão sejam aplicados na tabela correta, sem criar registros
  /// duplicados.
  Future<List<PendingItem>> listPending({String? type}) async {
    final db = await AppDatabase.instance.database;
    final items = <PendingItem>[];

    // Contas recorrentes pendentes.
    final billRows = await db.query(
      'bills',
      where: type == null ? "status = 'pending'" : "status = 'pending' AND type = ?",
      whereArgs: type == null ? null : [type],
      orderBy: 'due_date ASC',
    );
    for (final row in billRows) {
      final bill = Bill.fromMap(row);
      items.add(
        PendingItem(
          bill: bill,
          source: BillSource.bill,
          sourceId: bill.id!,
        ),
      );
    }

    // Parcelamentos ativos: exibidos pela próxima parcela a vencer.
    final installmentRows = await db.query(
      'installments',
      where: "status = 'active'",
      orderBy: 'first_due_date ASC',
    );
    for (final row in installmentRows) {
      final paid = (row['paid_installments'] as num? ?? 0).toInt();
      final firstDue = DateTime.parse(row['first_due_date'] as String);
      final nextDue = DateTime(
        firstDue.year,
        firstDue.month + paid,
        firstDue.day,
      );
      final bill = Bill(
        id: row['id'] as int?,
        name: row['name'] as String,
        amount: (row['installment_amount'] as num).toDouble(),
        dueDate: nextDue,
        category: row['category'] as String,
        recurrence: 'once',
        status: 'pending',
        notes: row['notes'] as String?,
        type: 'expense',
      );
      items.add(
        PendingItem(
          bill: bill,
          source: BillSource.installment,
          sourceId: bill.id!,
        ),
      );
    }

    // Movimentações avulsas futuras (ainda não realizadas).
    //
    // Uma transação representa um fato já ocorrido na data informada. Por
    // isso, apenas as com data estritamente futura são consideradas pendentes:
    // ao chegar o dia (ou ao serem confirmadas), deixam de ser pendentes e
    // passam a compor o realizado. Datas passadas não entram como "vencidas"
    // porque, para lançamentos avulsos, não há distinção entre "não pago" e
    // "já realizado" — vencidas/hoje aplicam-se a contas e parcelamentos, que
    // possuem vencimento explícito.
    final today = DateTime.now();
    final startOfTomorrow = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));
    final transactionRows = await db.query(
      'transactions',
      where: type == null
          ? 'transaction_date >= ?'
          : 'transaction_date >= ? AND type = ?',
      whereArgs: type == null
          ? [startOfTomorrow.toIso8601String()]
          : [startOfTomorrow.toIso8601String(), type],
      orderBy: 'transaction_date ASC',
    );
    for (final row in transactionRows) {
      final bill = Bill(
        id: row['id'] as int?,
        name: row['description'] as String,
        amount: (row['amount'] as num).toDouble(),
        dueDate: DateTime.parse(row['transaction_date'] as String),
        category: row['category'] as String,
        recurrence: 'once',
        status: 'pending',
        notes: row['notes'] as String?,
        type: row['type'] as String,
      );
      items.add(
        PendingItem(
          bill: bill,
          source: BillSource.transaction,
          sourceId: bill.id!,
        ),
      );
    }

    items.sort((a, b) => a.bill.dueDate.compareTo(b.bill.dueDate));
    return items;
  }

  /// Contadores de "Contas e vencimentos" considerando as três fontes.
  ///
  /// Observação de performance: a tela já carrega a lista completa via
  /// [listPending]. Para evitar uma segunda consulta idêntica ao banco, a tela
  /// deve preferir [countsFromItems] com a lista já carregada. Este método
  /// permanece para usos isolados (ex.: notificações) que não têm a lista.
  Future<Map<String, int>> pendingCounts({String? type}) async {
    final items = await listPending(type: type);
    return countsFromItems(items);
  }

  /// Calcula os contadores a partir de uma lista já carregada, sem tocar no
  /// banco. Evita a consulta duplicada de [pendingCounts] na tela de Contas.
  Map<String, int> countsFromItems(List<PendingItem> items) {
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    int overdue = 0;
    int todayCount = 0;

    for (final item in items) {
      final due = DateTime(
        item.bill.dueDate.year,
        item.bill.dueDate.month,
        item.bill.dueDate.day,
      );
      if (due.isBefore(current)) overdue++;
      if (due == current) todayCount++;
    }

    return {
      'pending': items.length,
      'overdue': overdue,
      'today': todayCount,
    };
  }

  /// Marca como pago/recebido um item unificado, aplicando a operação na
  /// tabela de origem correta.
  ///
  /// - [BillSource.bill]: delega para [markPaid] (gera transação e próxima
  ///   ocorrência quando recorrente).
  /// - [BillSource.installment]: delega para o repositório de parcelamentos.
  /// - [BillSource.transaction]: movimentação avulsa futura; ao ser
  ///   confirmada, apenas deixa de ser pendente (a data é antecipada para
  ///   hoje), pois a transação já representa o lançamento realizado.
  ///
  /// Retorna `true` quando a operação foi efetivada.
  Future<bool> markPendingPaid(PendingItem item) async {
    switch (item.source) {
      case BillSource.bill:
        return markPaid(item.bill);
      case BillSource.installment:
        return _payInstallment(item.sourceId);
      case BillSource.transaction:
        return _settleTransaction(item.sourceId);
    }
  }

  Future<bool> _payInstallment(int id) async {
    final db = await AppDatabase.instance.database;
    var paid = false;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'installments',
        columns: ['paid_installments', 'total_installments', 'status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final row = rows.first;
      final currentPaid = (row['paid_installments'] as num? ?? 0).toInt();
      final total = (row['total_installments'] as num).toInt();
      final status = row['status'] as String?;
      if (status != 'active' || currentPaid >= total) return;

      final nextPaid = currentPaid + 1;
      final nextStatus = nextPaid >= total ? 'finished' : 'active';
      await txn.update(
        'installments',
        {'paid_installments': nextPaid, 'status': nextStatus},
        where: 'id = ?',
        whereArgs: [id],
      );

      final installmentRows = await txn.query(
        'installments',
        columns: ['name', 'installment_amount', 'category'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final data = installmentRows.first;
      final now = DateTime.now().toIso8601String();
      await txn.insert('transactions', {
        'type': 'expense',
        'amount': (data['installment_amount'] as num).toDouble(),
        'description':
            '${data['name']} ($nextPaid/$total)',
        'category': data['category'],
        'transaction_date': now,
        'notes': 'Parcela paga',
        'created_at': now,
        'updated_at': now,
      });

      paid = true;
    });

    if (paid) DataChangeNotifier.instance.notifyChanged();
    return paid;
  }

  Future<bool> _settleTransaction(int id) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final updated = await db.update(
      'transactions',
      {'transaction_date': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated > 0) DataChangeNotifier.instance.notifyChanged();
    return updated > 0;
  }

  /// Exclui um item unificado na sua tabela de origem.
  ///
  /// A exclusão é aplicada na tabela de origem e, quando a origem possui
  /// transações derivadas (parcelas já pagas de um parcelamento), essas também
  /// são removidas na mesma transação de banco. Sem isso, o item desaparecia de
  /// "Contas e vencimentos" mas permanecia em "Ganhos e gastos" como dado
  /// órfão — exatamente o sintoma de dessincronização relatado (BUG 2).
  Future<void> deletePending(PendingItem item) async {
    switch (item.source) {
      case BillSource.bill:
        // `delete` já remove a conta e notifica as telas.
        await delete(item.sourceId);
      case BillSource.installment:
        final db = await AppDatabase.instance.database;
        await db.transaction((txn) async {
          // Remove as transações geradas pelas parcelas já pagas deste
          // parcelamento, identificadas pela descrição "Nome (n/total)".
          final rows = await txn.query(
            'installments',
            columns: ['name', 'total_installments'],
            where: 'id = ?',
            whereArgs: [item.sourceId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final name = rows.first['name'] as String;
            final total = (rows.first['total_installments'] as num).toInt();
            for (var n = 1; n <= total; n++) {
              await txn.delete(
                'transactions',
                where: 'description = ?',
                whereArgs: ['$name ($n/$total)'],
              );
            }
          }
          await txn.delete(
            'installments',
            where: 'id = ?',
            whereArgs: [item.sourceId],
          );
        });
        DataChangeNotifier.instance.notifyChanged();
      case BillSource.transaction:
        final db = await AppDatabase.instance.database;
        await db.delete('transactions',
            where: 'id = ?', whereArgs: [item.sourceId]);
        DataChangeNotifier.instance.notifyChanged();
    }
  }
}

