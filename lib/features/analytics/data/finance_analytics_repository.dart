import '../../../core/analytics/date_range.dart';
import '../../../core/database/app_database.dart';
import '../domain/analytics_models.dart';

class FinanceAnalyticsRepository {
  FinanceAnalyticsRepository._();
  static final instance = FinanceAnalyticsRepository._();

  Future<FinanceAnalytics> load(FinanceDateRange range) async {
    final current = await _totals(range);
    final previous = await _totals(range.previous());
    final categories = await _categories(range);
    final evolution = await _evolution(range);

    return FinanceAnalytics(
      income: current.$1,
      expense: current.$2,
      balance: current.$1 - current.$2,
      previousIncome: previous.$1,
      previousExpense: previous.$2,
      previousBalance: previous.$1 - previous.$2,
      dailyAverageExpense: range.days <= 0 ? 0 : current.$2 / range.days,
      biggestExpenseCategory: categories.isEmpty ? null : categories.first.category,
      expensesByCategory: categories,
      evolution: evolution,
    );
  }

  Future<(double, double)> _totals(FinanceDateRange range) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date < ?
    ''', [range.start.toIso8601String(), range.end.toIso8601String()]);

    final row = rows.first;
    return ((row['income'] as num).toDouble(), (row['expense'] as num).toDouble());
  }

  Future<List<CategoryAmount>> _categories(FinanceDateRange range) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT category, SUM(amount) AS total
      FROM transactions
      WHERE type = 'expense' AND transaction_date >= ? AND transaction_date < ?
      GROUP BY category ORDER BY total DESC
    ''', [range.start.toIso8601String(), range.end.toIso8601String()]);

    return rows.map((r) => CategoryAmount(r['category'] as String, (r['total'] as num).toDouble())).toList();
  }

  Future<List<DailyBalancePoint>> _evolution(FinanceDateRange range) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT substr(transaction_date, 1, 10) AS day,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      GROUP BY substr(transaction_date, 1, 10)
      ORDER BY day ASC
    ''', [range.start.toIso8601String(), range.end.toIso8601String()]);

    double running = 0;
    return rows.map((r) {
      final income = (r['income'] as num).toDouble();
      final expense = (r['expense'] as num).toDouble();
      running += income - expense;
      return DailyBalancePoint(date: DateTime.parse(r['day'] as String), income: income, expense: expense, balance: running);
    }).toList();
  }
}

