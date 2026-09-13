enum PeriodFilter { today, week, month, year, custom }

class FinanceDateRange {
  final DateTime start;
  final DateTime end;
  final PeriodFilter filter;

  const FinanceDateRange({
    required this.start,
    required this.end,
    required this.filter,
  });

  factory FinanceDateRange.fromFilter(
    PeriodFilter filter, {
    DateTime? now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final date = now ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);

    switch (filter) {
      case PeriodFilter.today:
        return FinanceDateRange(
          start: day,
          end: day.add(const Duration(days: 1)),
          filter: filter,
        );
      case PeriodFilter.week:
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return FinanceDateRange(
          start: monday,
          end: monday.add(const Duration(days: 7)),
          filter: filter,
        );
      case PeriodFilter.month:
        return FinanceDateRange(
          start: DateTime(day.year, day.month),
          end: DateTime(day.year, day.month + 1),
          filter: filter,
        );
      case PeriodFilter.year:
        return FinanceDateRange(
          start: DateTime(day.year),
          end: DateTime(day.year + 1),
          filter: filter,
        );
      case PeriodFilter.custom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError('Período personalizado exige início e fim.');
        }
        return FinanceDateRange(
          start: DateTime(customStart.year, customStart.month, customStart.day),
          end: DateTime(
            customEnd.year,
            customEnd.month,
            customEnd.day,
          ).add(const Duration(days: 1)),
          filter: filter,
        );
    }
  }

  int get days => end.difference(start).inDays;

  FinanceDateRange previous() {
    final duration = end.difference(start);
    return FinanceDateRange(
      start: start.subtract(duration),
      end: start,
      filter: filter,
    );
  }
}

