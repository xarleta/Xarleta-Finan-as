import 'package:flutter/material.dart';
import '../../core/state/data_change_listener.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../transactions/data/transaction_repository.dart';
import 'dashboard_customize_page.dart';
import 'data/dashboard_preferences_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with DataChangeListenerMixin {
  late Future<Map<String, double>> _summaryFuture;

  /// Personalização carregada do banco. Enquanto não carregada, usa o padrão
  /// para que o dashboard nunca fique vazio ou travado.
  DashboardPreferences _preferences = DashboardPreferences.defaults;

  @override
  void initState() {
    super.initState();
    _summaryFuture = TransactionRepository.instance.summary();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await DashboardPreferencesRepository.instance.load();
    if (!mounted) return;
    setState(() => _preferences = preferences);
  }

  Future<void> _reload() async {
    final future = TransactionRepository.instance.summary();
    setState(() {
      _summaryFuture = future;
    });
    await future;
  }

  /// Recarrega o resumo quando qualquer dado financeiro muda em outra tela
  /// (lançamentos, contas, parcelamentos). Sem isso, o dashboard só atualizava
  /// ao ser reaberto ou por pull-to-refresh.
  @override
  void onDataChanged() {
    // O adiamento para o próximo frame (evitando `setState` durante o build) e
    // a filtragem de telas não visíveis são feitos pelo
    // `DataChangeListenerMixin`, então aqui basta recarregar.
    _reload();
  }

  Future<void> _openCustomize() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardCustomizePage(),
      ),
    );

    if (changed == true) {
      await _loadPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Não foi possível carregar o resumo financeiro.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final income = snapshot.data?['income'] ?? 0;
        final expense = snapshot.data?['expense'] ?? 0;
        final balance = income - expense;

        final visible = _preferences.visibleOrder;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Olá, Xarleta!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Controle financeiro pessoal'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Personalizar dashboard',
                    onPressed: _openCustomize,
                    icon: const Icon(Icons.dashboard_customize_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final widget in visible) ...[
                _buildWidget(widget, income: income, expense: expense, balance: balance),
                const SizedBox(height: 12),
              ],
              if (visible.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Todos os cards estão ocultos. Use o botão de personalizar '
                      'para exibir novamente.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói o widget real correspondente à preferência.
  ///
  /// Apenas widgets que existem de fato são renderizados aqui.
  Widget _buildWidget(
    DashboardWidget widget, {
    required double income,
    required double expense,
    required double balance,
  }) {
    switch (widget) {
      case DashboardWidget.balance:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SALDO DISPONÍVEL', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Atualizado pelos seus lançamentos', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      case DashboardWidget.income:
        return _Summary(title: 'Entradas', value: income, color: AppTheme.positive);
      case DashboardWidget.expense:
        return _Summary(title: 'Saídas', value: expense, color: AppTheme.negative);
      case DashboardWidget.tip:
        return const Card(
          child: ListTile(
            leading: Icon(Icons.lightbulb_outline),
            title: Text('Dica'),
            subtitle: Text('Registre cada ganho e gasto para manter o saldo real atualizado.'),
          ),
        );
    }
  }
}

class _Summary extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  const _Summary({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title),
        const SizedBox(height: 6),
        Text(money(value), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}
