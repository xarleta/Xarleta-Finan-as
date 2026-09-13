# Auditoria Funcional Completa — Xarleta Finanças

> Relatório atualizado após a auditoria da branch `fix/auditoria-criticos`.
> Documenta o estado **real** do código após as correções aplicadas nesta rodada.
> Nenhuma funcionalidade existente foi removida; apenas lacunas confirmadas foram
> corrigidas.

---

## 1. Resultado das validações executadas

| Validação | Comando | Resultado |
| --- | --- | --- |
| Análise estática | `flutter analyze` | **No issues found!** |
| Testes automatizados | `flutter test --concurrency=1` | **49 testes, todos aprovados** |
| Branch | `git branch --show-current` | `fix/auditoria-criticos` |

> Observação: o `MissingPluginException` de `local_auth` exibido durante os testes
> é **esperado** no ambiente de teste (sem plugin nativo) e é tratado
> graciosamente por [`SecurityService`](lib/services/security_service.dart:4),
> que retorna `false` em vez de lançar.

---

## 2. Mapa de navegação

### Barra inferior ([`AppShell`](lib/features/shell/app_shell.dart:1))

- **Início** → Dashboard
- **Finanças** → Hub com 7 atalhos
- **Adicionar** → Ação rápida (ganho/gasto e registrar trabalho)
- **Análises** → `AnalyticsPageV5`
- **Config** → `SettingsPageV6`

### Hub de Finanças ([`FinanceHubPage`](lib/features/shell/app_shell.dart:1))

Transações, Contas, Parcelamentos, Trabalho, Metas, Reservas, Categorias.

### Configurações ([`SettingsPageV6`](lib/features/settings/settings_page_v6.dart:8))

Aparência, Notificações, Segurança, Backup/Restauração, Exportação, Sobre.

---

## 3. Auditoria por funcionalidade

### 3.1 Dashboard

