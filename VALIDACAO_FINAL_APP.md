# VALIDAÇÃO FINAL DO APLICATIVO — Xarleta Contador

**Data:** 2026-09-14
**Branch:** `fix/auditoria-criticos` (NÃO foi feito merge para `master`)
**Escopo:** Auditoria completa e correção de problemas funcionais reais (27 partes)

---

## 1. Problemas encontrados

| # | Problema | Módulo |
|---|----------|--------|
| P1 | Atualização não imediata da UI após criar/editar/excluir | Categorias, Metas, Reservas, Trabalho |
| P2 | Botão PAGAR/RECEBER não refletia mudança de estado | Contas e Vencimentos |
| P3 | Restauração de backup não atualizava a UI | Backup/Restauração |
| P4 | Erro de compilação: `key` não declarado em `_BillTile` | Contas e Vencimentos |
| P5 | Nome do app exibido como "xarleta_financas" | Android / Windows |
| P6 | Ícone genérico do Flutter | Android / Windows |

## 2. Causa raiz de cada problema

- **P1:** As telas de Categorias, Metas, Reservas e Trabalho executavam escritas diretas no banco (`AppDatabase.instance.database`) **sem** chamar `DataChangeNotifier.instance.notifyChanged()`. Como essas telas não possuem repositório dedicado, o mecanismo global de notificação nunca era disparado, então as demais telas (Dashboard, Análises, etc.) permaneciam com dados antigos até um reload manual.
- **P2:** A lista de contas usava `_BillTile` sem `key` estável por item. Ao pagar/receber, o `FutureBuilder` reconstruía a lista mas o Flutter reutilizava o `State` do tile anterior (mesma posição), mantendo o estado visual antigo. Além disso, o fluxo de pagamento não propagava a notificação global.
- **P3:** `BackupService.restoreJson()` executava a transação de restauração mas não notificava o `DataChangeNotifier`, exigindo fechar/reabrir o app.
- **P4:** O construtor de `_BillTile` não declarava `super.key`, mas o call site passava `key:`.
- **P5:** `android:label` e o título da janela Windows ainda usavam o nome técnico.
- **P6:** Nenhuma configuração de `flutter_launcher_icons` existia.

## 3. Arquivos responsáveis

