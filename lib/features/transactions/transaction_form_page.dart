import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../bills/data/bill_repository.dart';
import '../bills/domain/bill_model.dart';
import '../categories/data/category_repository.dart';
import '../installments/data/installment_repository.dart';
import '../installments/domain/installment_model.dart';
import 'data/transaction_repository.dart';
import 'domain/transaction_model.dart';

/// Natureza da movimentação financeira escolhida pelo usuário.
///
/// Determina quais campos são exibidos e qual repositório é utilizado ao
/// salvar. Receita e despesa compartilham o mesmo formulário, mas apenas as
/// naturezas compatíveis com o tipo selecionado ficam disponíveis.
enum MovementNature {
  /// Receita/despesa registrada uma única vez (tabela `transactions`).
  single,

  /// Despesa ou receita que se repete (tabela `bills`).
  recurring,

  /// Despesa dividida em parcelas (tabela `installments`).
  installment,
}

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

  /// Controladores usados apenas no fluxo de despesa parcelada.
  late final TextEditingController _installmentsCount;

  late TransactionType _type;
  late MovementNature _nature;
  late String _category;
  late DateTime _date;

  /// Frequência da movimentação recorrente (semanal/mensal/anual).
  String _recurrence = 'monthly';

  /// Categorias carregadas do banco para o tipo selecionado.
  List<String> _categories = const [];

  /// Indica se as categorias ainda estão sendo carregadas.
  bool _loadingCategories = true;

  /// Erro ocorrido ao carregar as categorias (null quando não há erro).
  Object? _categoriesError;

  /// Indica se o salvamento está em andamento (evita duplo toque).
  bool _saving = false;

  /// Quando `true`, o formulário está no modo de edição de um lançamento
  /// simples existente. Nesse caso a natureza não pode ser alterada, pois
  /// mudaria o significado do registro já salvo.
  bool get _isEditingSingle => widget.initial != null;

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

    _installmentsCount = TextEditingController(text: '12');

    _type = item?.type ?? TransactionType.expense;

    _nature = MovementNature.single;

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
    _installmentsCount.dispose();

    super.dispose();
  }

  /// Naturezas disponíveis para o tipo atual.
  ///
  /// Receita permite única e recorrente; despesa permite única, recorrente e
  /// parcelada. Opções incompatíveis nunca são exibidas.
  List<MovementNature> get _availableNatures {
    if (_type == TransactionType.income) {
      return const [MovementNature.single, MovementNature.recurring];
    }
    return const [
      MovementNature.single,
      MovementNature.recurring,
      MovementNature.installment,
    ];
  }

  String _natureLabel(MovementNature nature) {
    final income = _type == TransactionType.income;
    switch (nature) {
      case MovementNature.single:
        return income ? 'Receita única' : 'Despesa única';
      case MovementNature.recurring:
        return income ? 'Receita recorrente' : 'Despesa recorrente';
      case MovementNature.installment:
        return 'Despesa parcelada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == TransactionType.income;
    final isInstallment = _nature == MovementNature.installment;
    final isRecurring = _nature == MovementNature.recurring;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingSingle
              ? 'Editar lançamento'
              : 'Nova movimentação',
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tipo: receita ou despesa.
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _isEditingSingle
                  ? null
                  : (v) {
                      setState(() {
                        _type = v.first;
                        _category = '';
                        // Ao trocar para receita, parcelamento deixa de ser
                        // válido; volta para única.
                        if (!_availableNatures.contains(_nature)) {
                          _nature = MovementNature.single;
                        }
                      });
                      _loadCategories();
                    },
            ),

            const SizedBox(height: 16),

            // Natureza da movimentação (oculta ao editar um lançamento
            // simples, pois o tipo do registro já está definido).
            if (!_isEditingSingle) ...[
              Text(
                'Natureza da movimentação',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              RadioGroup<MovementNature>(
                groupValue: _nature,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _nature = v);
                  }
                },
                child: Column(
                  children: _availableNatures
                      .map(
                        (nature) => RadioListTile<MovementNature>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: nature,
                          title: Text(_natureLabel(nature)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isInstallment ? 'Valor total' : 'Valor',
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
              decoration: InputDecoration(
                labelText: isInstallment
                    ? 'Descrição da compra'
                    : (isIncome ? 'Descrição da receita' : 'Descrição'),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty
                      ? 'Informe uma descrição'
                      : null,
            ),

            const SizedBox(height: 12),

            // Quantidade de parcelas (apenas despesa parcelada).
            if (isInstallment) ...[
              TextFormField(
                controller: _installmentsCount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de parcelas',
                ),
                validator: (v) {
                  final count = int.tryParse((v ?? '').trim()) ?? 0;
                  if (count < 2) {
                    return 'Informe ao menos 2 parcelas';
                  }
                  if (count > 360) {
                    return 'Máximo de 360 parcelas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _InstallmentPreview(
                total: parseBrazilianNumber(_amount.text),
                count: int.tryParse(_installmentsCount.text.trim()) ?? 0,
              ),
              const SizedBox(height: 12),
            ],

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

            // Frequência (apenas recorrente).
            if (isRecurring) ...[
              DropdownButtonFormField<String>(
                initialValue: _recurrence,
                decoration: const InputDecoration(
                  labelText: 'Frequência',
                ),
                items: const [
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
                    setState(() => _recurrence = v);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isRecurring
                    ? 'Primeiro vencimento'
                    : (isInstallment ? 'Primeira parcela' : 'Data'),
              ),
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditingSingle
                          ? 'SALVAR ALTERAÇÕES'
                          : 'SALVAR',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      switch (_nature) {
        case MovementNature.single:
          await _saveSingle();
        case MovementNature.recurring:
          await _saveRecurring();
        case MovementNature.installment:
          await _saveInstallment();
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveSingle() async {
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
  }

  Future<void> _saveRecurring() async {
    final bill = Bill(
      name: _description.text.trim(),
      amount: parseBrazilianNumber(_amount.text),
      dueDate: _date,
      category: _category,
      recurrence: _recurrence,
      reminderDays: 1,
      notes: _notes.text.trim().isEmpty
          ? null
          : _notes.text.trim(),
      type: _type == TransactionType.income ? 'income' : 'expense',
    );

    await BillRepository.instance.create(bill);
  }

  Future<void> _saveInstallment() async {
    final total = parseBrazilianNumber(_amount.text);
    final count = int.parse(_installmentsCount.text.trim());
    final perInstallment = total / count;

    final installment = Installment(
      name: _description.text.trim(),
      totalAmount: total,
      installmentAmount: perInstallment,
      totalInstallments: count,
      firstDueDate: _date,
      category: _category,
      notes: _notes.text.trim().isEmpty
          ? null
          : _notes.text.trim(),
    );

    await InstallmentRepository.instance.create(installment);
  }
}

/// Pré-visualização do valor de cada parcela e do total.
class _InstallmentPreview extends StatelessWidget {
  final double total;
  final int count;

  const _InstallmentPreview({
    required this.total,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0 || count < 2) {
      return const SizedBox.shrink();
    }

    final perInstallment = total / count;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valor da parcela: ${money(perInstallment)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Total: ${money(total)} em $count x'),
          ],
        ),
      ),
    );
  }
}
