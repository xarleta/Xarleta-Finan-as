import 'package:flutter/material.dart';
import '../../core/analytics/date_range.dart';
import '../../core/state/data_change_listener.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'data/finance_analytics_repository.dart';
import 'domain/analytics_models.dart';
import 'widgets/analytics_charts.dart';
import 'widgets/period_selector.dart';

class AnalyticsPageV5 extends StatefulWidget {
  const AnalyticsPageV5({super.key});

  @override
  State<AnalyticsPageV5> createState() => _AnalyticsPageV5State();
}

class _AnalyticsPageV5State extends State<AnalyticsPageV5>
    with DataChangeListenerMixin {
  PeriodFilter _filter = PeriodFilter.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  late Future<FinanceAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  FinanceDateRange get _range => FinanceDateRange.fromFilter(
    _filter,
    customStart: _customStart,
    customEnd: _customEnd,
  );

  Future<FinanceAnalytics> _load() =>
      FinanceAnalyticsRepository.instance.load(_range);

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  void onDataChanged() {
    // Recarrega as análises quando qualquer repositório sinaliza uma escrita. O
    // agendamento para o próximo frame e a filtragem de telas não visíveis são
    // feitos pelo `DataChangeListenerMixin`.
    _reload();
  }

  /// Retorna `true` quando um intervalo personalizado válido foi escolhido.
  Future<bool> _selectCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _customStart ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _customEnd ?? DateTime.now(),
      ),
    );
    if (result == null) return false;
    setState(() {
      _customStart = result.start;
      _customEnd = result.end;
    });
    return true;
  }

  Future<void> _onFilterChanged(PeriodFilter value) async {
    if (value == PeriodFilter.custom) {
      // Só aplica o filtro personalizado se o usuário confirmar um intervalo.
      // Ao cancelar, mantém o período anterior, evitando DateRange inválido.
      final selected = await _selectCustomRange();
      if (!selected) return;
    }
    setState(() {
      _filter = value;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceAnalytics>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PeriodSelector(
                selected: _filter,
                onChanged: _onFilterChanged,
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Text(
                        'Não foi possível carregar as análises.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _reload,
                        child: const Text('TENTAR NOVAMENTE'),
                      ),
                    ],
                  ),
                )
              else if (data != null) ...[
                const SizedBox(height: 16),
                _HeroBalance(balance: data.balance),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Metric('Ganhos', data.income, AppTheme.positive)),
                    const SizedBox(width: 12),
                    Expanded(child: _Metric('Gastos', data.expense, AppTheme.negative)),
                  ],
                ),
                const SizedBox(height: 20),
                _InsightCard(data: data),
                const SizedBox(height: 20),
                const Text('Ganhos x gastos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IncomeExpenseChart(
                      income: data.income,
                      expense: data.expense,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Gastos por categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CategoryChart(data: data.expensesByCategory),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroBalance extends StatelessWidget {
  final double balance;
  const _HeroBalance({required this.balance});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SALDO DO PERÍODO', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Text(
          money(balance),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  const _Metric(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(
            money(value),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class _InsightCard extends StatelessWidget {
  final FinanceAnalytics data;
  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data.biggestExpenseCategory ?? 'Nenhuma';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo inteligente', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Maior categoria de gasto: $category'),
            Text('Média diária de gastos: ${money(data.dailyAverageExpense)}'),
            Text(
              'Variação dos gastos: ${data.expenseChangePercent.toStringAsFixed(1)}% em relação ao período anterior.',
            ),
          ],
        ),
      ),
    );
  }
}

