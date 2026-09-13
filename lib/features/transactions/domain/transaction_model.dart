enum TransactionType { income, expense }

class FinanceTransaction {
  final int? id;
  final TransactionType type;
  final double amount;
  final String description;
  final String category;
  final DateTime date;
  final String? notes;

  const FinanceTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'amount': amount,
    'description': description,
    'category': category,
    'transaction_date': date.toIso8601String(),
    'notes': notes,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) => FinanceTransaction(
    id: map['id'] as int?,
    type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
    amount: (map['amount'] as num).toDouble(),
    description: map['description'] as String,
    category: map['category'] as String,
    date: DateTime.parse(map['transaction_date'] as String),
    notes: map['notes'] as String?,
  );
}

