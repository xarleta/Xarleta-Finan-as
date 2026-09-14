import 'package:flutter/material.dart';

import '../../core/state/data_change_listener.dart';
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

class _TransactionsPageState extends State<TransactionsPage>
    with DataChangeListenerMixin {
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
    // Pode ser chamado após `await Navigator.push` ou após a exclusão de um
    // lançamento. Se a tela já tiver sido descartada, o `setState` lançaria;
    // a verificação mantém o comportamento quando a tela está viva.
    if (!mounted) return;
    setState(() => _transactionsFuture = _load());
    await _transactionsFuture;
  }

  @override
  void onDataChanged() {
    // Recarrega quando qualquer repositório sinaliza uma escrita (inclusive
    // lançamentos criados/editados em outras telas). O agendamento para o
    // próximo frame e a filtragem de telas não visíveis são feitos pelo
    // `DataChangeListenerMixin`, então aqui basta recarregar.
    _refresh();
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

class _TransactionTile extends StatefulWidget {
  final FinanceTransaction item;
  final Future<void> Function() onChanged;

  const _TransactionTile({
    required this.item,
    required this.onChanged,
  });

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {
  bool _deleting = false;

  FinanceTransaction get item => widget.item;

  /// Confirma e executa a exclusão do lançamento.
  ///
  /// A exclusão é um `DELETE` real na tabela `transactions` (ver
  /// [TransactionRepository.delete]); após confirmar, a lista é recarregada
  /// via [onChanged] para refletir a remoção imediatamente.
  Future<void> _delete() async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text(
          'Deseja realmente excluir "${item.description}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await TransactionRepository.instance.delete(item.id!);
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento excluído'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${income ? '+' : '-'} ${money(item.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            IconButton(
              tooltip: 'Excluir',
              onPressed: _deleting ? null : _delete,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          ],
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
            await widget.onChanged();
          }
        },
        onLongPress: _deleting ? null : _delete,
      ),
    );
  }
}
