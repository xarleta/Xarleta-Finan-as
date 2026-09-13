class Installment {
  final int? id;
  final String name;
  final double totalAmount;
  final double installmentAmount;
  final int totalInstallments;
  final int paidInstallments;
  final DateTime firstDueDate;
  final String category;
  final String status;
  final int reminderDays;
  final String? notes;

  const Installment({this.id, required this.name, required this.totalAmount, required this.installmentAmount, required this.totalInstallments, this.paidInstallments=0, required this.firstDueDate, required this.category, this.status='active', this.reminderDays=1, this.notes});

  Map<String,dynamic> toMap() => {
    'name': name, 'total_amount': totalAmount, 'installment_amount': installmentAmount,
    'total_installments': totalInstallments, 'paid_installments': paidInstallments,
    'first_due_date': firstDueDate.toIso8601String(), 'category': category,
    'status': status, 'reminder_days': reminderDays, 'notes': notes,
  };

  factory Installment.fromMap(Map<String,dynamic> m) => Installment(
    id:m['id'] as int?, name:m['name'] as String, totalAmount:(m['total_amount'] as num).toDouble(),
    installmentAmount:(m['installment_amount'] as num).toDouble(), totalInstallments:(m['total_installments'] as num).toInt(),
    paidInstallments:(m['paid_installments'] as num? ?? 0).toInt(), firstDueDate:DateTime.parse(m['first_due_date'] as String),
    category:m['category'] as String, status:m['status'] as String? ?? 'active', reminderDays:(m['reminder_days'] as num? ?? 1).toInt(), notes:m['notes'] as String?,
  );

  int get remaining => totalInstallments - paidInstallments;
  double get remainingAmount => remaining * installmentAmount;
  DateTime get nextDueDate => DateTime(firstDueDate.year, firstDueDate.month + paidInstallments, firstDueDate.day);
}

