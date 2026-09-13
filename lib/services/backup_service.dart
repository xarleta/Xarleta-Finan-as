import 'dart:convert';
import '../core/database/app_database.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const tables = [
    'transactions',
    'bills',
    'installments',
    'work_sessions',
    'goals',
    'reserves',
    'categories',
    'goal_contributions',
    'reserve_movements',
    'app_settings',
  ];

  Future<String> createJson() async {
    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> data = {
      'app': 'Xarleta Finanças',
      'version': 9,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    for (final table in tables) {
      data['tables'][table] = await db.query(table);
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> restoreJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Estrutura principal inválida.');
    }
    if (decoded['app'] != 'Xarleta Finanças') {
      throw const FormatException('Este arquivo não é um backup do Xarleta Finanças.');
    }

    final tablesData = decoded['tables'];
    if (tablesData is! Map<String, dynamic>) {
      throw const FormatException('Dados das tabelas inválidos.');
    }

    // Validação completa antes de apagar qualquer dado.
    final prepared = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      if (!tablesData.containsKey(table)) {
        prepared[table] = [];
        continue;
      }
      final rows = tablesData[table];
      if (rows is! List) {
        throw FormatException('Tabela inválida: $table');
      }
      prepared[table] = rows.map<Map<String, dynamic>>((raw) {
        if (raw is! Map) throw FormatException('Registro inválido em $table');
        return Map<String, dynamic>.from(raw);
      }).toList();
    }

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final table in tables.reversed) {
        await txn.delete(table);
      }
      for (final table in tables) {
        for (final row in prepared[table]!) {
          await txn.insert(table, row);
        }
      }
    });
  }
}

