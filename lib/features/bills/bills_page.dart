import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'bill_form_page.dart';
import 'data/bill_repository.dart';
import 'domain/bill_model.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  late Future<List<Bill>> _billsFuture;
  late Future<Map<String, int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = BillRepository.instance.list();
    _countsFuture = BillRepository.instance.counts();
  }

  Future<void> _refresh() async {
    setState(() {
      _billsFuture = BillRepository.instance.list();
      _countsFuture = BillRepository.instance.counts();
    });
    await _billsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas e vencimentos'),
      ),
      body: FutureBuilder<List<Bill>>(
        future: _billsFuture,
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
                  const Text('Não foi possível carregar as contas.'),
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<Map<String, int>>(
                  future: _countsFuture,
                  builder: (_, countSnapshot) {
                    final counts = countSnapshot.data ?? {};

                    return Row(
                      children: [
                        Expanded(
                          child: _Count(
                            'Pendentes',
                            counts['pending'] ?? 0,
                            AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Count(
                            'Vencidas',
                            counts['overdue'] ?? 0,
                            AppTheme.negative,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Count(
                            'Hoje',
                            counts['today'] ?? 0,
                            AppTheme.warning,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Nenhuma conta pendente.',
                      ),
                    ),
                  ),
                ...items.map(
                  (bill) => _BillTile(
                    bill: bill,
                    onChanged: _refresh,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar conta',
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const BillFormPage(),
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

class _Count extends StatelessWidget {
  final String title;
  final int number;
  final Color color;

  const _Count(
    this.title,
    this.number,
    this.color,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '$number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillTile extends StatefulWidget {
  final Bill bill;
  final Future<void> Function() onChanged;

  const _BillTile({
    required this.bill,
    required this.onChanged,
  });

  @override
  State<_BillTile> createState() => _BillTileState();
}

class _BillTileState extends State<_BillTile> {
  bool _paying = false;

  Bill get bill => widget.bill;

  String _recurrenceText(String recurrence) {
    switch (recurrence) {
      case 'once':
        return 'Única';

      case 'daily':
        return 'Diária';

      case 'weekly':
        return 'Semanal';

      case 'monthly':
        return 'Mensal';

      case 'yearly':
        return 'Anual';

      default:
        return recurrence;
    }
  }

  Future<void> _pay() async {
    if (_paying) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Marcar como paga'),
          content: Text(
            'Confirmar o pagamento de "${bill.name}" no valor de '
            '${money(bill.amount)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _paying = true);
    try {
      final paid = await BillRepository.instance.markPaid(bill);
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paid
                  ? 'Conta marcada como paga.'
                  : 'Esta conta já estava paga.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _deleteBill(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta'),
          content: Text(
            'Deseja realmente excluir "${bill.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await BillRepository.instance.delete(bill.id!);

      await widget.onChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta excluída.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dueDate = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );

    final overdue = dueDate.isBefore(today);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            overdue ? Icons.warning_amber_rounded : Icons.receipt_long,
            color: overdue ? AppTheme.negative : null,
          ),
        ),
        title: Text(bill.name),
        subtitle: Text(
          '${dateText(bill.dueDate)} • ${_recurrenceText(bill.recurrence)}',
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              money(bill.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: _paying ? null : _pay,
              child: _paying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('PAGAR'),
            ),
          ],
        ),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => BillFormPage(
                initial: bill,
              ),
            ),
          );

          if (changed == true) {
            await widget.onChanged();
          }
        },
        onLongPress: () {
          _deleteBill(context);
        },
      ),
    );
  }
}
