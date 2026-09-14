import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/features/bills/data/bill_repository.dart';
import 'package:xarleta_financas/features/bills/domain/bill_model.dart';
import 'package:xarleta_financas/features/bills/widgets/bill_card.dart';

/// Testes de layout do card de "Contas e vencimentos" (BUG 3 / BUG 4).
///
/// O bug original era um `RenderFlex overflowed by 8.0 pixels` na base do
/// card. A causa era o uso de `ListTile` com `subtitle` de duas linhas e um
/// `trailing` em `Column` (valor + linha de botões), que ultrapassava a altura
/// fixa do `ListTile`.
///
/// A correção substitui o `ListTile` por um `Row` responsivo com `Expanded` no
/// lado esquerdo (nome/valor com `ellipsis`) e uma coluna de ações compacta no
/// lado direito. Estes testes garantem que o card não estoura em telas
/// estreitas (Android pequeno) nem em telas largas.
///
/// O `BillCard` é testado diretamente (sem banco de dados), o que torna o
/// teste rápido e determinístico. O `flutter_test` reporta
/// `RenderFlex overflowed` como exceção capturada pelo binding;
/// `tester.takeException()` a expõe.
void main() {
  PendingItem buildItem({
    String name = 'Aluguel apartamento',
    double amount = 3500.0,
    String type = 'expense',
  }) {
    return PendingItem(
      bill: Bill(
        id: 1,
        name: name,
        amount: amount,
        dueDate: DateTime(2026, 9, 28),
        category: 'Moradia',
        recurrence: 'monthly',
        type: type,
      ),
      source: BillSource.bill,
      sourceId: 1,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size size,
    required PendingItem item,
    bool overdue = false,
    bool paying = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillCard(
            item: item,
            sourceLabel: 'Mensal',
            overdue: overdue,
            paying: paying,
            onPay: () {},
            onDelete: () {},
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('card não estoura em tela estreita (Android pequeno)',
      (tester) async {
    await pumpCard(
      tester,
      size: const Size(320, 640),
      item: buildItem(
        name: 'Aluguel apartamento com nome bem longo para forçar quebra',
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'não deve haver overflow em tela estreita');
    expect(find.textContaining('Aluguel apartamento'), findsOneWidget);
  });

  testWidgets('card não estoura em tela média', (tester) async {
    await pumpCard(
      tester,
      size: const Size(411, 891),
      item: buildItem(
        name: 'Aluguel apartamento com nome bem longo para forçar quebra',
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'não deve haver overflow em tela média');
  });

  testWidgets('card não estoura em tela larga', (tester) async {
    await pumpCard(
      tester,
      size: const Size(600, 900),
      item: buildItem(
        name: 'Aluguel apartamento com nome bem longo para forçar quebra',
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'não deve haver overflow em tela larga');
  });

  testWidgets('card não estoura quando vencido', (tester) async {
    await pumpCard(
      tester,
      size: const Size(320, 640),
      item: buildItem(
        name: 'Aluguel apartamento com nome bem longo para forçar quebra',
      ),
      overdue: true,
    );

    expect(tester.takeException(), isNull,
        reason: 'não deve haver overflow quando vencido');
  });

  testWidgets('card não estoura quando é receita', (tester) async {
    await pumpCard(
      tester,
      size: const Size(320, 640),
      item: buildItem(
        name: 'Freelance com nome bem longo para forçar quebra de linha',
        type: 'income',
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'não deve haver overflow quando é receita');
  });

  testWidgets('ações PAGAR e excluir continuam visíveis', (tester) async {
    await pumpCard(
      tester,
      size: const Size(320, 640),
      item: buildItem(),
    );

    expect(find.text('PAGAR'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('receita mostra RECEBER', (tester) async {
    await pumpCard(
      tester,
      size: const Size(320, 640),
      item: buildItem(type: 'income'),
    );

    expect(find.text('RECEBER'), findsOneWidget);
  });

  // BUG 5: os contadores eram obtidos por uma segunda consulta idêntica ao
  // banco (`pendingCounts` chamava `listPending` de novo). Agora a tela deriva
  // os contadores da lista já carregada via `countsFromItems`, que é uma
  // função pura e pode ser testada sem banco de dados.
  group('countsFromItems (contadores sem consulta duplicada)', () {
    PendingItem itemDue(DateTime due) => PendingItem(
          bill: Bill(
            id: 1,
            name: 'Conta',
            amount: 100,
            dueDate: due,
            category: 'Geral',
            recurrence: 'once',
          ),
          source: BillSource.bill,
          sourceId: 1,
        );

    test('conta pendentes, vencidas e de hoje', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final counts = BillRepository.instance.countsFromItems([
        itemDue(yesterday),
        itemDue(today),
        itemDue(tomorrow),
      ]);

      expect(counts['pending'], 3);
      expect(counts['overdue'], 1);
      expect(counts['today'], 1);
    });

    test('lista vazia retorna zeros', () {
      final counts = BillRepository.instance.countsFromItems([]);

      expect(counts['pending'], 0);
      expect(counts['overdue'], 0);
      expect(counts['today'], 0);
    });
  });
}
