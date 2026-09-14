import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/bill_model.dart';

/// Card responsivo de um item de "Contas e vencimentos".
///
/// Estrutura (BUG 4):
/// - esquerda: ícone, nome (até 2 linhas) e data/origem;
/// - direita: valor e botão de ação (PAGAR/RECEBER) + excluir.
///
/// Foi extraído de `_BillTile` para permitir testar o layout sem banco de
/// dados. O layout usa `Expanded` + `TextOverflow.ellipsis` no lado esquerdo e
/// uma coluna com `mainAxisSize.min` no lado direito, evitando o
/// `RenderFlex overflowed` que ocorria com o `ListTile` anterior (BUG 3).
class BillCard extends StatelessWidget {
  final PendingItem item;

  /// Rótulo da origem (ex.: "Mensal", "Parcelamento", "Lançamento futuro").
  final String sourceLabel;

  /// Indica se o item está vencido (data anterior a hoje).
  final bool overdue;

  /// `true` enquanto o pagamento/recebimento está em andamento.
  final bool paying;

  /// Chamado ao tocar no card (abre o formulário, quando aplicável).
  final VoidCallback? onTap;

  /// Chamado ao tocar em PAGAR/RECEBER.
  final VoidCallback? onPay;

  /// Chamado ao tocar em excluir.
  final VoidCallback? onDelete;

  const BillCard({
    super.key,
    required this.item,
    required this.sourceLabel,
    required this.overdue,
    required this.paying,
    this.onTap,
    this.onPay,
    this.onDelete,
  });

  Bill get bill => item.bill;

  @override
  Widget build(BuildContext context) {
    final isIncome = bill.isIncome;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  overdue
                      ? Icons.warning_amber_rounded
                      : (isIncome
                          ? Icons.arrow_downward
                          : Icons.receipt_long),
                  color: overdue
                      ? AppTheme.negative
                      : (isIncome ? AppTheme.positive : null),
                ),
              ),
              const SizedBox(width: 12),
              // Lado esquerdo: nome (até 2 linhas) e data/origem. Usa
              // `Expanded` + `ellipsis` para nunca estourar a largura.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateText(bill.dueDate)} • $sourceLabel'
                      '${isIncome ? ' • Receita' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Lado direito: valor e ações. `mainAxisSize.min` evita que a
              // coluna ocupe altura fixa (causa do overflow anterior).
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(bill.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppTheme.positive : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: paying ? null : onPay,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: paying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isIncome ? 'RECEBER' : 'PAGAR'),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        visualDensity: VisualDensity.compact,
                        onPressed: paying ? null : onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
