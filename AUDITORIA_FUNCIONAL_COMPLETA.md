# Auditoria Funcional Completa — Xarleta Finanças

Data da auditoria: 2026-09-13
Escopo: interface, navegação, botões, rotas, persistência e serviços.
Método: leitura estática de todo o código em `lib/`, confronto com a documentação
(`README.md`, `PROJECT_ARCHITECTURE.md`, `DEVELOPMENT_STATUS.md`) e execução de
`flutter analyze`, `flutter test` e `flutter build windows`.

> Esta auditoria **não alterou nenhum código de funcionalidade**. Apenas o
> presente relatório foi criado.

---

## 1. Resultado das validações executadas

| Comando | Resultado | Observação |
| --- | --- | --- |
| `flutter analyze` | **OK** — `No issues found!` | Nenhum aviso ou erro estático. |
| `flutter test` | **OK** — `All tests passed!` (2 testes) | `database_migration_test.dart` (migração v2→v8) e `widget_test.dart` (teste trivial `1+1`). |
| `flutter build windows` | **OK** — `Built build\windows\x64\runner\Release\xarleta_financas.exe` | A primeira tentativa falhou por cache efêmero corrompido (`windows/flutter/ephemeral/cpp_client_wrapper/*.cc` ausentes). Após `flutter clean && flutter pub get`, o build foi concluído com sucesso. Não é um defeito de código. |

---

## 2. Mapa de navegação e telas

### Barra inferior (`AppShell`)

| Índice | Rótulo | Tela | Arquivo |
| --- | --- | --- | --- |
| 0 | Início | `DashboardPage` | [`dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart:6) |
| 1 | Finanças | `FinanceHubPage` | [`app_shell.dart`](lib/features/shell/app_shell.dart:105) |
| 2 | Adicionar | `_QuickAdd` | [`app_shell.dart`](lib/features/shell/app_shell.dart:175) |
| 3 | Análises | `AnalyticsPageV5` | [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:10) |
| 4 | Config. | `SettingsPageV6` | [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:8) |

### Hub de Finanças (`FinanceHubPage`) — rotas via `Navigator.push`

| Item | Tela destino | Arquivo |
| --- | --- | --- |
| Ganhos e gastos | `TransactionsPage` | [`transactions_page.dart`](lib/features/transactions/transactions_page.dart:9) |
| Contas e vencimentos | `BillsPage` | [`bills_page.dart`](lib/features/bills/bills_page.dart:9) |
| Parcelamentos | `InstallmentsPage` | [`installments_page.dart`](lib/features/installments/installments_page.dart:7) |
| Trabalho e entregas | `WorkPage` | [`work_page.dart`](lib/features/work/work_page.dart:5) |
| Metas financeiras | `GoalsPage` | [`goals_page.dart`](lib/features/goals/goals_page.dart:5) |
| Reservas | `ReservesPage` | [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:6) |
| Categorias | `CategoriesPage` | [`categories_page.dart`](lib/features/categories/categories_page.dart:4) |

### Configurações (`SettingsPageV6`)

| Item | Destino / Ação | Arquivo |
| --- | --- | --- |
| Aparência | Bottom sheet de tema (Sistema/Claro/Escuro) | [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:136) |
| Lembretes e notificações | `NotificationSettingsPage` | [`notification_settings_page.dart`](lib/features/settings/notification_settings_page.dart:4) |
| Segurança e biometria | `SecuritySettingsPage` | [`security_settings_page.dart`](lib/features/settings/security_settings_page.dart:5) |
| Dados, backup e exportação | `DataManagementPage` | [`data_management_page.dart`](lib/features/settings/data_management_page.dart:7) |
| Inicializar notificações | `NotificationService.initialize()` | [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:97) |
| Personalizar dashboard | **Sem ação** | [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:113) |
| Editar categorias | `CategoriesPage` | [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:120) |

---

## 3. Auditoria por funcionalidade

### 3.1 Dashboard

- **Arquivo responsável:** [`dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart:12)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. O `FutureBuilder` usa `future: TransactionRepository.instance.summary()` criado
     **dentro do `build`** ([linha 16](lib/features/dashboard/dashboard_page.dart:16)).
     Cada reconstrução dispara uma nova consulta ao banco. O `RefreshIndicator`
     apenas chama `setState(() {})`, o que recria o future — funciona, mas é
     ineficiente e pode gerar consultas repetidas.
  2. Não há tratamento de `snapshot.hasError` nem estado de carregamento
     explícito: em caso de falha do banco, os valores caem para `0` silenciosamente
     ([linhas 18-19](lib/features/dashboard/dashboard_page.dart:18)), exibindo saldo
     incorreto sem aviso.
  3. O saldo é **global** (todas as transações), enquanto a tela de Análises usa
     saldo **por período**. Não há indicador de que o dashboard ignora o período.
