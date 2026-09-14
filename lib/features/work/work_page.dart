import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/state/data_change_listener.dart';
import '../../core/state/data_change_notifier.dart';
import '../../core/utils/formatters.dart';

class WorkPage extends StatefulWidget {
  const WorkPage({super.key});
  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage>
    with DataChangeListenerMixin {
  late Future<List<Map<String, Object?>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _load();
  }

  Future<List<Map<String, Object?>>> _load() async {
    final db = await AppDatabase.instance.database;
    return db.query('work_sessions', orderBy: 'session_date DESC, id DESC');
  }

  @override
  void onDataChanged() {
    // Recarrega as sessões quando qualquer repositório sinaliza uma escrita.
    // O post frame evita `setState` durante o build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _sessionsFuture = _load());
    });
  }

  /// Exclui uma sessão de trabalho após confirmação do usuário.
  Future<void> _deleteSession(Map<String, Object?> session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir sessão'),
        content: Text(
          'Deseja realmente excluir "${session['activity']}"?',
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

    if (confirmed != true) return;

    final db = await AppDatabase.instance.database;
    await db.delete(
      'work_sessions',
      where: 'id = ?',
      whereArgs: [session['id']],
    );

    // Propaga a exclusão para as telas dependentes (ex.: dashboard).
    DataChangeNotifier.instance.notifyChanged();

    if (!mounted) return;
    setState(() => _sessionsFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabalho e entregas')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _sessionsFuture,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as sessões.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _sessionsFuture = _load()),
                    child: const Text('TENTAR NOVAMENTE'),
                  ),
                ],
              ),
            );
          }
          final rows = snapshot.data ?? [];
          final earnings = rows.fold<double>(
              0, (s, r) => s + ((r['earnings'] as num).toDouble()));
          final expenses = rows.fold<double>(
              0, (s, r) => s + ((r['expenses'] as num).toDouble()));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                  child: ListTile(
                      title: const Text('Ganhos'),
                      trailing: Text(money(earnings)))),
              Card(
                  child: ListTile(
                      title: const Text('Gastos'),
                      trailing: Text(money(expenses)))),
              Card(
                  child: ListTile(
                      title: const Text('Lucro líquido'),
                      trailing: Text(money(earnings - expenses),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('Nenhuma sessão registrada.'))),
              ...rows.map((r) {
                final e = (r['earnings'] as num).toDouble();
                final x = (r['expenses'] as num).toDouble();
                final h = (r['hours'] as num).toDouble();
                final km = (r['kilometers'] as num).toDouble();
                return Card(
                    child: ListTile(
                  title: Text(r['activity'] as String),
                  subtitle: Text(
                      'Lucro: ${money(e - x)} • ${h.toStringAsFixed(1)}h • ${km.toStringAsFixed(1)} km'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h > 0 ? '${money((e - x) / h)}/h' : ''),
                      IconButton(
                        tooltip: 'Excluir sessão',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteSession(r),
                      ),
                    ],
                  ),
                ));
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const WorkFormPage()));
          // A tela pode ter sido descartada enquanto o formulário estava
          // aberto; sem esta verificação o setState lançaria após o dispose.
          if (!mounted) return;
          setState(() => _sessionsFuture = _load());
        },
      ),
    );
  }
}

class WorkFormPage extends StatefulWidget {
  const WorkFormPage({super.key});
  @override
  State<WorkFormPage> createState() => _WorkFormPageState();
}

class _WorkFormPageState extends State<WorkFormPage> {
  final activity = TextEditingController(text: 'Uber');
  final earnings = TextEditingController();
  final expenses = TextEditingController();
  final hours = TextEditingController();
  final km = TextEditingController();

  @override
  void dispose() {
    activity.dispose();
    earnings.dispose();
    expenses.dispose();
    hours.dispose();
    km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Registrar trabalho')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: activity,
              decoration: const InputDecoration(labelText: 'Atividade')),
          const SizedBox(height: 12),
          TextField(
              controller: earnings,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ganhos')),
          const SizedBox(height: 12),
          TextField(
              controller: expenses,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gastos')),
          const SizedBox(height: 12),
          TextField(
              controller: hours,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Horas trabalhadas')),
          const SizedBox(height: 12),
          TextField(
              controller: km,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quilômetros')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('SALVAR SESSÃO')),
        ]),
      );

  Future<void> _save() async {
    final earningsValue = parseBrazilianNumber(earnings.text);
    final expensesValue = parseBrazilianNumber(expenses.text);

    // Uma sessão sem ganhos e sem gastos não representa nada financeiro;
    // evita registros vazios que poluem o histórico.
    if (earningsValue <= 0 && expensesValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe ao menos um valor de ganho ou gasto.',
          ),
        ),
      );
      return;
    }

    final db = await AppDatabase.instance.database;
    await db.insert('work_sessions', {
      'activity':
          activity.text.trim().isEmpty ? 'Trabalho' : activity.text.trim(),
      'session_date': DateTime.now().toIso8601String(),
      'earnings': earningsValue,
      'expenses': expensesValue,
      'hours': parseBrazilianNumber(hours.text),
      'kilometers': parseBrazilianNumber(km.text),
      'notes': null,
    });

    // Notifica as demais telas para que a nova sessão apareça imediatamente.
    DataChangeNotifier.instance.notifyChanged();

    if (mounted) Navigator.pop(context);
  }
}
