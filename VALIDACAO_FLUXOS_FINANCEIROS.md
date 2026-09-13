# Validação dos Fluxos Financeiros — Xarleta Finanças

Branch: `fix/auditoria-criticos`
Data: 2026-09-13

Este documento registra a auditoria, as correções e a validação dos fluxos
financeiros do aplicativo, com foco na correção e conclusão dos formulários
financeiros (receita única, despesa única, despesa recorrente, despesa
parcelada e receita recorrente).

---

## 1. Arquitetura encontrada

O projeto usa Flutter com SQLite (sqflite) e o padrão de repositórios
singleton. As movimentações financeiras são representadas por três tabelas:

- `transactions` — lançamentos únicos (receita ou despesa) já realizados.
- `bills` — contas/recorrências com vencimento e status (pendente/paga).
- `installments` — compras parceladas com controle de parcelas pagas.

O dashboard e as análises leem **apenas** `transactions`, ou seja, somente
movimentações efetivamente realizadas.

## 2. Como a receita funcionava antes

Existia apenas receita única, gravada em `transactions` com `type = 'income'`.
Não havia nenhuma forma de cadastrar receita recorrente.

## 3. Como a despesa funcionava antes

Despesa única em `transactions` (`type = 'expense'`), despesa recorrente em
`bills` e despesa parcelada em `installments`. Porém o formulário de Nova
Transação só criava lançamentos únicos — não havia como cadastrar recorrência
ou parcelamento a partir do fluxo principal.

## 4. Como a conta recorrente funcionava antes

`bills` já suportava recorrência (`once`, `daily`, `weekly`, `monthly`,
`yearly`) via `BillRepository.markPaid`, que marca a conta como paga, cria a
transação correspondente e gera a próxima ocorrência. Só existia para despesa.

## 5. Como o parcelamento funcionava antes

`installments` já suportava parcelamento via `InstallmentRepository.payNext`,
que registra a próxima parcela, cria a transação e finaliza ao pagar a última.
Só existia para despesa.

## 6. O que foi corrigido

- O formulário de Nova Transação passou a oferecer **Tipo** (Receita/Despesa)
  e **Natureza** (única, recorrente e, para despesa, parcelada).
- Opções incompatíveis deixaram de ser exibidas (receita não mostra
  parcelamento).
- Despesa recorrente passou a ser cadastrável diretamente do fluxo principal,
  reutilizando `bills`.
- Despesa parcelada passou a ser cadastrável diretamente do fluxo principal,
  reutilizando `installments`, com pré-visualização do valor da parcela.
- Receita recorrente foi implementada (lacuna confirmada).

## 7. Como a receita recorrente foi implementada

A receita recorrente reutiliza a tabela `bills` com uma nova coluna `type`
(`'income'` ou `'expense'`). Ao marcar como recebida, `markPaid` cria uma
transação de entrada (`type = 'income'`) e gera a próxima ocorrência mantendo
o tipo. Nenhuma arquitetura de recorrência paralela foi criada.

## 8. Decisão arquitetural

Foram avaliadas três opções:

- **Opção A** — gerar transações futuras antecipadamente: rejeitada, pois
  inflaria o banco e contaria receitas ainda não realizadas.
- **Opção B** — registro recorrente separado (reutilizando `bills` com `type`):
  **escolhida**, pois reaproveita toda a lógica de recorrência, lembretes e
  pagamento já testada, sem duplicar código.
- **Opção C** — nova tabela dedicada: rejeitada por duplicar a arquitetura de
  recorrência existente.

A decisão foi a Opção B.

## 9. Banco de dados alterado ou não

Sim. A versão do schema passou de **8 para 9**, adicionando a coluna `type`
na tabela `bills`.

## 10. Migração

A migração `if (oldVersion < 9)` executa:

```sql
ALTER TABLE bills ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'
```

Registros antigos recebem `'expense'`, preservando o comportamento anterior.
A criação de banco novo já inclui a coluna com o mesmo padrão.

## 11. Backup

O `BackupService` exporta as tabelas inteiras via `db.query(table)`, portanto a
coluna `type` de `bills` é incluída automaticamente no JSON. A versão do backup
é 9.

## 12. Restauração

A restauração valida toda a estrutura antes de apagar qualquer dado e executa
em transação. Como a coluna `type` faz parte do dump, receitas recorrentes são
restauradas corretamente.

