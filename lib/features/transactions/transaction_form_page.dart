import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import 'data/transaction_repository.dart';
import 'domain/transaction_model.dart';

class TransactionFormPage extends StatefulWidget {
  final FinanceTransaction? initial;

  const TransactionFormPage({
    super.key,
    this.initial,
  });

  @override
  State<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState
    extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;

  late TransactionType _type;
  late String _category;
  late DateTime _date;

  final incomeCategories = const [
    'Salário',
    'Uber',
    '99',
    'Entregas',
    'Motoboy',
    'Música',
    'Vendas',
    'Freelance',
    'Outros',
  ];

  final expenseCategories = const [
    'Alimentação',
    'Mercado',
    'Combustível',
    'Moradia',
    'Internet',
    'Telefone',
    'Academia',
    'Assinaturas',
    'Trabalho',
    'Lazer',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();

    final item = widget.initial;

    _amount = TextEditingController(
      text: item?.amount.toString() ?? '',
    );

    _description = TextEditingController(
      text: item?.description ?? '',
    );

    _notes = TextEditingController(
      text: item?.notes ?? '',
    );

    _type = item?.type ?? TransactionType.expense;

    _category = item?.category ??
        (_type == TransactionType.income
            ? incomeCategories.first
            : expenseCategories.first);

    _date = item?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == TransactionType.income
        ? incomeCategories
        : expenseCategories;

    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? 'Novo lançamento'
              : 'Editar lançamento',
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Gasto'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Ganho'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) {
                setState(() {
                  _type = v.first;

                  _category =
                      _type == TransactionType.income
                          ? incomeCategories.first
                          : expenseCategories.first;
                });
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _amount,
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
                      : 'Informe um valor válido',
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descrição',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty
                      ? 'Informe uma descrição'
                      : null,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
              ),
              items: categories
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _category = v;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(
                dateText(_date),
              ),
              trailing: const Icon(
                Icons.calendar_today_outlined,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  setState(() {
                    _date = picked;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _save,
              child: Text(
                widget.initial == null
                    ? 'SALVAR'
                    : 'SALVAR ALTERAÇÕES',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final item = FinanceTransaction(
      id: widget.initial?.id,
      type: _type,
      amount: parseBrazilianNumber(_amount.text),
      description: _description.text.trim(),
      category: _category,
      date: _date,
      notes: _notes.text.trim().isEmpty
          ? null
          : _notes.text.trim(),
    );

    if (widget.initial == null) {
      await TransactionRepository.instance.create(item);
    } else {
      await TransactionRepository.instance.update(item);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}