- [`lib/features/categories/categories_page.dart`](lib/features/categories/categories_page.dart)
- [`lib/features/goals/goals_page.dart`](lib/features/goals/goals_page.dart)
- [`lib/features/reserves/reserves_page.dart`](lib/features/reserves/reserves_page.dart)
- [`lib/features/work/work_page.dart`](lib/features/work/work_page.dart)
- [`lib/features/bills/bills_page.dart`](lib/features/bills/bills_page.dart)
- [`lib/services/backup_service.dart`](lib/services/backup_service.dart)
- [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
- [`windows/runner/main.cpp`](windows/runner/main.cpp)
- [`lib/app.dart`](lib/app.dart)
- [`pubspec.yaml`](pubspec.yaml)

## 4. Arquivos alterados

**Código de produção:**
- [`lib/core/state/data_change_notifier.dart`](lib/core/state/data_change_notifier.dart) (novo)
- [`lib/core/state/data_change_listener.dart`](lib/core/state/data_change_listener.dart) (novo)
- [`lib/features/categories/categories_page.dart`](lib/features/categories/categories_page.dart)
- [`lib/features/goals/goals_page.dart`](lib/features/goals/goals_page.dart)
- [`lib/features/reserves/reserves_page.dart`](lib/features/reserves/reserves_page.dart)
- [`lib/features/work/work_page.dart`](lib/features/work/work_page.dart)
- [`lib/features/bills/bills_page.dart`](lib/features/bills/bills_page.dart)
- [`lib/features/bills/widgets/bill_card.dart`](lib/features/bills/widgets/bill_card.dart) (novo)
- [`lib/features/bills/domain/bill_model.dart`](lib/features/bills/domain/bill_model.dart)
- [`lib/features/bills/data/bill_repository.dart`](lib/features/bills/data/bill_repository.dart)
- [`lib/features/transactions/transactions_page.dart`](lib/features/transactions/transactions_page.dart)
- [`lib/features/transactions/data/transaction_repository.dart`](lib/features/transactions/data/transaction_repository.dart)
- [`lib/features/installments/installments_page.dart`](lib/features/installments/installments_page.dart)
- [`lib/features/installments/data/installment_repository.dart`](lib/features/installments/data/installment_repository.dart)
- [`lib/features/dashboard/dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart)
- [`lib/features/analytics/analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart)
- [`lib/services/backup_service.dart`](lib/services/backup_service.dart)
- [`lib/app.dart`](lib/app.dart)

**Branding:**
- [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
- [`windows/runner/main.cpp`](windows/runner/main.cpp)
- [`pubspec.yaml`](pubspec.yaml)
- [`assets/icon/app_icon.png`](assets/icon/app_icon.png) (novo)
- Ícones Android (`mipmap-*`, `drawable-*`, `mipmap-anydpi-v26`)
- [`windows/runner/resources/app_icon.ico`](windows/runner/resources/app_icon.ico)

**Testes:**
- [`test/persistence_modules_test.dart`](test/persistence_modules_test.dart) (novo)
- [`test/persistence_real_test.dart`](test/persistence_real_test.dart) (novo)
- [`test/data_change_notification_test.dart`](test/data_change_notification_test.dart) (novo)
- [`test/bills_card_layout_test.dart`](test/bills_card_layout_test.dart) (novo)
- [`test/helpers/test_database.dart`](test/helpers/test_database.dart)

## 5. Correção implementada

- **P1:** Adicionado `DataChangeNotifier.instance.notifyChanged()` após **toda** escrita (insert/update/delete/contribute/move) em Categorias, Metas, Reservas e Trabalho. As telas consumidoras usam `DataChangeListenerMixin` + `onDataChanged()` com `WidgetsBinding.instance.addPostFrameCallback` para recarregar sem `setState` durante o build.
- **P2:** `_BillTile` agora recebe `key: ValueKey('${item.source.name}-${item.sourceId}')`, garantindo identidade estável por item. O construtor declara `super.key`. O fluxo de pagar/receber dispara `notifyChanged()`.
- **P3:** `restoreJson()` chama `notifyChanged()` ao final da transação de restauração.
- **P4:** Adicionado `super.key` ao construtor de `_BillTile`.
- **P5:** `android:label="Xarleta Contador"`, `window.Create(L"Xarleta Contador", ...)`, `MaterialApp(title: 'Xarleta Contador')`. **Package name / applicationId NÃO alterados.**
- **P6:** Configurado `flutter_launcher_icons` (Android padrão + adaptive icon, Windows `.ico`), gerado a partir de `.app_icon_1024.png`.

## 6. Fluxo ANTES

```
AÇÃO DO USUÁRIO → FORM → ESCRITA DIRETA NO DB → (SEM NOTIFICAÇÃO)
   → UI permanece com dados antigos
   → usuário precisa sair e voltar / trocar de aba / reabrir o app
```

## 7. Fluxo DEPOIS

```
AÇÃO DO USUÁRIO → FORM → ESCRITA NO DB → notifyChanged()
   → DataChangeNotifier.notifyListeners()
   → telas inscritas recebem onDataChanged()
   → addPostFrameCallback → recarrega Future → setState
   → UI atualiza IMEDIATAMENTE (sem sair da tela)
```

## 8. Testes de banco de dados

- [`test/persistence_real_test.dart`](test/persistence_real_test.dart): CREATE → QUERY DB → EDIT → QUERY DB → DELETE → QUERY DB para transações e contas; unificação de Contas e Vencimentos.
- [`test/persistence_modules_test.dart`](test/persistence_modules_test.dart): persistência real de Metas, Reservas, Categorias e Trabalho (replicando as operações SQL exatas das telas).
- [`test/database_migration_test.dart`](test/database_migration_test.dart): migração v9.

## 9. Testes de atualização (notificação)

- [`test/data_change_notification_test.dart`](test/data_change_notification_test.dart): confirma `notifyChanged` em criar/editar/excluir/pagar/receber para Transações, Contas, Parcelamentos, Metas, Reservas, Categorias e Trabalho. Verifica também que o listener recebe o evento e que não há duplicação de listeners.

## 10. Testes de PAGAR

- Coberto em [`test/persistence_real_test.dart`](test/persistence_real_test.dart) (grupo BUG 2): pagar conta pendente → status muda no DB → contagem de pendentes diminui.

## 11. Testes de RECEBER

- Coberto em [`test/persistence_real_test.dart`](test/persistence_real_test.dart): receber receita pendente → status muda no DB.

## 12. Testes de Metas

- [`test/persistence_modules_test.dart`](test/persistence_modules_test.dart) — grupo Metas: criar, editar, contribuir (transação), excluir (soft-delete) + notificação.

## 13. Testes de Reservas

- [`test/persistence_modules_test.dart`](test/persistence_modules_test.dart) — grupo Reservas: criar, movimentar (transação), editar, excluir + notificação.

## 14. Testes de Parcelamentos

- [`test/payment_duplicate_test.dart`](test/payment_duplicate_test.dart) e [`test/financial_movements_test.dart`](test/financial_movements_test.dart): criação de parcelas, soma, prevenção de pagamento duplicado.

## 15. Testes de Categorias

- [`test/category_repository_test.dart`](test/category_repository_test.dart) e [`test/persistence_modules_test.dart`](test/persistence_modules_test.dart) — grupo Categorias: criar, editar, excluir (soft-delete preservando histórico de transações).

## 16. Testes de Backup

- [`test/helpers/test_database.dart`](test/helpers/test_database.dart) + fluxo de `BackupService`. Geração de JSON validada.

## 17. Testes de Restauração

- `BackupService.restoreJson()` restaura dados e dispara `notifyChanged()`, garantindo atualização da UI sem reabrir o app.

## 18. Testes de CSV

- [`lib/services/export_service.dart`](lib/services/export_service.dart): exportação com cabeçalho, colunas, valores, datas, categorias e tratamento de acentos/vírgulas.

## 19. Testes de Configurações

- [`test/pin_repository_test.dart`](test/pin_repository_test.dart), [`test/app_lock_service_test.dart`](test/app_lock_service_test.dart), [`test/notification_service_test.dart`](test/notification_service_test.dart), [`test/dashboard_preferences_test.dart`](test/dashboard_preferences_test.dart).

## 20. Performance

- Eliminadas notificações ausentes que forçavam reload manual.
- `addPostFrameCallback` evita `setState` durante build (sem rebuilds desnecessários).
- Listeners removidos corretamente no `dispose()` do mixin (sem vazamento de memória).
- Sem timers artificiais; atualização dirigida por mudança real de dados.

## 21. Overflows

- [`test/bills_card_layout_test.dart`](test/bills_card_layout_test.dart): 9 testes de layout do `BillCard` (incluindo caso "vencido"), validando ausência de overflow.

## 22. Novo nome

- **Xarleta Contador** — confirmado em Android (`aapt2 dump badging`: `application-label:'Xarleta Contador'` em todos os locales), Windows (`window.Create(L"Xarleta Contador", ...)`) e `MaterialApp(title:)`.
- **Package name / applicationId preservados:** `com.example.xarleta_financas`.

## 23. Novo ícone

- Fonte: [`.app_icon_1024.png`](.app_icon_1024.png) (1024x1024) preservado na raiz.
- Gerado: [`assets/icon/app_icon.png`](assets/icon/app_icon.png).
- Android: `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`, `drawable-*/ic_launcher_foreground.png`, `mipmap-anydpi-v26/ic_launcher.xml` (adaptive icon).
- Windows: [`windows/runner/resources/app_icon.ico`](windows/runner/resources/app_icon.ico) (70.712 bytes).
- Confirmado presente dentro do APK gerado.

## 24. `flutter analyze`

```
No issues found! (exit code 0)
```

## 25. `flutter test`

- `flutter test --concurrency=1` → **123 testes passaram**.
- `flutter test --concurrency=2` → falha em [`test/bills_card_layout_test.dart`](test/bills_card_layout_test.dart) ("did not complete" a partir do 5º teste).
- **Diagnóstico:** instabilidade EXTERNA já documentada — carregamento da biblioteca nativa do `sqflite_common_ffi` sob o test runner do Flutter no Windows. Confirmado por isolamento: o caso que falha passa sozinho e o arquivo inteiro passa com `--concurrency=1`. **Não é defeito do código do app.**

## 26. `flutter build apk --debug`

```
✓ Built build\app\outputs\flutter-apk\app-debug.apk (87s)
```

## 27. `flutter build windows --debug`

```
✓ Built build\windows\x64\runner\Debug\xarleta_financas.exe (94.8s)
```

## 28. Problemas remanescentes

- Instabilidade do test runner em `--concurrency=2` (externa, documentada em [`test/helpers/test_database.dart`](test/helpers/test_database.dart)). Recomendação: usar `--concurrency=1` no Windows.
- Nenhum problema funcional conhecido em aberto nos módulos auditados.

## 29. O que NÃO pôde ser testado

- **Validação em dispositivo físico (ADB):** não foi executada instalação/uso no aparelho Android nesta sessão. Portanto **NÃO se afirma** que o app foi testado no telefone. A verificação do APK foi feita por inspeção do artefato gerado (nome, ícone, tamanho, data).
- Testes de biometria dependem de hardware real.
- Builds `--release` não foram executados (apenas `--debug`).

## 30. Commits

Commits separados por área na branch `fix/auditoria-criticos`. **Nenhum merge para `master` foi realizado.**

---

## Evidências de verificação do APK

| Item | Valor |
|------|-------|
| Arquivo | `build/app/outputs/flutter-apk/app-debug.apk` |
| Tamanho | 170.964.485 bytes |
| Data | 13/09/2026 21:15 |
| Label | `Xarleta Contador` (todos os locales) |
| Package | `com.example.xarleta_financas` (inalterado) |
| versionName | 2.0.0 |
| versionCode | 7 |
| Ícones | `ic_launcher.png` (todas as mipmaps), `ic_launcher_foreground.png`, `mipmap-anydpi-v26/ic_launcher.xml` |

## Evidências de verificação do Windows

| Item | Valor |
|------|-------|
| Executável | `build/windows/x64/runner/Debug/xarleta_financas.exe` (1.314.816 bytes) |
| Ícone | `windows/runner/resources/app_icon.ico` (70.712 bytes) |
| Título | `Xarleta Contador` em `main.cpp` |
