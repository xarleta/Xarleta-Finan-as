import 'package:flutter/material.dart';
import '../../../core/analytics/date_range.dart';

class PeriodSelector extends StatelessWidget {
  final PeriodFilter selected;
  final ValueChanged<PeriodFilter> onChanged;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PeriodFilter>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Período',
      ),
      items: const [
        DropdownMenuItem(
          value: PeriodFilter.today,
          child: Text('Hoje'),
        ),
        DropdownMenuItem(
          value: PeriodFilter.week,
          child: Text('Semana'),
        ),
        DropdownMenuItem(
          value: PeriodFilter.month,
          child: Text('Mês'),
        ),
        DropdownMenuItem(
          value: PeriodFilter.year,
          child: Text('Ano'),
        ),
        DropdownMenuItem(
          value: PeriodFilter.custom,
          child: Text('Personalizado'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
