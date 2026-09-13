import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import 'data/bill_repository.dart';
import 'domain/bill_model.dart';

class BillFormPage extends StatefulWidget {
  final Bill? initial;

  const BillFormPage({
    super.key,
    this.initial,
  });

  @override
  State<BillFormPage> createState() => _BillFormPageState();
}

class _BillFormPageState extends State<BillFormPage> {
  final form = GlobalKey<FormState>();

  late final TextEditingController name;
  late final TextEditingController amount;
  late final TextEditingController notes;

  late DateTime due;
  late String category;
  late String recurrence;
  late int reminder;

  final categories = const [
    'Moradia',
    'Internet',
    'Telefone',
    'Energia',
    'Água',
    'Academia',
    'Assinaturas',
    'Cartão',
    'Trabalho',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();

    final x = widget.initial;

    name = TextEditingController(
      text: x?.name ?? '',
    );

    amount = TextEditingController(
      text: x?.amount.toString() ?? '',
    );

    notes = TextEditingController(
      text: x?.notes ?? '',
    );

    due = x?.dueDate ?? DateTime.now();

    category = x?.category ?? categories.first;

    recurrence = x?.recurrence ?? 'once';

    reminder = x?.reminderDays ?? 1;
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    notes.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? 'Nova conta'
              : 'Editar conta',
        ),
      ),

      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nome da conta',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty
                      ? 'Informe o nome'
                      : null,
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
              ),
              validator: (v) =>
                  parseBrazilianNumber(v ?? '') > 0
                      ? null
                      : 'Valor inválido',
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
              ),
              items: categories
                  .map(
                    (x) => DropdownMenuItem(
                      value: x,
                      child: Text(x),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    category = v;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vencimento',
              ),
              subtitle: Text(
                dateText(due),
              ),
              trailing: const Icon(
                Icons.calendar_today_outlined,
              ),
              onTap: () async {
                final x = await showDatePicker(
                  context: context,
                  initialDate: due,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (x != null) {
                  setState(() {
                    due = x;
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: recurrence,
              decoration: const InputDecoration(
                labelText: 'Repetição',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'once',
                  child: Text('Não repetir'),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text('Semanal'),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text('Mensal'),
                ),
                DropdownMenuItem(
                  value: 'yearly',
                  child: Text('Anual'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    recurrence = v;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              initialValue: reminder,
              decoration: const InputDecoration(
                labelText: 'Lembrar antes',
              ),
              items: const [0, 1, 2, 3, 7]
                  .map(
                    (x) => DropdownMenuItem(
                      value: x,
                      child: Text(
                        x == 0
                            ? 'No dia do vencimento'
                            : '$x dia(s) antes',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    reminder = v;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: save,
              child: Text(
                widget.initial == null
                    ? 'SALVAR CONTA'
                    : 'SALVAR ALTERAÇÕES',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;

    final item = Bill(
      id: widget.initial?.id,
      name: name.text.trim(),
      amount: parseBrazilianNumber(
        amount.text,
      ),
      dueDate: due,
      category: category,
      recurrence: recurrence,
      reminderDays: reminder,
      status: widget.initial?.status ?? 'pending',
      notes: notes.text.trim().isEmpty
          ? null
          : notes.text.trim(),
    );

    if (widget.initial == null) {
      await BillRepository.instance.create(item);
    } else {
      await BillRepository.instance.update(item);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}