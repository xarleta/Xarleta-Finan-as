import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xarleta_financas/core/database/app_database.dart';
import 'package:xarleta_financas/features/work/work_page.dart';

/// Testes de ciclo de vida da tela de Trabalho e entregas.
///
/// Cobrem a correção do `setState` após `await Navigator.push` sem verificação
/// de `mounted`: se a tela for descartada enquanto o formulário está aberto,
/// o retorno não pode lançar exceção.
///
/// Cada arquivo de teste usa um diretório próprio para evitar contenção entre
/// os isolates executados em paralelo pelo `flutter test`.
void main() {
  late String databasePath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = join(
      Directory.systemTemp.path,
      'xarleta_test_work_lifecycle',
    );
    await databaseFactory.setDatabasesPath(dir);
    databasePath = join(dir, 'xarleta_financas.db');
    await deleteDatabase(databasePath);
    await Directory(dir).create(recursive: true);

    await AppDatabase.instance.database;
  });

  tearDownAll(() async {
    final db = await AppDatabase.instance.database;
    await db.close();
    await deleteDatabase(databasePath);
  });

  testWidgets(
    'descartar a tela de Trabalho durante o formulário não lança exceção',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WorkPage()),
      );

      // Aguarda o carregamento inicial das sessões. Usa `pump` com duração
      // fixa em vez de `pumpAndSettle` porque o indicador de progresso anima
      // continuamente enquanto o Future do SQLite não resolve.
      await tester.pump(const Duration(milliseconds: 500));

      // Abre o formulário de registro de trabalho.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Registrar trabalho'), findsOneWidget);

      // Substitui a árvore inteira, descartando a WorkPage enquanto o
      // formulário ainda está na pilha de navegação.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Nenhuma exceção deve ter sido registrada durante o descarte.
      expect(tester.takeException(), isNull);
    },
  );
}
