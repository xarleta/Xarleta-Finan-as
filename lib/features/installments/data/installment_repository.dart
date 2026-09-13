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

  Future<void> payNext(Installment item) async {
    if (item.id == null || item.status != 'active') return;
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final paid = item.paidInstallments + 1;
      final status = paid >= item.totalInstallments ? 'finished' : 'active';
      await txn.update('installments', {'paid_installments': paid, 'status': status}, where:'id=?', whereArgs:[item.id]);
      final now = DateTime.now().toIso8601String();
      await txn.insert('transactions', {
        'type':'expense','amount':item.installmentAmount,'description':'${item.name} ($paid/${item.totalInstallments})',
        'category':item.category,'transaction_date':now,'notes':'Parcela paga','created_at':now,'updated_at':now,
      });
    });
  }
}

