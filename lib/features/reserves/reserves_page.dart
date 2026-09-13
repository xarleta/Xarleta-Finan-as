import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';

class ReservesPage extends StatefulWidget {
  const ReservesPage({super.key});

  @override
  State<ReservesPage> createState() => _ReservesPageState();
}

class _ReservesPageState extends State<ReservesPage> {
  late Future<List<Map<String, Object?>>> _reservesFuture;

  @override
  void initState() {
    super.initState();
    _reservesFuture = load();
  }

  Future<void> _refresh() async {
    setState(() => _reservesFuture = load());
    await _reservesFuture;
  }

  Future<List<Map<String, Object?>>> load() async {
    final db = await AppDatabase.instance.database;

    return db.query(
      'reserves',
      orderBy: 'id DESC',
    );
  }

  Future<void> add() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova reserva'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                ),
              ),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor inicial',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (ok == true && nameController.text.trim().isNotEmpty) {
      final db = await AppDatabase.instance.database;

      await db.insert(
        'reserves',
        {
          'name': nameController.text.trim(),
          'current_amount': parseBrazilianNumber(
            valueController.text,
          ),
          'notes': null,
        },
      );

      await _refresh();
    }

    nameController.dispose();
    valueController.dispose();
  }

  Future<void> move(
    Map<String, Object?> reserve,
    String type,
  ) async {
    final valueController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            type == 'deposit' ? 'Adicionar dinheiro' : 'Retirar dinheiro',
          ),
          content: TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    final amount = parseBrazilianNumber(
      valueController.text,
    );

    final current = (reserve['current_amount'] as num).toDouble();

    if (ok == true && amount > 0 && (type == 'deposit' || amount <= current)) {
      final db = await AppDatabase.instance.database;

      final next = type == 'deposit' ? current + amount : current - amount;

      await db.transaction((transaction) async {
        await transaction.update(
          'reserves',
          {
            'current_amount': next,
          },
          where: 'id = ?',
          whereArgs: [
            reserve['id'],
          ],
        );

        await transaction.insert(
          'reserve_movements',
          {
            'reserve_id': reserve['id'],
            'type': type,
            'amount': amount,
            'movement_date': DateTime.now().toIso8601String(),
            'note': null,
          },
        );
      });

      await _refresh();
    }

    valueController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservas')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _reservesFuture,
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
                  const Text('Não foi possível carregar as reservas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('TENTAR NOVAMENTE'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma reserva criada.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 8,
              );
            },
            itemBuilder: (_, index) {
              final reserve = snapshot.data![index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.savings,
                    ),
                  ),
                  title: Text(
                    reserve['name'] as String,
                  ),
                  subtitle: Text(
                    money(
                      (reserve['current_amount'] as num).toDouble(),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      move(
                        reserve,
                        value,
                      );
                    },
                    itemBuilder: (_) {
                      return const [
                        PopupMenuItem(
                          value: 'deposit',
                          child: Text(
                            'Adicionar',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'withdraw',
                          child: Text(
                            'Retirar',
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: add,
        child: const Icon(
          Icons.add,
        ),
      ),
    );
  }
}
