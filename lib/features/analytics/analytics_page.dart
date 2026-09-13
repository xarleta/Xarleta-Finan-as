import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../transactions/data/transaction_repository.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: TransactionRepository.instance.summary(),
      builder: (_, snapshot) {
        final income = snapshot.data?['income'] ?? 0;
        final expense = snapshot.data?['expense'] ?? 0;
        final balance = income - expense;
        final total = income + expense;
        final expensePercent = total == 0 ? 0.0 : expense / total;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Resumo geral', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(child: ListTile(title: const Text('Entradas'), trailing: Text(money(income)))),
            Card(child: ListTile(title: const Text('Saídas'), trailing: Text(money(expense)))),
            Card(child: ListTile(title: const Text('Saldo'), trailing: Text(money(balance), style: const TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
            const Text('Proporção atual'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: expensePercent.clamp(0, 1)),
            const SizedBox(height: 8),
            Text('${(expensePercent * 100).toStringAsFixed(1)}% do volume financeiro registrado corresponde a gastos.'),
          ],
        );
      },
    );
  }
}

