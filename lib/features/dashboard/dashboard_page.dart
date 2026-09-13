import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../transactions/data/transaction_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, double>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = TransactionRepository.instance.summary();
  }

  Future<void> _reload() async {
    final future = TransactionRepository.instance.summary();
    setState(() {
      _summaryFuture = future;
    });
    await future;
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
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Olá, Xarleta!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Controle financeiro pessoal'),
              const SizedBox(height: 20),
              Container(
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
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Summary(title: 'Entradas', value: income, color: AppTheme.positive)),
                const SizedBox(width: 12),
                Expanded(child: _Summary(title: 'Saídas', value: expense, color: AppTheme.negative)),
              ]),
              const SizedBox(height: 24),
              const Text('Controle rápido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Card(child: ListTile(
                leading: Icon(Icons.lightbulb_outline),
                title: Text('Dica'),
                subtitle: Text('Registre cada ganho e gasto para manter o saldo real atualizado.'),
              )),
            ],
          ),
        );
      },
    );
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

