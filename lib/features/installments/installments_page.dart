import 'package:flutter/material.dart';
import '../../core/state/data_change_listener.dart';
import '../../core/utils/formatters.dart';
import 'data/installment_repository.dart';
import 'domain/installment_model.dart';
import 'installment_form_page.dart';

class InstallmentsPage extends StatefulWidget {
  const InstallmentsPage({super.key});

  @override
  State<InstallmentsPage> createState() =>
      _InstallmentsPageState();
}

class _InstallmentsPageState extends State<InstallmentsPage>
    with DataChangeListenerMixin {
  late Future<List<Installment>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = InstallmentRepository.instance.list();
  }

  Future<void> refresh() async {
    // Pode ser chamado após `await Navigator.push` (ex.: retorno do formulário
    // de parcelamento). Se a tela já tiver sido descartada, o `setState`
    // lançaria; a verificação mantém o comportamento quando a tela está viva.
    if (!mounted) return;
    setState(() => _itemsFuture = InstallmentRepository.instance.list());
    await _itemsFuture;
  }

  @override
  void onDataChanged() {
    // Recarrega os parcelamentos quando qualquer repositório sinaliza uma
    // escrita. O agendamento para o próximo frame e a filtragem de telas não
    // visíveis são feitos pelo `DataChangeListenerMixin`.
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcelamentos')),
      body: FutureBuilder<List<Installment>>(
        future: _itemsFuture,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (s.hasError) {
            return _LoadError(error: s.error, onRetry: refresh);
          }

          final items = s.data!;

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum parcelamento ativo.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (_, i) {
                return _Tile(
                  item: items[i],
                  onChanged: refresh,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final x = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const InstallmentFormPage(),
            ),
          );

          if (x == true) {
            refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Não foi possível carregar os parcelamentos.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('TENTAR NOVAMENTE')),
          ]),
        ),
      );
}

class _Tile extends StatefulWidget {
  final Installment item;
  final Future<void> Function() onChanged;

  const _Tile({
    required this.item,
    required this.onChanged,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _paying = false;

  Installment get item => widget.item;

  Future<void> _payNext(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pagar próxima parcela'),
        content: Text(
          'Confirmar o pagamento da parcela '
          '${item.paidInstallments + 1}/${item.totalInstallments} de '
          '"${item.name}" no valor de ${money(item.installmentAmount)}?',
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
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _paying = true);
    try {
      final paid = await InstallmentRepository.instance.payNext(item);
      await widget.onChanged();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            paid
                ? 'Parcela registrada.'
                : 'Este parcelamento já foi finalizado.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress =
        item.totalInstallments == 0
            ? 0.0
            : (item.paidInstallments /
                    item.totalInstallments)
                .clamp(0.0, 1.0)
                .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '${item.paidInstallments}/${item.totalInstallments} pagas • Próxima: ${dateText(item.nextDueDate)}',
            ),

            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: progress,
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${money(item.installmentAmount)} por parcela',
                ),
                Text(
                  'Restam ${item.remaining}',
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _paying
                        ? null
                        : () => _payNext(context),
                    child: _paying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'PAGAR PRÓXIMA',
                          ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: () async {
                    final x =
                        await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InstallmentFormPage(
                          initial: item,
                        ),
                      ),
                    );

                    if (x == true) {
                      await widget.onChanged();
                    }
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                ),

                IconButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Excluir parcelamento'),
                        content: Text(
                          'Deseja realmente excluir "${item.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    await InstallmentRepository.instance
                        .delete(item.id!);

                    await widget.onChanged();
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
