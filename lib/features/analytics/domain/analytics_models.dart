class CategoryAmount {
  final String category;
  final double amount;

  const CategoryAmount(this.category, this.amount);
}

class DailyBalancePoint {
  final DateTime date;
  final double income;
  final double expense;
  final double balance;

  const DailyBalancePoint({
    required this.date,
    required this.income,
    required this.expense,
    required this.balance,
  });
}

class FinanceAnalytics {
  final double income;
  final double expense;
  final double balance;
  final double previousIncome;
  final double previousExpense;
  final double previousBalance;
  final double dailyAverageExpense;
  final String? biggestExpenseCategory;
  final List<CategoryAmount> expensesByCategory;
  final List<DailyBalancePoint> evolution;

  const FinanceAnalytics({
    required this.income,
    required this.expense,
    required this.balance,
    required this.previousIncome,
    required this.previousExpense,
    required this.previousBalance,
    required this.dailyAverageExpense,
    required this.biggestExpenseCategory,
    required this.expensesByCategory,
    required this.evolution,
  });

  double get incomeChangePercent => _change(income, previousIncome);
  double get expenseChangePercent => _change(expense, previousExpense);

  double _change(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }
}

