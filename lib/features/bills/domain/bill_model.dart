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

/// Origem de um item exibido em "Contas e vencimentos".
///
/// A tela unifica três fontes já existentes no banco, sem duplicar dados:
/// contas recorrentes (`bills`), parcelamentos (`installments`) e despesas ou
/// receitas avulsas com vencimento futuro (`transactions`). Cada item continua
/// sendo pago/excluído na sua própria tabela de origem.
enum BillSource { bill, installment, transaction }

/// Item unificado exibido em "Contas e vencimentos".
///
/// Reutiliza o modelo [Bill] para os campos comuns (nome, valor, vencimento,
/// categoria, tipo) e acrescenta a origem e o identificador da tabela de
/// origem, necessários para pagar/excluir o registro correto.
class PendingItem {
  final Bill bill;
  final BillSource source;

  /// Identificador do registro na tabela de origem (`bills`, `installments`
  /// ou `transactions`). É o `bill.id` para contas recorrentes.
  final int sourceId;

  const PendingItem({
    required this.bill,
    required this.source,
    required this.sourceId,
  });

  bool get isIncome => bill.isIncome;
}
