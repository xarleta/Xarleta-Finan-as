import '../../../core/database/app_database.dart';
import '../domain/installment_model.dart';

class InstallmentRepository {
  InstallmentRepository._();
  static final instance = InstallmentRepository._();

  Future<List<Installment>> list({bool includeFinished=false}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('installments', where: includeFinished ? null : "status = 'active'", orderBy: 'first_due_date ASC');
    return rows.map(Installment.fromMap).toList();
  }

  Future<int> create(Installment item) async {
    final db = await AppDatabase.instance.database;
    return db.insert('installments', item.toMap());
  }

  Future<void> update(Installment item) async {
    if (item.id == null) return;
    final db = await AppDatabase.instance.database;
    await db.update('installments', item.toMap(), where:'id=?', whereArgs:[item.id]);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('installments', where:'id=?', whereArgs:[id]);
  }

  /// Registra o pagamento da próxima parcela.
  ///
  /// Retorna `true` se a parcela foi paga e `false` se o parcelamento não
  /// existe mais ou já foi finalizado. O estado atual é relido dentro da
  /// transação (em vez de confiar no objeto em memória), impedindo que
  /// cliques simultâneos gerem pagamentos duplicados.
  Future<bool> payNext(Installment item) async {
    if (item.id == null) return false;
    final db = await AppDatabase.instance.database;
    var paidNow = false;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'installments',
        columns: ['paid_installments', 'total_installments', 'status'],
        where: 'id = ?',
        whereArgs: [item.id],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final row = rows.first;
      final currentPaid = (row['paid_installments'] as int?) ?? 0;
      final total = (row['total_installments'] as int?) ?? item.totalInstallments;
      final currentStatus = row['status'] as String?;

      // Já finalizado ou todas as parcelas pagas: não duplica.
      if (currentStatus != 'active' || currentPaid >= total) return;

      final paid = currentPaid + 1;
      final status = paid >= total ? 'finished' : 'active';
      await txn.update(
        'installments',
        {'paid_installments': paid, 'status': status},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      final now = DateTime.now().toIso8601String();
      await txn.insert('transactions', {
        'type': 'expense',
        'amount': item.installmentAmount,
        'description': '${item.name} ($paid/$total)',
        'category': item.category,
        'transaction_date': now,
        'notes': 'Parcela paga',
        'created_at': now,
        'updated_at': now,
      });

      paidNow = true;
    });

    return paidNow;
  }
}

