import 'package:csv/csv.dart';
import '../core/database/app_database.dart';

class ExportService {
  ExportService._();
  static final instance = ExportService._();

  Future<String> transactionsCsv() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'transactions',
      orderBy: 'transaction_date DESC',
    );

    final data = <List<dynamic>>[
      ['ID', 'Tipo', 'Valor', 'Descrição', 'Categoria', 'Data', 'Observação'],
      ...rows.map((r) => [
        r['id'],
        r['type'],
        r['amount'],
        r['description'],
        r['category'],
        r['transaction_date'],
        r['notes'],
      ]),
    ];

    return const ListToCsvConverter().convert(data);
  }
}

