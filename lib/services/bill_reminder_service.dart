import '../features/bills/domain/bill_model.dart';
import 'notification_service.dart';

class BillReminderService {
  BillReminderService._();
  static final instance = BillReminderService._();

  Future<void> sync(Bill bill) async {
    if (bill.id == null) return;
    await NotificationService.instance.cancel(bill.id!);
    if (bill.status == 'paid') return;

    final reminder = bill.dueDate.subtract(Duration(days: bill.reminderDays));
    await NotificationService.instance.scheduleBillReminder(
      id: bill.id!,
      title: 'Conta próxima do vencimento',
      body: '${bill.name}: R\$ ${bill.amount.toStringAsFixed(2)} vence em ${bill.dueDate.day.toString().padLeft(2, '0')}/${bill.dueDate.month.toString().padLeft(2, '0')}',
      scheduledAt: reminder,
    );
  }

  Future<void> cancel(int id) => NotificationService.instance.cancel(id);
}