- **Impacto:** Usuário pode ver saldo zerado/incorreto sem entender o motivo;
  consultas redundantes ao banco.
- **Correção necessária:** Guardar o future em `initState`, adicionar tratamento
  de erro e recarregar via `setState` controlado.
- **Prioridade:** MÉDIA

### 3.2 Ganhos e gastos (Transações)

- **Arquivo responsável:** [`transactions_page.dart`](lib/features/transactions/transactions_page.dart:16),
  [`transaction_form_page.dart`](lib/features/transactions/transaction_form_page.dart:19),
  [`transaction_repository.dart`](lib/features/transactions/data/transaction_repository.dart:4)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. A exclusão ocorre por `onLongPress` **sem diálogo de confirmação**
     ([linha 210](lib/features/transactions/transactions_page.dart:210)), diferente
     de Contas, que confirma antes de excluir. Risco de exclusão acidental.
  2. O formulário usa listas de categorias **hardcoded**
     ([linhas 31-55](lib/features/transactions/transaction_form_page.dart:31)) em vez
     de consultar a tabela `categories`. Categorias criadas em "Categorias" não
     aparecem no formulário de lançamento.
  3. `update()` remove `created_at` do mapa
     ([linha 43](lib/features/transactions/data/transaction_repository.dart:43)),
     mas `toMap()` sempre gera novo `updated_at` — comportamento correto, porém
     `created_at` original é preservado apenas porque é removido do UPDATE.
- **Impacto:** Exclusão acidental; inconsistência entre categorias cadastradas e
  categorias disponíveis no lançamento.
- **Correção necessária:** Adicionar confirmação de exclusão; carregar categorias
  da tabela `categories` filtrando por `type` e `active=1`.
- **Prioridade:** ALTA (integração de categorias) / MÉDIA (confirmação)

### 3.3 Contas e vencimentos

- **Arquivo responsável:** [`bills_page.dart`](lib/features/bills/bills_page.dart:16),
  [`bill_form_page.dart`](lib/features/bills/bill_form_page.dart:18),
  [`bill_repository.dart`](lib/features/bills/data/bill_repository.dart:5)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. `markPaid` insere uma transação de despesa e, se recorrente, cria a próxima
     conta — tudo em transação de banco
     ([linhas 46-80](lib/features/bills/data/bill_repository.dart:46)). Correto.
  2. O botão "PAGAR" **não pede confirmação** e não é desabilitado durante a
     operação ([linha 294](lib/features/bills/bills_page.dart:294)); toques
     repetidos podem gerar pagamentos duplicados antes do `refresh`.
  3. `counts()` chama `list()` novamente
     ([linha 114](lib/features/bills/data/bill_repository.dart:114)), gerando uma
     segunda consulta ao banco em paralelo ao `FutureBuilder` principal da tela.
  4. Categorias do formulário também são **hardcoded**
     ([linhas 30-41](lib/features/bills/bill_form_page.dart:30)).
- **Impacto:** Possível duplicidade de pagamento por toque repetido; consultas
  redundantes; categorias divergentes das cadastradas.
- **Correção necessária:** Desabilitar botão durante operação e/ou confirmar;
  reutilizar a lista já carregada para os contadores.
- **Prioridade:** ALTA (duplicidade de pagamento)

### 3.4 Parcelamentos

