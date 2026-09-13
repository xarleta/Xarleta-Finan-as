import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/core/analytics/date_range.dart';

void main() {
  final now = DateTime(2026, 9, 13, 15, 30);

  test('todos os periodos fixos geram intervalos validos', () {
    for (final filter in [
      PeriodFilter.today,
      PeriodFilter.week,
      PeriodFilter.month,
      PeriodFilter.year,
    ]) {
      final range = FinanceDateRange.fromFilter(filter, now: now);
      expect(range.start.isBefore(range.end), isTrue,
          reason: 'Intervalo invalido para $filter');
      expect(range.days, greaterThan(0));
    }
  });

  test('periodo personalizado exige inicio e fim', () {
    expect(
      () => FinanceDateRange.fromFilter(PeriodFilter.custom, now: now),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('periodo personalizado valido cobre o dia final', () {
    final range = FinanceDateRange.fromFilter(
      PeriodFilter.custom,
      now: now,
      customStart: DateTime(2026, 9, 1),
      customEnd: DateTime(2026, 9, 10),
    );

    expect(range.start, DateTime(2026, 9, 1));
    expect(range.end, DateTime(2026, 9, 11));
    expect(range.days, 10);
  });

  test('periodo anterior nao gera intervalo invalido', () {
    final range = FinanceDateRange.fromFilter(PeriodFilter.month, now: now);
    final previous = range.previous();

    expect(previous.start.isBefore(previous.end), isTrue);
    expect(previous.end, range.start);
  });
}
