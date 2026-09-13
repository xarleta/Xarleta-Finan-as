import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/features/work/work_page.dart';

import 'helpers/test_database.dart';

/// Testes de ciclo de vida da tela de Trabalho e entregas.
///
/// Cobrem a correção do `setState` após `await Navigator.push` sem verificação
/// de `mounted`: se a tela for descartada enquanto o formulário está aberto,
/// o retorno não pode lançar exceção.
///
/// O banco é preparado pelo helper compartilhado [TestDatabase], que usa um
/// diretório temporário exclusivo por arquivo e limpa o singleton ao final,
/// evitando vazamento de estado entre os isolates paralelos do `flutter test`.
void main() {
  final db = TestDatabase('work_lifecycle');

  setUpAll(db.setUpAll);
  tearDownAll(db.tearDownAll);

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
