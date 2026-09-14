import 'package:flutter/material.dart';

import '../../core/state/data_change_listener.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'bill_form_page.dart';
import 'data/bill_repository.dart';
import 'domain/bill_model.dart';
import 'widgets/bill_card.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage>
    with DataChangeListenerMixin {
  late Future<List<PendingItem>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = BillRepository.instance.listPending();
  }

  Future<void> _refresh() async {
    // Pode ser chamado após `await Navigator.push` (ex.: retorno do formulário
    // de conta). Se a tela já tiver sido descartada, o `setState` lançaria; a
    // verificação mantém o comportamento quando a tela está viva.
    if (!mounted) return;
    setState(() {
      _billsFuture = BillRepository.instance.listPending();
    });
    await _billsFuture;
  }

  @override
  void onDataChanged() {
    // Recarrega contas e contadores quando qualquer repositório sinaliza uma
    // escrita (ex.: lançamento pago em outra tela). O post frame evita
    // `setState` durante o build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas e vencimentos'),
      ),
      body: FutureBuilder<List<PendingItem>>(
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
                // Os contadores são derivados da lista já carregada acima.
                // Antes havia um segundo FutureBuilder que refazia a mesma
                // consulta de pendentes no banco (BUG 5 - consulta duplicada).
                Builder(
                  builder: (_) {
                    final counts =
                        BillRepository.instance.countsFromItems(items);

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
                  (item) => _BillTile(
                    // A chave por origem+id garante que o Flutter associe o
                    // estado correto a cada item após o recarregamento. Sem
                    // ela, o estado (ex.: `_paying`) podia ser reaproveitado
                    // pela posição, dando a impressão de que o PAGAR/RECEBER
                    // não teve efeito.
                    key: ValueKey('${item.source.name}-${item.sourceId}'),
                    item: item,
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
  final PendingItem item;
  final Future<void> Function() onChanged;

  const _BillTile({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<_BillTile> createState() => _BillTileState();
}

class _BillTileState extends State<_BillTile> {
  bool _paying = false;

  PendingItem get item => widget.item;
  Bill get bill => widget.item.bill;

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

  /// Rótulo da origem do item, exibido no subtítulo para deixar claro de onde
  /// ele vem (conta recorrente, parcelamento ou lançamento futuro).
  String get _sourceLabel {
    switch (item.source) {
      case BillSource.bill:
        return _recurrenceText(bill.recurrence);
      case BillSource.installment:
        return 'Parcelamento';
      case BillSource.transaction:
        return 'Lançamento futuro';
    }
  }

  Future<void> _pay() async {
    if (_paying) return;

    final isIncome = bill.isIncome;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isIncome ? 'Marcar como recebida' : 'Marcar como paga'),
          content: Text(
            isIncome
                ? 'Confirmar o recebimento de "${bill.name}" no valor de '
                    '${money(bill.amount)}?'
                : 'Confirmar o pagamento de "${bill.name}" no valor de '
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
      final paid = await BillRepository.instance.markPendingPaid(item);
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paid
                  ? (isIncome
                      ? 'Receita marcada como recebida.'
                      : 'Conta marcada como paga.')
                  : (isIncome
                      ? 'Esta receita já havia sido recebida.'
                      : 'Esta conta já estava paga.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final isIncome = bill.isIncome;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isIncome ? 'Excluir receita' : 'Excluir conta',
          ),
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
      await BillRepository.instance.deletePending(item);

      await widget.onChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIncome ? 'Receita excluída.' : 'Conta excluída.',
            ),
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

    return BillCard(
      item: item,
      sourceLabel: _sourceLabel,
      overdue: overdue,
      paying: _paying,
      onPay: _pay,
      onDelete: () => _delete(context),
      onTap: () async {
        // Apenas contas recorrentes possuem formulário próprio. Itens de
        // parcelamento e lançamentos futuros são gerenciados nas suas telas
        // de origem (Parcelamentos e Ganhos e gastos).
        if (item.source != BillSource.bill) return;

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
    );
  }
}