- **Arquivo responsável:** [`installments_page.dart`](lib/features/installments/installments_page.dart:15),
  [`installment_form_page.dart`](lib/features/installments/installment_form_page.dart:19),
  [`installment_repository.dart`](lib/features/installments/data/installment_repository.dart:4)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. O botão de **excluir** ([linha 215](lib/features/installments/installments_page.dart:215))
     não possui confirmação nem feedback, diferente do padrão de Contas.
  2. `payNext` valida `status != 'active'` e usa transação
     ([linha 30](lib/features/installments/data/installment_repository.dart:30)).
     Correto, mas o botão "PAGAR PRÓXIMA" não é desabilitado durante a operação.
  3. `nextDueDate` calcula `DateTime(ano, mês + paidInstallments, dia)`
     ([linha 32](lib/features/installments/domain/installment_model.dart:32)).
     Para dias 29-31 em meses curtos, o Dart normaliza a data (ex.: 31/01 + 1 mês
     → 02/03), podendo exibir vencimento impreciso.
  4. Categorias hardcoded ([linhas 32-39](lib/features/installments/installment_form_page.dart:32)).
- **Impacto:** Exclusão acidental; data de próxima parcela potencialmente
  incorreta em meses curtos.
- **Correção necessária:** Confirmação de exclusão; tratamento de datas no fim do
  mês; integração com tabela de categorias.
- **Prioridade:** MÉDIA

### 3.5 Trabalho e entregas

- **Arquivo responsável:** [`work_page.dart`](lib/features/work/work_page.dart:11)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. A tela **não permite editar nem excluir** sessões registradas. Só há criação
     ([linha 95](lib/features/work/work_page.dart:95)) e listagem.
  2. O formulário `WorkFormPage` usa `TextField` comuns, **sem validação** e sem
     `Form`/`GlobalKey` ([linhas 133-160](lib/features/work/work_page.dart:133)).
     Valores inválidos viram `0` silenciosamente via `parseBrazilianNumber`.
  3. Não há campo de data: a sessão sempre usa `DateTime.now()`
     ([linha 168](lib/features/work/work_page.dart:168)).
  4. Não há estado de lista vazia com ação, nem `RefreshIndicator`.
  5. Não há tratamento de erro de escrita (`_save` sem try/catch).
- **Impacto:** Funcionalidade incompleta — usuário não corrige lançamentos
  errados; dados inconsistentes sem validação.
- **Correção necessária:** Adicionar edição/exclusão, validação de formulário,
  seleção de data e tratamento de erro.
- **Prioridade:** ALTA

### 3.6 Metas financeiras

- **Arquivo responsável:** [`goals_page.dart`](lib/features/goals/goals_page.dart:12)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. **Não há edição nem exclusão** de metas. Apenas criação
     ([linha 36](lib/features/goals/goals_page.dart:36)) e contribuição
     ([linha 119](lib/features/goals/goals_page.dart:119)).
  2. A tabela `goals` possui coluna `active`, e a consulta filtra `active=1`
     ([linha 31](lib/features/goals/goals_page.dart:31)), mas **nada no app define
     `active=0`** — não há como arquivar/concluir uma meta.
  3. O diálogo de nova meta não valida antes de fechar; se inválido, fecha
     silenciosamente sem salvar ([linhas 96-98](lib/features/goals/goals_page.dart:96)).
  4. `goal_contributions` é gravada corretamente em transação
     ([linha 151](lib/features/goals/goals_page.dart:151)), mas **não há tela de
     histórico** de aportes.
  5. Não há `RefreshIndicator` na lista.
- **Impacto:** Metas não podem ser corrigidas ou removidas; histórico de aportes
  inacessível apesar de persistido.
- **Correção necessária:** Edição/exclusão de metas, feedback de validação,
  visualização de contribuições.
- **Prioridade:** ALTA

### 3.7 Reservas

- **Arquivo responsável:** [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:13)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. **Não há edição nem exclusão** de reservas.
  2. `reserve_movements` é gravada corretamente em transação
     ([linha 143](lib/features/reserves/reserves_page.dart:143)), mas **não há tela
     de histórico** de movimentações.
  3. Retirada maior que o saldo é bloqueada silenciosamente
     ([linha 138](lib/features/reserves/reserves_page.dart:138)) — o diálogo fecha
     sem informar o motivo da recusa.
  4. Não há `RefreshIndicator`.
