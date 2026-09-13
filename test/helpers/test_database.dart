import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';

/// Utilitário compartilhado para preparar o banco de dados nos testes.
///
/// Motivação (causa raiz da instabilidade):
///
/// O `flutter test` executa cada arquivo de teste em um isolate próprio, em
/// paralelo. O `sqflite_common_ffi` inicializa a biblioteca nativa do SQLite
/// (`sqlite3.dll` no Windows) através de `sqfliteFfiInit()`, que por sua vez
/// executa `sqlite3.openInMemory().close()` para forçar o carregamento da
/// biblioteca no isolate atual. Quando vários isolates fazem isso ao mesmo
/// tempo, o carregamento nativo concorre e o isolate é encerrado abruptamente,
/// produzindo o erro:
///
///     Failed to load "...": Connection closed before test suite loaded.
///
/// Este helper centraliza a inicialização para que todos os arquivos de teste
/// usem exatamente o mesmo procedimento, evitando divergências e garantindo
/// que o handle do `AppDatabase` (singleton) seja sempre fechado e limpo ao
/// final de cada arquivo, sem vazar estado entre execuções.
///
/// Uso típico em um arquivo de teste:
///
/// ```dart
/// void main() {
///   final db = TestDatabase('nome_unico_do_arquivo');
///
///   setUpAll(db.setUpAll);
///   tearDownAll(db.tearDownAll);
///   setUp(db.clearTables);
/// }
/// ```
class TestDatabase {
  TestDatabase(this.slug);

  /// Identificador único do arquivo de teste. É usado para criar um diretório
  /// temporário exclusivo, evitando que arquivos executados em paralelo
  /// disputem o mesmo arquivo `.db`.
  final String slug;

  late final String directoryPath;
  late final String databasePath;

  /// Inicializa a fábrica FFI e abre a base usada pelo arquivo de teste.
  ///
  /// Deve ser chamado em `setUpAll`.
  ///
  /// Quando [openDatabase] é `false`, apenas a fábrica FFI e o caminho
  /// temporário são preparados, sem abrir a base. Isso é necessário para
  /// testes que precisam criar um banco legado antes que o `AppDatabase`
  /// abra o arquivo (ex.: testes de migração).
  Future<void> setUpAll({bool openDatabase = true}) async {
    sqfliteFfiInit();
    // Usa a fábrica sem isolate secundário: o `flutter test` já executa cada
    // arquivo em um isolate próprio e, em paralelo, a criação de um isolate
    // adicional por arquivo para carregar a biblioteca nativa do SQLite
    // concorre e derruba o isolate de teste ("Connection closed before test
    // suite loaded"). A variante `NoIsolate` executa as chamadas no isolate
    // atual, eliminando essa concorrência sem reduzir a cobertura dos testes.
    databaseFactory = databaseFactoryFfiNoIsolate;

    directoryPath = join(Directory.systemTemp.path, 'xarleta_test_$slug');
    await Directory(directoryPath).create(recursive: true);
    await databaseFactory.setDatabasesPath(directoryPath);

    databasePath = join(directoryPath, 'xarleta_financas.db');
    // Remove resíduos de execuções anteriores diretamente pelo sistema de
    // arquivos. O diretório é exclusivo deste arquivo de teste, então não há
    // risco de apagar dados de outro teste executado em paralelo.
    final existing = File(databasePath);
    if (await existing.exists()) {
      await existing.delete();
    }

    if (openDatabase) {
      // Abre (e mantém) a base usada por todos os testes do arquivo.
      await AppDatabase.instance.database;
    }
  }

  /// Fecha a base, limpa o singleton e remove o arquivo temporário.
  ///
  /// Deve ser chamado em `tearDownAll`.
  ///
  /// A remoção do arquivo é feita diretamente via `dart:io` em vez de
  /// `deleteDatabase`: sob paralelismo, o `deleteDatabase` do
  /// `sqflite_common_ffi` pode reabrir uma conexão interna para apagar o
  /// arquivo e, quando vários isolates fazem isso ao mesmo tempo, a chamada
  /// não retorna, deixando o `tearDownAll` pendurado ("did not complete").
  /// Como o diretório é exclusivo deste arquivo de teste, apagar o arquivo
  /// diretamente é equivalente e não bloqueia.
  Future<void> tearDownAll() async {
    await AppDatabase.instance.closeForTesting();
    final file = File(databasePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Remove todas as linhas das tabelas informadas, preservando o schema.
  ///
  /// Deve ser chamado em `setUp` para garantir que cada teste comece de um
  /// estado limpo, sem depender da ordem de execução.
  Future<void> clearTables(List<String> tables) async {
    final db = await AppDatabase.instance.database;
    for (final table in tables) {
      await db.delete(table);
    }
  }
}
