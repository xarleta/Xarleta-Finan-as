# Arquitetura do Projeto

## Visao geral

Xarleta Financas e um aplicativo Flutter para controle financeiro pessoal
offline. O ponto de entrada e `lib/main.dart`; ele prepara o Flutter,
configura o SQLite para a plataforma atual, inicializa notificacoes e inicia
`XarletaFinancasApp`.

## Estrutura de pastas

```text
lib/
  main.dart                         Inicializacao da aplicacao
  app.dart                          MaterialApp, tema persistido e bloqueio
  core/
    analytics/                      Filtros de periodo
    database/                       Banco SQLite e configuracao por plataforma
    security/                       Repositorio do PIN
    settings/                       Preferencias locais, incluindo tema
    theme/                          Temas claro e escuro
    utils/                          Formatacao e conversao de valores
  features/
    shell/                          Navegacao principal e hub de financas
    dashboard/                      Resumo inicial
    transactions/                   Ganhos e gastos
    bills/                          Contas, vencimentos e pagamentos
    installments/                   Parcelamentos
    work/                           Trabalho e entregas
    goals/                          Metas financeiras
    reserves/                       Reservas e movimentacoes
    categories/                     Categorias de ganhos e gastos
    analytics/                      Graficos e analises por periodo
    settings/                       Aparencia, notificacoes, seguranca e dados
  services/                         Integracoes de backup, notificacao e seguranca
test/                               Testes Flutter e de migracao do banco
```

As funcionalidades com modelos e repositorios separados usam a organizacao
`data/` e `domain/` dentro da respectiva feature. As telas mais simples usam
`AppDatabase` diretamente.

## Navegacao principal

`AppShell` apresenta cinco destinos na barra inferior:

1. Inicio: `DashboardPage`.
2. Financas: `FinanceHubPage`.
3. Adicionar: atalhos para novo ganho/gasto e registro de trabalho.
4. Analises: `AnalyticsPageV5`.
5. Configuracoes: `SettingsPageV6`.

O hub de financas abre, por rotas `MaterialPageRoute`, Ganhos e gastos,
Contas e vencimentos, Parcelamentos, Trabalho e entregas, Metas financeiras,
Reservas e Categorias. Formularios e telas secundarias retornam pela pilha do
`Navigator`; telas de cadastro retornam `true` quando houve alteracao para que
a tela anterior recarregue seus dados.

## Funcionalidades

- Lancamentos de ganho e gasto, com busca, filtros, criacao, edicao e exclusao.
- Contas recorrentes ou avulsas, vencimentos e marcacao de pagamento.
- Parcelamentos, pagamento da proxima parcela, edicao e exclusao.
- Registro de trabalho/entregas com ganhos, gastos, horas e quilometragem.
- Metas financeiras e contribuicoes.
- Reservas, depositos, retiradas e historico de movimentos.
- Categorias ativas de ganho e gasto.
- Dashboard e analises com periodo, graficos e indicadores.
- Tema sistema, claro ou escuro persistido em preferencias locais.
- PIN de aplicativo, bloqueio ao retornar ao app e autenticacao biometrica
  quando disponivel.
- Notificacoes locais de contas e notificacao de teste.
- Backup JSON, restauracao transacional e exportacao CSV de lancamentos.

## Banco de dados

`AppDatabase` usa o arquivo `xarleta_financas.db` e schema na versao **8**.
Criacao e migracao ficam em `lib/core/database/app_database.dart`.

Tabelas existentes:

| Tabela | Finalidade |
| --- | --- |
| `transactions` | Lancamentos de ganho e gasto. |
| `bills` | Contas e vencimentos. |
| `installments` | Parcelamentos e progresso de pagamento. |
| `work_sessions` | Sessoes de trabalho e entregas. |
| `goals` | Metas financeiras. |
| `reserves` | Saldos das reservas. |
| `categories` | Categorias ativas de ganho e gasto. |
| `goal_contributions` | Aportes em metas. |
| `reserve_movements` | Depositos e retiradas de reservas. |
| `app_settings` | Configuracoes persistidas no banco. |

Ha indices para `bills.due_date`, `transactions.transaction_date` e
`transactions(type, transaction_date)`. A migracao para a versao 8 usa
`CREATE TABLE IF NOT EXISTS`; nao executa exclusao ou recriacao de tabelas.
O teste `test/database_migration_test.dart` valida a atualizacao de uma base
legada com dados preservados.

## SQLite no Windows

Em Windows e Linux, `database_platform_io.dart` inicializa
`sqflite_common_ffi` e define `databaseFactoryFfi`. O arquivo
`database_platform.dart` usa importacao condicional, preservando a compilacao
para web. O build Windows inclui `sqlite3.dll` como ativo nativo. Android e
macOS continuam usando a implementacao registrada pelo pacote `sqflite`.

## Servicos

| Servico | Responsabilidade |
| --- | --- |
| `AppLockService` | Verificacao e desbloqueio por PIN/biometria; contem `AppLockGate`. |
| `SecurityService` | Integracao com `local_auth`. |
| `NotificationService` | Inicializacao, agendamento e cancelamento de lembretes. |
| `BillReminderService` | Regras de lembrete relacionadas a contas. |
| `BackupService` | Backup JSON e restauracao dentro de transacao. |
| `ExportService` | Exportacao CSV de transacoes. |

## Tema, seguranca e dados

`SettingsRepository` persiste o tema em `shared_preferences`. `app.dart`
carrega essa preferencia antes de montar o shell e encaminha alteracoes ao
menu de configuracoes. `AppLockGate` envolve o shell para respeitar PIN
configurado e relocar o aplicativo quando entra em segundo plano.

Backup e restauracao ficam em `DataManagementPage` e `RestoreBackupPage`.
Antes de restaurar, o usuario recebe confirmacao; a substituicao das tabelas
ocorre dentro de uma unica transacao.

## Dependencias principais

- Flutter e Material Design
- `sqflite`, `path` e `sqflite_common_ffi`
- `shared_preferences`
- `flutter_local_notifications`, `timezone` e `flutter_timezone`
- `local_auth`
- `fl_chart`
- `share_plus`, `file_picker` e `csv`
- `intl` e `flutter_localizations`
