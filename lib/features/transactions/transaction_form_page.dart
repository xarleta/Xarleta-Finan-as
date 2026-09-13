import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../categories/data/category_repository.dart';
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

  /// Categorias carregadas do banco para o tipo selecionado.
  List<String> _categories = const [];

  /// Indica se as categorias ainda estão sendo carregadas.
  bool _loadingCategories = true;

  /// Erro ocorrido ao carregar as categorias (null quando não há erro).
  Object? _categoriesError;

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

    _category = item?.category ?? '';

    _date = item?.date ?? DateTime.now();

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });

    try {
      final names = await CategoryRepository.instance.namesByType(
        _type == TransactionType.income ? 'income' : 'expense',
      );

      if (!mounted) return;

      setState(() {
        _categories = names;
        _loadingCategories = false;

        // Mantém a categoria atual quando ainda existir; caso contrário,
        // seleciona a primeira disponível. Se não houver categorias, mantém
        // o valor atual (inclusive o de um lançamento antigo) para não
        // quebrar registros existentes.
        if (_categories.isNotEmpty && !_categories.contains(_category)) {
          _category = _categories.first;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingCategories = false;
        _categoriesError = e;
      });
    }
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
                  _category = '';
                });
                _loadCategories();
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

            if (_loadingCategories)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_categoriesError != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Não foi possível carregar as categorias.'),
                  trailing: TextButton(
                    onPressed: _loadCategories,
                    child: const Text('TENTAR NOVAMENTE'),
                  ),
                ),
              )
            else if (_categories.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Nenhuma categoria cadastrada.'),
                  subtitle: Text(
                    'Cadastre categorias em Categorias para selecioná-las aqui.',
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category)
                    ? _category
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                ),
                items: _categories
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