## 13. Cálculos auditados

- `TransactionRepository.summary()` soma apenas `transactions`.
- `FinanceAnalyticsRepository` (totais, categorias, evolução) lê apenas
  `transactions`.
- Contas e parcelamentos **pendentes** não entram no resumo antes do pagamento.
- Ao pagar, é criada exatamente uma transação por evento (proteção dentro de
  `db.transaction`, com releitura de estado).
- Não há soma duplicada de receita recorrente, parcela ou conta paga.

## 14. Dashboard

O dashboard usa `income - expense` sobre `transactions`, consistente com as
análises. Nenhuma alteração de cálculo foi necessária.

## 15. Análises

As análises usam o mesmo conjunto (`transactions`), garantindo consistência com
o dashboard.

## 16. Testes criados

- `test/financial_movements_test.dart` (novo): receita única, despesa única,
  despesa recorrente, despesa parcelada, receita recorrente (criação,
  persistência, não duplicação, frequência, edição, cancelamento), categorias
  por tipo, cálculos consolidados e backup/restore.
- `test/database_migration_test.dart` (atualizado): espera versão 9 e verifica
  a existência da coluna `type` em `bills`.

## 17. Resultado real do `flutter analyze`

```
No issues found! (ran in 3.0s)
```

## 18. Resultado real do `flutter test --concurrency=1`

```
00:11 +64: All tests passed!
```

(64 testes aprovados, incluindo os 15 novos de movimentação financeira e a
migração v9.)

## 19. Resultado real do `flutter build windows --debug`

```
√ Built build\windows\x64\runner\Debug\xarleta_financas.exe
```

## 20. Resultado real do `flutter build windows --release`

```
√ Built build\windows\x64\runner\Release\xarleta_financas.exe
```

## 21. Resultado real do `flutter build apk --debug`

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

## 22. Arquivos alterados

- `lib/core/database/app_database.dart`
- `lib/features/bills/domain/bill_model.dart`
- `lib/features/bills/data/bill_repository.dart`
- `lib/features/bills/bill_form_page.dart`
- `lib/features/bills/bills_page.dart`
- `lib/features/transactions/transaction_form_page.dart`
- `lib/features/shell/app_shell.dart`
- `test/database_migration_test.dart`
- `test/financial_movements_test.dart` (novo)

## 23. Commits

- `48b46ce` — `fix(database): adiciona migracao v9 com tipo em contas recorrentes`
- `8de343c` — `fix(contas): integra receita e despesa recorrente ao fluxo financeiro`
- `cb9cc60` — `fix(transacoes): completa tipos de movimentacao financeira`
- `9717250` — `test(financas): adiciona cobertura para tipos de movimentacao`

## 24. Funcionalidades pendentes

- Login Google, Firebase, sincronização em nuvem e multiusuário (fora do
  escopo desta rodada, conforme instrução).
- Redesign Liquid Glass (fora do escopo desta rodada).
- Data final opcional para recorrência (não implementada; a recorrência segue
  indefinidamente até cancelamento manual).

## 25. Riscos conhecidos

- O teste `test/work_page_lifecycle_test.dart` apresentou falha intermitente
  ("did not complete") em uma execução completa, mas passou isoladamente e na
  reexecução completa. Trata-se de flakiness de isolamento de teste
  (singleton `AppDatabase` compartilhado entre arquivos), não relacionada às
  alterações desta rodada.
- A migração usa `ALTER TABLE ... ADD COLUMN` com `DEFAULT`, operação não
  destrutiva; não há remoção de dados.
- A receita recorrente depende do usuário marcar como recebida para gerar a
  transação; receitas futuras não são contabilizadas antecipadamente (por
  decisão arquitetural).

---

## Status consolidado

| Fluxo | Status |
|-------|--------|
| Receita única | FUNCIONA |
| Despesa única | FUNCIONA |
| Despesa recorrente | FUNCIONA |
| Despesa parcelada | FUNCIONA |
| Receita recorrente | FUNCIONA |
| Migração v9 | FUNCIONA |
| Backup/restore | FUNCIONA |
| Dashboard/Análises | FUNCIONA |
| Build Windows (debug/release) | FUNCIONA |
| Build APK (debug) | FUNCIONA |