- **Impacto:** Reservas não podem ser corrigidas/removidas; usuário não entende
  por que uma retirada foi recusada; histórico inacessível.
- **Correção necessária:** Edição/exclusão, mensagem de validação de saldo,
  histórico de movimentos.
- **Prioridade:** ALTA

### 3.8 Categorias

- **Arquivo responsável:** [`categories_page.dart`](lib/features/categories/categories_page.dart:11)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. Existe criação ([linha 37](lib/features/categories/categories_page.dart:37)) e
     edição ([linha 85](lib/features/categories/categories_page.dart:85)), mas
     **não há exclusão/desativação**. A coluna `active` existe e é filtrada, mas
     nunca é alterada para `0`.
  2. O `insert` engole qualquer exceção com `catch (_) {}`
     ([linha 75](lib/features/categories/categories_page.dart:75)). Duplicidade
     (nome `UNIQUE`) falha **sem nenhuma mensagem** ao usuário.
  3. As categorias cadastradas **não são usadas** pelos formulários de transações,
     contas e parcelamentos (todos usam listas hardcoded). A funcionalidade de
     categorias é, na prática, isolada.
  4. Não há `RefreshIndicator`.
- **Impacto:** Usuário não entende por que uma categoria não foi salva; a
  funcionalidade de categorias não tem efeito real nos lançamentos.
- **Correção necessária:** Feedback de erro, exclusão/desativação e integração
  com os formulários.
- **Prioridade:** ALTA

### 3.9 Configurações

- **Arquivo responsável:** [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:8)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. O item **"Personalizar dashboard"** é um `Card` estático **sem `onTap`**
     ([linhas 113-118](lib/features/settings/settings_page_v6.dart:113)) — botão
     sem ação.
  2. O item **"Inicializar notificações"** é uma ação técnica exposta ao usuário
     final; já é chamada automaticamente em [`main.dart`](lib/main.dart:11).
  3. Existe um arquivo legado [`settings_page.dart`](lib/features/settings/settings_page.dart:3)
     (`SettingsPage`) **não referenciado** por nenhum outro arquivo — código morto.
     Ele contém vários itens sem ação (Personalizar dashboard, Editar categorias,
     Lembretes, PIN, Backup, Exportar).
- **Impacto:** Item de menu sem função confunde o usuário; código morto aumenta
  manutenção.
- **Correção necessária:** Implementar ou remover "Personalizar dashboard";
  avaliar remoção do arquivo legado após confirmação.
- **Prioridade:** MÉDIA

### 3.10 Aparência (tema)

- **Arquivo responsável:** [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:136),
  [`app.dart`](lib/app.dart:42),
  [`settings_repository.dart`](lib/core/settings/settings_repository.dart:4)
- **Status:** FUNCIONA
- **Problema encontrado:** Nenhum defeito funcional. O tema é persistido em
  `shared_preferences` e aplicado via `MaterialApp.themeMode`. A troca é
  propagada por callback `onThemeChanged`.
- **Impacto:** —
- **Correção necessária:** —
- **Prioridade:** BAIXA

### 3.11 Notificações

- **Arquivo responsável:** [`notification_service.dart`](lib/services/notification_service.dart:6),
  [`bill_reminder_service.dart`](lib/services/bill_reminder_service.dart:4),
  [`notification_settings_page.dart`](lib/features/settings/notification_settings_page.dart:4)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. **Texto com caracteres corrompidos** em `showTest()`
     ([linhas 105-106](lib/services/notification_service.dart:105)):
     `'Xarleta Finan�as'` e `'Notifica��es est�o funcionando.'`. Isso é um defeito
     real de codificação (mojibake) que aparece na notificação de teste.
  2. `initialize()` só configura `InitializationSettings` para **Android**
     ([linha 34](lib/services/notification_service.dart:34)). Em iOS/macOS não há
     configuração Darwin, então notificações não funcionam nessas plataformas.
  3. `scheduleBillReminder` usa `AndroidScheduleMode.inexactAllowWhileIdle`
     ([linha 88](lib/services/notification_service.dart:88)) — lembretes podem
     atrasar; aceitável, mas sem `exact` não há precisão.
  4. `FlutterTimezone.getLocalTimezone()` pode lançar exceção em plataformas não
     suportadas (ex.: Windows), e não há try/catch em `initialize()`
     ([linha 28](lib/services/notification_service.dart:28)). Como `main.dart`
     chama `await NotificationService.instance.initialize()` **antes** de
     `runApp` ([linha 11](lib/main.dart:11)), uma exceção aqui **impede o app de
     iniciar**.
  5. A tela de notificações apenas testa; não há controle de ativar/desativar
     lembretes.
