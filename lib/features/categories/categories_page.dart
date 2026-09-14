import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/state/data_change_listener.dart';
import '../../core/state/data_change_notifier.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with DataChangeListenerMixin {
  String type = 'expense';
  late Future<List<Map<String, Object?>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = load();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _categoriesFuture = load());
    await _categoriesFuture;
  }

  @override
  void onDataChanged() {
    // Recarrega as categorias quando qualquer repositório sinaliza uma escrita.
    // O agendamento para o próximo frame e a filtragem de telas não visíveis são
    // feitos pelo `DataChangeListenerMixin`.
    _refresh();
  }

  Future<List<Map<String, Object?>>> load() async {
    final db = await AppDatabase.instance.database;

    return db.query(
      'categories',
      where: 'type=? AND active=1',
      whereArgs: [type],
      orderBy: 'name',
    );
  }

  Future<void> add() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      final db = await AppDatabase.instance.database;

      try {
        await db.insert(
          'categories',
          {
            'name': controller.text.trim(),
            'type': type,
            'active': 1,
          },
        );

        // Notifica as demais telas (formulários, dashboard) para que a nova
        // categoria apareça imediatamente, sem precisar sair e voltar.
        DataChangeNotifier.instance.notifyChanged();

        if (mounted) {
          await _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível salvar a categoria. '
                'Verifique se o nome já existe.',
              ),
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> edit(Map<String, Object?> row) async {
    final controller = TextEditingController(
      text: row['name'] as String,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar categoria'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      final db = await AppDatabase.instance.database;

      try {
        await db.update(
          'categories',
          {
            'name': controller.text.trim(),
          },
          where: 'id=?',
          whereArgs: [row['id']],
        );

        // Propaga a edição para as telas que exibem categorias.
        DataChangeNotifier.instance.notifyChanged();

        if (mounted) {
          await _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível salvar a categoria. '
                'Verifique se o nome já existe.',
              ),
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  /// Desativa a categoria (soft delete), preservando o histórico de
  /// lançamentos que já a utilizam. A coluna `active` passa a ser 0 e a
  /// categoria deixa de aparecer nas listas e nos formulários.
  Future<void> removeCategory(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover categoria'),
        content: Text(
          'Deseja remover "${row['name']}"? Os lançamentos já registrados '
          'com esta categoria serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // O showDialog acima é um gap assíncrono; garante que o State ainda
    // está montado antes de acessar o BuildContext.
    if (!mounted) return;

    // Captura o messenger antes de qualquer novo await para não usar o
    // BuildContext após um gap assíncrono.
    final messenger = ScaffoldMessenger.of(context);

    final db = await AppDatabase.instance.database;

    try {
      await db.update(
        'categories',
        {'active': 0},
        where: 'id=?',
        whereArgs: [row['id']],
      );

      // Propaga a remoção para as telas que listam categorias.
      DataChangeNotifier.instance.notifyChanged();

      if (mounted) {
        await _refresh();
        messenger.showSnackBar(
          const SnackBar(content: Text('Categoria removida.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Não foi possível remover a categoria.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Gastos'),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Ganhos'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (value) {
                setState(() {
                  type = value.first;
                  _categoriesFuture = load();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Não foi possível carregar as categorias.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('TENTAR NOVAMENTE'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rows = snapshot.data ?? [];

                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma categoria cadastrada.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];

                    return ListTile(
                      title: Text(row['name'] as String),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            edit(row);
                          } else if (value == 'remove') {
                            removeCategory(row);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remover'),
                          ),
                        ],
                      ),
                      onTap: () => edit(row),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
