import '../../../core/database/app_database.dart';

/// Repositório de categorias.
///
/// Centraliza o acesso à tabela `categories`, garantindo que os formulários
/// utilizem as categorias cadastradas pelo usuário (respeitando o tipo
/// `income`/`expense` e apenas as ativas) em vez de listas fixas no código.
class CategoryRepository {
  CategoryRepository._();

  static final instance = CategoryRepository._();

  /// Retorna os nomes das categorias ativas do [type] informado,
  /// ordenados alfabeticamente.
  Future<List<String>> namesByType(String type) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'categories',
      columns: ['name'],
      where: 'type=? AND active=1',
      whereArgs: [type],
      orderBy: 'name',
    );

    return rows
        .map((row) => row['name'] as String)
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }
}