- **Impacto:** Risco de falha de inicialização em Windows/desktop; notificação de
  teste com texto corrompido; ausência de suporte iOS/macOS.
- **Correção necessária:** Corrigir codificação dos textos; envolver
  `initialize()` em try/catch; adicionar configuração Darwin.
- **Prioridade:** CRÍTICA (risco de não iniciar) / ALTA (texto corrompido)

### 3.12 Segurança e PIN

- **Arquivo responsável:** [`pin_repository.dart`](lib/core/security/pin_repository.dart:3),
  [`app_lock_service.dart`](lib/services/app_lock_service.dart:23),
  [`security_service.dart`](lib/services/security_service.dart:4),
  [`pin_settings_page.dart`](lib/features/settings/pin_settings_page.dart:4)
- **Status:** PARCIAL
- **Problema encontrado:**
  1. **O PIN é armazenado em texto puro** em `shared_preferences`
     ([linha 25](lib/core/security/pin_repository.dart:25)) e comparado
     diretamente ([linha 31](lib/core/security/pin_repository.dart:31)). Não há
     hash. Qualquer leitura das preferências expõe o PIN.
  2. `AppLockGate._load()` verifica **apenas** `PinRepository.isEnabled()`
     ([linha 47](lib/services/app_lock_service.dart:47)), enquanto
     `AppLockService.isLockEnabled()` considera PIN **ou** biometria
     ([linha 10](lib/services/app_lock_service.dart:10)). Ou seja, se só houver
     biometria habilitada (sem PIN), o app **não bloqueia** na inicialização.
  3. O botão "USAR BIOMETRIA" aparece sempre
     ([linha 141](lib/services/app_lock_service.dart:141)), mesmo em aparelhos sem
     biometria; a falha é silenciosa.
  4. `PinSettingsPage` não pede o PIN atual antes de alterar/desativar
     ([linha 32](lib/features/settings/pin_settings_page.dart:32)).
  5. `disable()` mantém o PIN salvo, apenas desliga o flag
     ([linha 34](lib/core/security/pin_repository.dart:34)).
- **Impacto:** Segurança fraca (PIN em claro); bloqueio inconsistente quando só
  biometria está ativa.
- **Correção necessária:** Armazenar hash do PIN; alinhar `AppLockGate` com
  `isLockEnabled()`; condicionar botão de biometria à disponibilidade.
- **Prioridade:** CRÍTICA

### 3.13 Backup e restauração

- **Arquivo responsável:** [`backup_service.dart`](lib/services/backup_service.dart:4),
  [`data_management_page.dart`](lib/features/settings/data_management_page.dart:7),
  [`restore_backup_page.dart`](lib/features/settings/restore_backup_page.dart:6)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. `createJson` e `restoreJson` cobrem as 10 tabelas
     ([linhas 8-19](lib/services/backup_service.dart:8)) e a restauração é
     transacional com validação prévia
     ([linhas 50-77](lib/services/backup_service.dart:50)). Correto.
  2. `restoreJson` **não valida a versão** do backup (`decoded['version']` é
     ignorado). Um backup de schema futuro poderia ser restaurado em schema
     antigo sem aviso.
  3. O backup é compartilhado como **texto** via `Share.share(json)`
     ([linha 21](lib/features/settings/data_management_page.dart:21)), não como
     arquivo. Em alguns destinos isso pode ser inconveniente.
  4. Após restaurar, **não há recarregamento** das telas já montadas; o usuário
     precisa navegar para ver os dados novos.
  5. `_shareBackup`/`_shareCsv` não tratam exceção (apenas `finally`), então uma
     falha não gera mensagem ao usuário.