- **Arquivo:** [`dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart:8)
- **Status:** FUNCIONA
- **Observações:**
  - O `Future` é criado em `initState` ([linha 24](lib/features/dashboard/dashboard_page.dart:24)),
    não no `build` — consulta não é recriada a cada reconstrução.
  - Trata `waiting`, `hasError` (com "Tentar novamente") e lista vazia.
  - Personalização persistida em `app_settings` via
    [`DashboardPreferencesRepository`](lib/features/dashboard/data/dashboard_preferences_repository.dart:1).
  - O resumo usa [`TransactionRepository.summary()`](lib/features/transactions/data/transaction_repository.dart:52),
    que soma **todas** as transações (sem filtro de período). Contas e parcelas
    pagas geram transações, portanto **não há dupla contagem** — o valor entra
    uma única vez, no momento do pagamento.
- **Prioridade:** BAIXA

### 3.2 Ganhos e gastos (Transações)

- **Arquivo:** [`transaction_form_page.dart`](lib/features/transactions/transaction_form_page.dart:7),
  [`transactions_page.dart`](lib/features/transactions/transactions_page.dart:1)
- **Status:** FUNCIONA (com limitação de escopo documentada)
- **Observações:**
  - O formulário oferece **apenas** `Gasto`/`Ganho` (única ocorrência). **Não há**
    seleção de natureza "recorrente" nem "parcelada" dentro do formulário.
  - Categorias são carregadas do banco via
    [`CategoryRepository.namesByType()`](lib/features/categories/data/category_repository.dart:1),
    com estados de carregamento, erro e vazio.
  - Exclusão exige confirmação ([linha 210](lib/features/transactions/transactions_page.dart:210)).
  - **Limitação de arquitetura (não é bug):** despesa recorrente é representada
    por **Contas** (com recorrência) e despesa parcelada por **Parcelamentos**.
    Receita recorrente **não possui** representação dedicada.
- **Prioridade:** MÉDIA (ver seção 5 — lacuna de receita recorrente)

### 3.3 Contas e vencimentos

- **Arquivo:** [`bill_form_page.dart`](lib/features/bills/bill_form_page.dart:7),
  [`bill_repository.dart`](lib/features/bills/data/bill_repository.dart:5)
- **Status:** FUNCIONA
- **Observações:**
  - Recorrência: `once`, `weekly`, `monthly`, `yearly`.
  - `markPaid()` é transacional e relê o status dentro da transação
    ([linha 54](lib/features/bills/data/bill_repository.dart:54)), impedindo
    pagamento duplicado mesmo em chamadas simultâneas.
  - Conta recorrente gera a próxima ocorrência sem duplicar a transação.
  - Categorias carregadas do banco (tipo `expense`).
  - Exclusão exige confirmação ([linha 275](lib/features/bills/bills_page.dart:275)).
- **Prioridade:** BAIXA

### 3.4 Parcelamentos

- **Arquivo:** [`installment_form_page.dart`](lib/features/installments/installment_form_page.dart:1),
  [`installment_repository.dart`](lib/features/installments/data/installment_repository.dart:4)
- **Status:** FUNCIONA
- **Observações:**
  - `payNext()` é transacional e relê o estado
    ([linha 41](lib/features/installments/data/installment_repository.dart:41)),
    impedindo duplicação.
  - Ao pagar a última parcela, o status vira `finished`.
  - `nextDueDate` usa `DateTime(ano, mês + pagas, dia)`
    ([`installment_model.dart`](lib/features/installments/domain/installment_model.dart:1)).
    Para dias 29–31 pode haver normalização de fim de mês (ex.: 31 → 30/28).
    Comportamento aceitável, mas vale registrar.
- **Prioridade:** BAIXA

### 3.5 Trabalho e entregas

- **Arquivo:** [`work_page.dart`](lib/features/work/work_page.dart:5)
- **Status:** FUNCIONA (após correções desta rodada)
- **Corrigido nesta rodada:**
  1. **Exclusão de sessão** adicionada, com confirmação
     ([`_deleteSession`](lib/features/work/work_page.dart:25)).
  2. **Validação** no formulário: sessão sem ganhos e sem gastos é recusada com
     mensagem ([`_save`](lib/features/work/work_page.dart:211)).
  3. `mounted` verificado após o `Navigator.push`
     ([linha 102](lib/features/work/work_page.dart:102)).
- **Pendências remanescentes:**
  - Não há **edição** de sessão (apenas criar/excluir).
  - A data da sessão é sempre `DateTime.now()` — não há campo de data.
- **Prioridade:** MÉDIA

### 3.6 Metas financeiras

- **Arquivo:** [`goals_page.dart`](lib/features/goals/goals_page.dart:5)
- **Status:** FUNCIONA (após correções desta rodada)
- **Corrigido nesta rodada:**
  1. **Edição** de nome, valor alvo e prazo
     ([`editGoal`](lib/features/goals/goals_page.dart:178)).
  2. **Remoção** com soft delete (`active = 0`), preservando contribuições
     ([`deleteGoal`](lib/features/goals/goals_page.dart:262)).
  3. Menu de ações (Editar/Remover) no card.
- **Pendências remanescentes:**
  - Não há tela de **histórico de contribuições** (a tabela
    `goal_contributions` é gravada, mas não consultada).
- **Prioridade:** MÉDIA

### 3.7 Reservas

- **Arquivo:** [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:6)
- **Status:** FUNCIONA (após correções desta rodada)
- **Corrigido nesta rodada:**
  1. **Feedback de saldo insuficiente** ao retirar mais que o disponível
     ([linha 138](lib/features/reserves/reserves_page.dart:138)) — antes fechava
     em silêncio.
  2. **Edição** de nome e valor atual
     ([`editReserve`](lib/features/reserves/reserves_page.dart:190)).
  3. **Remoção** transacional da reserva e de suas movimentações
     ([`deleteReserve`](lib/features/reserves/reserves_page.dart:257)).
- **Pendências remanescentes:**
  - Não há tela de **histórico de movimentações** (a tabela
    `reserve_movements` é gravada, mas não consultada).
- **Prioridade:** MÉDIA

### 3.8 Categorias

- **Arquivo:** [`categories_page.dart`](lib/features/categories/categories_page.dart:4)
- **Status:** FUNCIONA (após correções desta rodada)
- **Corrigido nesta rodada:**
  1. **Remoção** com soft delete (`active = 0`), preservando lançamentos
     ([`removeCategory`](lib/features/categories/categories_page.dart:160)).
  2. **Feedback de erro** no `edit()` (duplicidade de nome) — antes falhava em
     silêncio ([linha 124](lib/features/categories/categories_page.dart:124)).
  3. Menu de ações (Editar/Remover) por item.
- **Observações:**
  - As categorias **são** usadas pelos formulários de transações, contas e
    parcelamentos (via `CategoryRepository.namesByType`).
  - A coluna `active` agora é efetivamente alterada.
- **Prioridade:** BAIXA

### 3.9 Configurações

- **Arquivo:** [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:8)
- **Status:** FUNCIONA
- **Observações:**
  - "Personalizar dashboard" possui ação (abre `DashboardCustomizePage`).
  - Existe arquivo legado [`settings_page.dart`](lib/features/settings/settings_page.dart:3)
    não referenciado (código morto). Remoção é opcional e de baixo risco.
- **Prioridade:** BAIXA

### 3.10 Aparência (tema)

- **Arquivo:** [`settings_page_v6.dart`](lib/features/settings/settings_page_v6.dart:136),
  [`app.dart`](lib/app.dart:42),
  [`settings_repository.dart`](lib/core/settings/settings_repository.dart:4)
- **Status:** FUNCIONA
- **Observações:** Tema persistido em `shared_preferences` e aplicado via
  `MaterialApp.themeMode`; troca propagada por callback.
- **Prioridade:** BAIXA

### 3.11 Notificações

- **Arquivo:** [`notification_service.dart`](lib/services/notification_service.dart:6),
  [`bill_reminder_service.dart`](lib/services/bill_reminder_service.dart:4)
- **Status:** FUNCIONA
- **Observações:**
  - `initialize()` é **à prova de falha**: envolve tudo em `try/catch` e nunca
    propaga exceção ([linha 49](lib/services/notification_service.dart:49)).
  - `main.dart` dispara a inicialização com `unawaited`
    ([linha 15](lib/main.dart:15)), sem bloquear o `runApp`.
  - `FlutterTimezone.getLocalTimezone()` tem `try/catch` interno
    ([linha 56](lib/services/notification_service.dart:56)).
  - `scheduleBillReminder` retorna cedo quando o plugin não está inicializado
    ([linha 100](lib/services/notification_service.dart:100)).
  - **Pendência:** configuração Darwin (iOS/macOS) ausente — notificações não
    funcionam nessas plataformas. Alvo atual é Android.
- **Prioridade:** BAIXA (Android) / MÉDIA (iOS/macOS)

### 3.12 Segurança e PIN

- **Arquivo:** [`pin_repository.dart`](lib/core/security/pin_repository.dart:3),
  [`app_lock_service.dart`](lib/services/app_lock_service.dart:23),
  [`security_service.dart`](lib/services/security_service.dart:4)
- **Status:** FUNCIONA
- **Observações:**
  - PIN armazenado com **PBKDF2-HMAC-SHA256** (120000 iterações, 32 bytes,
    salt base64Url), com migração automática de formatos legados
    (texto puro e SHA-256+salt).
  - Comparação em tempo constante (`_constantTimeEquals`).
  - `AppLockGate` usa `AppLockService.isLockEnabled()` (PIN **ou** biometria
    disponível), alinhado ao serviço.
  - Botão de biometria condicionado à disponibilidade real.
  - `AppLockGate` trata ciclo de vida (relock em pause/inactive, guardado por
    `_unlocking`).
- **Prioridade:** BAIXA

### 3.13 Backup e restauração

- **Arquivo:** [`backup_service.dart`](lib/services/backup_service.dart:4),
  [`data_management_page.dart`](lib/features/settings/data_management_page.dart:7),
  [`restore_backup_page.dart`](lib/features/settings/restore_backup_page.dart:6)
- **Status:** FUNCIONA
- **Observações:**
  - Cobre as 10 tabelas; restauração transacional com validação prévia.
  - **Pendência:** `restoreJson` não valida a versão do backup
    (`decoded['version']` é ignorado). Um backup de schema futuro poderia ser
    restaurado sem aviso.
- **Prioridade:** MÉDIA

### 3.14 Exportação de dados (CSV)

- **Arquivo:** [`export_service.dart`](lib/services/export_service.dart:4)
- **Status:** FUNCIONA (escopo limitado)
- **Observações:** Exporta apenas `transactions`. Contas, parcelamentos, metas,
  reservas e trabalho não são exportados.
- **Prioridade:** BAIXA

### 3.15 Análises

- **Arquivo:** [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:10),
  [`finance_analytics_repository.dart`](lib/features/analytics/data/finance_analytics_repository.dart:5)
- **Status:** FUNCIONA
- **Observações:**
  - `Future` criado em `initState` ([linha 26](lib/features/analytics/analytics_page_v5.dart:26)).
  - `snapshot.hasError` tratado com "Tentar novamente".
  - Cancelamento do período personalizado **não** quebra a tela: o filtro só é
    aplicado após confirmação
    ([`_onFilterChanged`](lib/features/analytics/analytics_page_v5.dart:61)).
- **Prioridade:** BAIXA

---

## 4. Problemas transversais

| # | Problema | Arquivos afetados | Prioridade | Status |
| --- | --- | --- | --- | --- |
| T1 | Código morto / arquivos não referenciados | [`settings_page.dart`](lib/features/settings/settings_page.dart:3), [`analytics_page.dart`](lib/features/analytics/analytics_page.dart:5), [`dashboard_v5_patch.dart`](lib/features/dashboard/dashboard_v5_patch.dart:1), [`bill_notification_patch.dart`](lib/core/database/bill_notification_patch.dart:1) | BAIXA | Pendente |
| T2 | Tabelas de histórico persistidas sem tela de consulta | `goal_contributions`, `reserve_movements` | MÉDIA | Pendente |
| T3 | Ausência de `RefreshIndicator` em algumas listas | [`goals_page.dart`](lib/features/goals/goals_page.dart:1), [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:1), [`work_page.dart`](lib/features/work/work_page.dart:1), [`categories_page.dart`](lib/features/categories/categories_page.dart:1) | BAIXA | Pendente |
| T4 | Backup não valida versão do schema | [`backup_service.dart`](lib/services/backup_service.dart:4) | MÉDIA | Pendente |
| T5 | Exportação CSV limitada a transações | [`export_service.dart`](lib/services/export_service.dart:4) | BAIXA | Pendente |
| T6 | Sem suporte a receita recorrente | (arquitetura) | ALTA | Pendente |

---

## 5. Lacuna de arquitetura: receita recorrente

**Situação confirmada:** não existe suporte a **receita recorrente**.

- **Despesa única:** Transações (Gasto).
- **Despesa recorrente:** Contas (com recorrência).
- **Despesa parcelada:** Parcelamentos.
- **Receita única:** Transações (Ganho).
- **Receita recorrente:** **não existe**.

**Por que não foi implementado nesta rodada:** implementar receita recorrente
exige decisão de arquitetura (nova tabela `incomes` recorrentes, ou generalizar
`bills` para aceitar `type`, ou um modelo unificado de "movimentações
recorrentes"). Isso altera schema e fluxos — fora do escopo de "correção de
problemas confirmados" e sujeito a aprovação.

**Opções de implementação (para decisão futura):**

1. **Generalizar `bills`** adicionando coluna `type` (`expense`/`income`) e
   renomeando conceitualmente para "compromissos/recorrências". Menor esforço,
   reutiliza `markPaid`, recorrência e lembretes. Requer migração de schema.
2. **Nova tabela `recurring_incomes`** espelhando `bills`. Isola domínios, mas
   duplica lógica.
3. **Modelo unificado de recorrência** (`recurring_entries`) com `type`. Mais
   limpo a longo prazo, maior refatoração.

**Recomendação:** opção 1 (generalizar `bills`), por reutilizar toda a
infraestrutura já testada de recorrência, lembretes e proteção contra duplicação.

---

## 6. Resumo consolidado por status

| Funcionalidade | Status | Prioridade máxima |
| --- | --- | --- |
| Dashboard | FUNCIONA | BAIXA |
| Ganhos e gastos | FUNCIONA | MÉDIA (receita recorrente) |
| Contas e vencimentos | FUNCIONA | BAIXA |
| Parcelamentos | FUNCIONA | BAIXA |
| Trabalho e entregas | FUNCIONA | MÉDIA (edição/data) |
| Metas financeiras | FUNCIONA | MÉDIA (histórico) |
| Reservas | FUNCIONA | MÉDIA (histórico) |
| Categorias | FUNCIONA | BAIXA |
| Configurações | FUNCIONA | BAIXA |
| Aparência | FUNCIONA | BAIXA |
| Notificações | FUNCIONA | BAIXA (Android) |
| Segurança e PIN | FUNCIONA | BAIXA |
| Backup e restauração | FUNCIONA | MÉDIA (versão) |
| Exportação de dados | FUNCIONA | BAIXA |
| Análises | FUNCIONA | BAIXA |

---

## 7. Correções aplicadas nesta rodada

| Área | Correção | Arquivo |
| --- | --- | --- |
| Categorias | Remoção (soft delete) + feedback de erro no editar + menu de ações | [`categories_page.dart`](lib/features/categories/categories_page.dart:160) |
| Metas | Edição + remoção (soft delete) + menu de ações | [`goals_page.dart`](lib/features/goals/goals_page.dart:178) |
| Reservas | Feedback de saldo insuficiente + edição + remoção transacional | [`reserves_page.dart`](lib/features/reserves/reserves_page.dart:138) |
| Trabalho | Exclusão de sessão + validação de valores | [`work_page.dart`](lib/features/work/work_page.dart:25) |

**Validação:** `flutter analyze` → *No issues found!*;
`flutter test --concurrency=1` → *49 testes aprovados*.

---

## 8. Observações finais

- Nenhuma funcionalidade existente foi removida ou teve comportamento alterado
  de forma destrutiva.
- A arquitetura atual (features com `data/`/`domain/`, `AppDatabase` singleton,
  serviços singleton) foi preservada.
- O schema permanece na **versão 8**; nenhuma migração foi necessária nesta
  rodada (as correções usam colunas já existentes, como `active`).
- As correções de remoção usam **soft delete** onde há histórico associado
  (categorias, metas), evitando perda de dados.
- A lacuna de **receita recorrente** permanece como principal item de
  arquitetura pendente, documentada na seção 5.
