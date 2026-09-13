class Bill {
  final int? id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final String category;
  final String recurrence;
  final int reminderDays;
  final String status;
  final String? notes;

  /// Tipo da movimentação recorrente: `expense` (despesa) ou `income`
  /// (receita). Registros antigos assumem `expense` para preservar o
  /// comportamento anterior.
  final String type;

  const Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.category,
    this.recurrence = 'once',
    this.reminderDays = 1,
    this.status = 'pending',
    this.notes,
    this.type = 'expense',
  });

  bool get isIncome => type == 'income';

  Map<String, dynamic> toMap() => {
    'name': name, 'amount': amount, 'due_date': dueDate.toIso8601String(),
    'category': category, 'recurrence': recurrence, 'reminder_days': reminderDays,
    'status': status, 'notes': notes, 'type': type,
  };

  factory Bill.fromMap(Map<String,dynamic> m) => Bill(
    id: m['id'] as int?, name: m['name'] as String, amount: (m['amount'] as num).toDouble(),
    dueDate: DateTime.parse(m['due_date'] as String), category: m['category'] as String,
    recurrence: m['recurrence'] as String? ?? 'once', reminderDays: (m['reminder_days'] as num? ?? 1).toInt(),
    status: m['status'] as String? ?? 'pending', notes: m['notes'] as String?,
    type: m['type'] as String? ?? 'expense',
  );
}