- **Impacto:** Backup/restauração funcionam, mas sem feedback de erro e sem
  validação de versão.
- **Correção necessária:** Validar versão, tratar erros e sinalizar sucesso.
- **Prioridade:** MÉDIA

### 3.14 Exportação de dados (CSV)

- **Arquivo responsável:** [`export_service.dart`](lib/services/export_service.dart:4),
  [`data_management_page.dart`](lib/features/settings/data_management_page.dart:27)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. Exporta **apenas** `transactions` ([linha 10](lib/services/export_service.dart:10)).
     Contas, parcelamentos, metas, reservas e trabalho **não são exportados**.
  2. Compartilhado como texto, não como arquivo `.csv`
     ([linha 31](lib/features/settings/data_management_page.dart:31)).
  3. Sem tratamento de erro.
- **Impacto:** Exportação limitada a lançamentos; expectativa do usuário pode ser
  maior.
- **Correção necessária:** Documentar escopo ou ampliar exportação; tratar erros.
- **Prioridade:** BAIXA

### 3.15 Análises

- **Arquivo responsável:** [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:17),
  [`finance_analytics_repository.dart`](lib/features/analytics/data/finance_analytics_repository.dart:5)
- **Status:** FUNCIONA
- **Problema encontrado:**
  1. O `FutureBuilder` cria o future **dentro do `build`**
     ([linha 49](lib/features/analytics/analytics_page_v5.dart:49)), recriando a
     consulta a cada reconstrução — mesmo padrão do Dashboard.
  2. Não há tratamento de `snapshot.hasError`: em erro, a tela fica apenas com o
     seletor de período, sem mensagem.
  3. Ao selecionar "Personalizado", `_selectCustomRange` é chamado **após**
     `setState(_filter = custom)` ([linhas 59-62](lib/features/analytics/analytics_page_v5.dart:59)).
     Se o usuário cancelar o seletor, `_filter` permanece `custom` com
     `_customStart/_customEnd` nulos, e `FinanceDateRange.fromFilter` **lança
     `ArgumentError`** ([linha 51](lib/core/analytics/date_range.dart:51)),
     quebrando a tela.
  4. `AnalyticsPage` legado ([`analytics_page.dart`](lib/features/analytics/analytics_page.dart:5))
     não é referenciado — código morto.
- **Impacto:** Tela de análises pode quebrar ao cancelar período personalizado.
- **Correção necessária:** Tratar cancelamento do seletor (reverter filtro),
  tratar erro e mover o future para `initState`.
- **Prioridade:** ALTA

---

## 4. Problemas transversais

