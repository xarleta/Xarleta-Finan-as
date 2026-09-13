import 'package:flutter/material.dart';

import '../analytics/analytics_page_v5.dart';
import '../bills/bills_page.dart';
import '../categories/categories_page.dart';
import '../dashboard/dashboard_page.dart';
import '../goals/goals_page.dart';
import '../installments/installments_page.dart';
import '../reserves/reserves_page.dart';
import '../settings/settings_page_v6.dart';
import '../transactions/transaction_form_page.dart';
import '../transactions/transactions_page.dart';
import '../work/work_page.dart';

class AppShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const FinanceHubPage(),
      const SizedBox.shrink(),
      const AnalyticsPageV5(),
      SettingsPageV6(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    const titles = [
      'Início',
      'Finanças',
      'Adicionar',
      'Análises',
      'Configurações',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
      ),
      body: _index == 2
          ? _QuickAdd(
              onChanged: () {
                setState(() {
                  _index = 1;
                });
              },
            )
          : pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finanças',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Adicionar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Análises',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config.',
          ),
        ],
      ),
    );
  }
}

class FinanceHubPage extends StatelessWidget {
  const FinanceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({String title, IconData icon, Widget page})>[
      (
        title: 'Ganhos e gastos',
        icon: Icons.swap_vert_outlined,
        page: const TransactionsPage(),
      ),
      (
        title: 'Contas e vencimentos',
        icon: Icons.receipt_long_outlined,
        page: const BillsPage(),
      ),
      (
        title: 'Parcelamentos',
        icon: Icons.credit_card_outlined,
        page: const InstallmentsPage(),
      ),
      (
        title: 'Trabalho e entregas',
        icon: Icons.work_outline,
        page: const WorkPage(),
      ),
      (
        title: 'Metas financeiras',
        icon: Icons.flag_outlined,
        page: const GoalsPage(),
      ),
      (
        title: 'Reservas',
        icon: Icons.savings_outlined,
        page: const ReservesPage(),
      ),
      (
        title: 'Categorias',
        icon: Icons.category_outlined,
        page: const CategoriesPage(),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = items[index];

        return Card(
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => item.page,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickAdd extends StatelessWidget {
  final VoidCallback onChanged;

  const _QuickAdd({
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Adicionar rapidamente',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionFormPage(),
                    ),
                  );

                  if (saved == true) {
                    onChanged();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('NOVO GANHO OU GASTO'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkPage(),
                    ),
                  );

                  onChanged();
                },
                icon: const Icon(Icons.work_outline),
                label: const Text('REGISTRAR TRABALHO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}