import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'data/transaction_repository.dart';
import 'domain/transaction_model.dart';
import 'transaction_form_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _query = '';
  TransactionType? _filter;
  late Future<List<FinanceTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _load();
  }

  Future<List<FinanceTransaction>> _load() =>
      TransactionRepository.instance.list(
        query: _query,
        type: _filter,
      );

  Future<void> _refresh() async {
    setState(() => _transactionsFuture = _load());
    await _transactionsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganhos e gastos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar lançamento',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                  _transactionsFuture = _load();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TransactionType?>(
              segments: const [
                ButtonSegment(
                  value: null,
                  label: Text('Todos'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Ganhos'),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Gastos'),
                ),
              ],
              selected: {_filter},
              emptySelectionAllowed: true,
              multiSelectionEnabled: false,
              onSelectionChanged: (value) {
                setState(() {
                  _filter = value.isEmpty ? null : value.first;
                  _transactionsFuture = _load();
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<FinanceTransaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Não foi possível carregar os lançamentos.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('TENTAR NOVAMENTE'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!;

                if (items.isEmpty) {
                  return const Center(
                    child: Text('Nenhum lançamento encontrado.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      return _TransactionTile(
                        item: items[index],
                        onChanged: _refresh,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar lançamento',
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const TransactionFormPage(),
            ),
          );

          if (changed == true) {
            await _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final FinanceTransaction item;
  final Future<void> Function() onChanged;

  const _TransactionTile({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final income = item.type == TransactionType.income;
    final color = income ? AppTheme.positive : AppTheme.negative;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            income ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(item.description),
        subtitle: Text(
          '${item.category} • ${dateText(item.date)}',
        ),
        trailing: Text(
          '${income ? '+' : '-'} ${money(item.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionFormPage(
                initial: item,
              ),
            ),
          );

          if (changed == true) {
            await onChanged();
          }
        },
        onLongPress: () async {
          await TransactionRepository.instance.delete(item.id!);

          await onChanged();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lançamento excluído'),
              ),
            );
          }
        },
      ),
    );
  }
}
