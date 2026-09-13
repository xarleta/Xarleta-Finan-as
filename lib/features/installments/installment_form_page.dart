import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import 'data/installment_repository.dart';
import 'domain/installment_model.dart';

class InstallmentFormPage extends StatefulWidget {
  final Installment? initial;

  const InstallmentFormPage({
    super.key,
    this.initial,
  });

  @override
  State<InstallmentFormPage> createState() =>
      _InstallmentFormPageState();
}

class _InstallmentFormPageState
    extends State<InstallmentFormPage> {
  final form = GlobalKey<FormState>();

  late final TextEditingController name;
  late final TextEditingController total;
  late final TextEditingController value;
  late final TextEditingController count;
  late final TextEditingController notes;

  late DateTime due;
  late String category;

  final cats = const [
    'Cartão',
    'Eletrônicos',
    'Veículo',
    'Casa',
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

    total = TextEditingController(
      text: x?.totalAmount.toString() ?? '',
    );

    value = TextEditingController(
      text: x?.installmentAmount.toString() ?? '',
    );

    count = TextEditingController(
      text: x?.totalInstallments.toString() ?? '',
    );

    notes = TextEditingController(
      text: x?.notes ?? '',
    );

    due = x?.firstDueDate ?? DateTime.now();

    category = x?.category ?? cats.first;
  }

  @override
  void dispose() {
    name.dispose();
    total.dispose();
    value.dispose();
    count.dispose();
    notes.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? 'Novo parcelamento'
              : 'Editar parcelamento',
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
                labelText: 'Nome da compra',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty
                      ? 'Informe o nome'
                      : null,
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor total',
                prefixText: 'R\$ ',
              ),
              validator: (v) =>
                  parseBrazilianNumber(v ?? '') > 0
                      ? null
                      : 'Valor inválido',
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor de cada parcela',
                prefixText: 'R\$ ',
              ),
              validator: (v) =>
                  parseBrazilianNumber(v ?? '') > 0
                      ? null
                      : 'Valor inválido',
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade de parcelas',
              ),
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) > 0
                      ? null
                      : 'Quantidade inválida',
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
              ),
              items: cats
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
                'Primeiro vencimento',
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
                    ? 'SALVAR PARCELAMENTO'
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

    final item = Installment(
      id: widget.initial?.id,
      name: name.text.trim(),
      totalAmount: parseBrazilianNumber(
        total.text,
      ),
      installmentAmount: parseBrazilianNumber(
        value.text,
      ),
      totalInstallments: int.parse(
        count.text,
      ),
      paidInstallments:
          widget.initial?.paidInstallments ?? 0,
      firstDueDate: due,
      category: category,
      status: widget.initial?.status ?? 'active',
      notes: notes.text.trim().isEmpty
          ? null
          : notes.text.trim(),
    );

    if (widget.initial == null) {
      await InstallmentRepository.instance
          .create(item);
    } else {
      await InstallmentRepository.instance
          .update(item);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}