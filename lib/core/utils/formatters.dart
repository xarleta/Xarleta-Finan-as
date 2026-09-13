import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _date = DateFormat('dd/MM/yyyy');

String money(num value) => _money.format(value);
String dateText(DateTime value) => _date.format(value);

double parseBrazilianNumber(String text) {
  final normalized = text
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(normalized) ?? 0;
}

