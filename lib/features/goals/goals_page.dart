import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late Future<List<Map<String, Object?>>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _goalsFuture = load();
  }

  Future<void> _refresh() async {
    setState(() => _goalsFuture = load());
    await _goalsFuture;
  }

  Future<List<Map<String, Object?>>> load() async {
    final db = await AppDatabase.instance.database;

    return db.query(
      'goals',
      where: 'active=1',
      orderBy: 'deadline ASC',
    );
  }

  Future<void> addGoal() async {
    final name = TextEditingController();
    final target = TextEditingController();
    DateTime? deadline;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Nova meta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                ),
              ),
              TextField(
                controller: target,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor alvo',
                ),
              ),
              ListTile(
                title: Text(
                  deadline == null ? 'Sem prazo' : dateText(deadline!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );

                  if (d != null) {
                    set(() => deadline = d);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true &&
        name.text.trim().isNotEmpty &&
        parseBrazilianNumber(target.text) > 0) {
      final db = await AppDatabase.instance.database;

      await db.insert(
        'goals',
        {
          'name': name.text.trim(),
          'target_amount': parseBrazilianNumber(target.text),
          'current_amount': 0,
          'deadline': deadline?.toIso8601String(),
          'active': 1,
        },
      );

      await _refresh();
    }

    name.dispose();
    target.dispose();
  }

  Future<void> contribute(Map<String, Object?> g) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text('Adicionar a ${g['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    final amount = parseBrazilianNumber(controller.text);

    if (ok == true && amount > 0) {
      final db = await AppDatabase.instance.database;

      await db.transaction((t) async {
        await t.update(
          'goals',
          {
            'current_amount': (g['current_amount'] as num).toDouble() + amount,
          },
          where: 'id=?',
          whereArgs: [g['id']],
        );

        await t.insert(
          'goal_contributions',
          {
            'goal_id': g['id'],
            'amount': amount,
            'contribution_date': DateTime.now().toIso8601String(),
            'note': null,
          },
        );
      });

      await _refresh();
    }

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas financeiras')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _goalsFuture,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (s.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as metas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('TENTAR NOVAMENTE'),
                  ),
                ],
              ),
            );
          }

          if (s.data!.isEmpty) {
            return const Center(
              child: Text('Nenhuma meta cadastrada.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: s.data!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final g = s.data![i];

              final cur = (g['current_amount'] as num).toDouble();

              final tar = (g['target_amount'] as num).toDouble();

              final progress =
                  tar <= 0 ? 0.0 : (cur / tar).clamp(0.0, 1.0).toDouble();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${money(cur)} de ${money(tar)}',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => contribute(g),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Adicionar valor',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addGoal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
