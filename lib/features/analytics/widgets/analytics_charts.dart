import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../domain/analytics_models.dart';

class IncomeExpenseChart extends StatelessWidget {
  final double income;
  final double expense;

  const IncomeExpenseChart({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = (income > expense ? income : expense);
    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 100 : maxValue * 1.2,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  value == 0 ? 'Ganhos' : 'Gastos',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income)]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense)]),
          ],
        ),
      ),
    );
  }
}

class CategoryChart extends StatelessWidget {
  final List<CategoryAmount> data;

  const CategoryChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sem gastos no período.')),
      );
    }

    final top = data.take(5).toList();
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: [
                for (final item in top)
                  PieChartSectionData(
                    value: item.amount,
                    title: '${item.category}\n${money(item.amount)}',
                    radius: 80,
                    titleStyle: const TextStyle(fontSize: 10),
                  ),
              ],
              centerSpaceRadius: 30,
            ),
          ),
        ),
        ...top.map((item) => ListTile(
          dense: true,
          title: Text(item.category),
          trailing: Text(money(item.amount)),
        )),
      ],
    );
  }
}

