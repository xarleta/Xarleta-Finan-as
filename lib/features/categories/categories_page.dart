import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String type = 'expense';
  late Future<List<Map<String, Object?>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = load();
  }

  Future<void> _refresh() async {
    setState(() => _categoriesFuture = load());
    await _categoriesFuture;
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

      await db.update(
        'categories',
        {
          'name': controller.text.trim(),
        },
        where: 'id=?',
        whereArgs: [row['id']],
      );

      if (mounted) {
        await _refresh();
      }
    }

    controller.dispose();
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
                      trailing: const Icon(
                        Icons.edit_outlined,
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
