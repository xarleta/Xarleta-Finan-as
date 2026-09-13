import 'package:flutter/material.dart';
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

class _InstallmentsPageState extends State<InstallmentsPage> {
  late Future<List<Installment>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = InstallmentRepository.instance.list();
  }

  Future<void> refresh() async {
    setState(() => _itemsFuture = InstallmentRepository.instance.list());
    await _itemsFuture;
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

class _Tile extends StatelessWidget {
  final Installment item;
  final Future<void> Function() onChanged;

  const _Tile({
    required this.item,
    required this.onChanged,
  });

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
                    onPressed: () async {
                      await InstallmentRepository.instance
                          .payNext(item);

                      await onChanged();
                    },
                    child: const Text(
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
                      await onChanged();
                    }
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                ),

                IconButton(
                  onPressed: () async {
                    await InstallmentRepository.instance
                        .delete(item.id!);

                    await onChanged();
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