| # | Problema | Arquivos afetados | Prioridade |
| --- | --- | --- | --- |
| T1 | `FutureBuilder` com future criado no `build` (consultas repetidas) | [`dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart:16), [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:49) | MÉDIA |
| T2 | Categorias hardcoded nos formulários, ignorando a tabela `categories` | [`transaction_form_page.dart`](lib/features/transactions/transaction_form_page.dart:31), [`bill_form_page.dart`](lib/features/bills/bill_form_page.dart:30), [`installment_form_page.dart`](lib/features/installments/installment_form_page.dart:32) | ALTA |
| T3 | Ausência de confirmação em exclusões/pagamentos | [`transactions_page.dart`](lib/features/transactions/transactions_page.dart:210), [`installments_page.dart`](lib/features/installments/installments_page.dart:215), [`bills_page.dart`](lib/features/bills/bills_page.dart:294) | ALTA |
| T4 | Código morto / arquivos não referenciados | [`settings_page.dart`](lib/features/settings/settings_page.dart:3), [`analytics_page.dart`](lib/features/analytics/analytics_page.dart:5), [`dashboard_v5_patch.dart`](lib/features/dashboard/dashboard_v5_patch.dart:1), [`bill_notification_patch.dart`](lib/core/database/bill_notification_patch.dart:1) | BAIXA |
| T5 | Falta de tratamento de erro em operações de escrita/compartilhamento | [`work_page.dart`](lib/features/work/work_page.dart:163), [`data_management_page.dart`](lib/features/settings/data_management_page.dart:17), [`categories_page.dart`](lib/features/categories/categories_page.dart:75) | MÉDIA |
| T6 | Botões/ações sem feedback de validação (diálogos fecham silenciosamente) | [`goals_page.dart`](lib/features/goals/goals_page.dart:96), [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:138), [`categories_page.dart`](lib/features/categories/categories_page.dart:75) | MÉDIA |
| T7 | Coluna `active` existe mas nunca é alterada (metas e categorias) | [`goals_page.dart`](lib/features/goals/goals_page.dart:31), [`categories_page.dart`](lib/features/categories/categories_page.dart:31) | MÉDIA |
| T8 | Tabelas de histórico persistidas mas sem tela de consulta | `goal_contributions`, `reserve_movements` | MÉDIA |
| T9 | Ausência de `RefreshIndicator` em várias listas | [`goals_page.dart`](lib/features/goals/goals_page.dart:213), [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:210), [`work_page.dart`](lib/features/work/work_page.dart:55), [`categories_page.dart`](lib/features/categories/categories_page.dart:211) | BAIXA |

---

## 5. Resumo consolidado por status

| Funcionalidade | Status | Prioridade máxima |
| --- | --- | --- |
| Dashboard | PARCIAL | MÉDIA |
| Ganhos e gastos | FUNCIONA | ALTA (integração categorias) |
| Contas e vencimentos | FUNCIONA | ALTA (duplicidade de pagamento) |
| Parcelamentos | FUNCIONA | MÉDIA |
| Trabalho e entregas | PARCIAL | ALTA |
| Metas financeiras | PARCIAL | ALTA |
| Reservas | PARCIAL | ALTA |
| Categorias | PARCIAL | ALTA |
| Configurações | PARCIAL | MÉDIA |
| Aparência | FUNCIONA | BAIXA |
| Notificações | PARCIAL | CRÍTICA |
| Segurança e PIN | PARCIAL | CRÍTICA |
| Backup e restauração | FUNCIONA | MÉDIA |
| Exportação de dados | FUNCIONA | BAIXA |
| Análises | FUNCIONA | ALTA |

### Itens CRÍTICOS (correção recomendada antes de novas funcionalidades)

1. **Notificações — risco de não iniciar o app:** `NotificationService.initialize()`
   é aguardado antes de `runApp` e pode lançar exceção em plataformas sem suporte
   a `flutter_timezone` (ex.: Windows). Ver
   [`main.dart`](lib/main.dart:11) e
   [`notification_service.dart`](lib/services/notification_service.dart:28).
2. **Segurança — PIN em texto puro:** armazenado sem hash em
   `shared_preferences`. Ver
   [`pin_repository.dart`](lib/core/security/pin_repository.dart:25).
3. **Segurança — bloqueio inconsistente:** `AppLockGate` ignora biometria isolada.
   Ver [`app_lock_service.dart`](lib/services/app_lock_service.dart:47).
4. **Análises — quebra ao cancelar período personalizado:** `ArgumentError` em
   [`date_range.dart`](lib/core/analytics/date_range.dart:51) acionado por
   [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:59).
5. **Contas — pagamento duplicado:** botão "PAGAR" sem proteção contra toques
   repetidos. Ver [`bills_page.dart`](lib/features/bills/bills_page.dart:294).

---

## 6. Observações finais

- Nenhuma funcionalidade existente foi removida ou alterada durante esta
  auditoria.
- A arquitetura atual (features com `data/`/`domain/`, `AppDatabase` singleton,
  serviços singleton) foi preservada e é coerente com a documentação.
- O schema do banco está na versão 8, com migração não destrutiva validada por
  teste automatizado ([`database_migration_test.dart`](test/database_migration_test.dart)).
- `flutter analyze` e `flutter test` passaram sem erros; `flutter build windows`
  gerou o executável com sucesso após limpeza do cache efêmero.
- A cobertura de testes é mínima: apenas migração de banco e um teste trivial de
  widget. Não há testes de repositórios financeiros nem de fluxos de UI.
- Recomenda-se tratar os itens CRÍTICOS da seção 5 antes de qualquer nova
  implementação, pois alguns podem impedir a inicialização do app ou causar
  perda/duplicação de dados.
