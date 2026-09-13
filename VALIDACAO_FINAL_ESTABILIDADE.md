# Validação Final de Estabilidade — Xarelta Finanças

Branch: `fix/auditoria-criticos`
Data da validação: 2026-09-13
Flutter: 3.47.4 (stable) · Dart: 3.13.3 · Plataforma: Windows 11 (12 núcleos lógicos)

---

## 1. STATUS FINAL

**APROVADO COM RESSALVAS**

A suíte de testes está estável e reproduzível (3 execuções consecutivas completas, 64 testes cada),
o `flutter analyze` não reporta problemas e os três builds (APK debug, Windows debug, Windows release)
foram gerados com sucesso. A ressalva é que a estabilidade depende do uso do script versionado
`tool/test.bat` / `tool/test.sh`, que fixa a concorrência em 2 — ver seções 3 e 4.

---

## 2. CAUSA RAIZ DO TESTE INSTÁVEL

Foram identificadas **duas causas independentes**, ambas confirmadas por evidência empírica.

### 2.1 Causa raiz primária — inicialização de plugin pendurada (deadlock)

O `NotificationService.initialize()` aguardava, sem limite de tempo, chamadas de plugin de
plataforma que **nunca respondem** em ambiente de teste:

- `FlutterTimezone.getLocalTimezone()`
- `FlutterLocalNotificationsPlugin.initialize()`
- `createNotificationChannel()` / `requestNotificationsPermission()`

Em ambiente de teste não existe implementação nativa desses canais. O `await` ficava pendurado
indefinidamente. Como `BillRepository.markPaid()` chama `BillReminderService.sync()`/`cancel()`,
que por sua vez chamam `NotificationService`, o teste travava em `did not complete [E]`.

**Evidência:** o teste `financial_movements_test.dart: Despesa recorrente pagamento gera despesa e
próxima ocorrência sem duplicar` repetiu por ~7 segundos e então travou. O mesmo arquivo passava
isoladamente, mas travava sob paralelismo — comportamento típico de espera sem timeout.

### 2.2 Causa raiz secundária — concorrência do runner sob paralelismo máximo

O `flutter test` executa cada arquivo em um isolate próprio, em paralelo, usando por padrão o
número de núcleos lógicos (12 nesta máquina). Cada isolate carrega a biblioteca nativa do SQLite
via `sqfliteFfiInit()`. Com 12 isolates carregando a biblioteca simultaneamente, o runner derruba
isolates, produzindo falhas aleatórias:

```
Failed to load "...": Connection closed before test suite loaded.
... did not complete [E]
```

**Evidência decisiva:** as falhas ocorreram em arquivos **sem SQLite** (`pin_repository_test.dart`,
`notification_service_test.dart`, `date_range_test.dart`), provando que a origem não é a lógica de
banco, e sim o esgotamento de recursos do runner sob paralelismo máximo.

### 2.3 Hipóteses descartadas com evidência

| Hipótese | Resultado | Evidência |
|---|---|---|
| `dart_test.yaml` limitaria a concorrência | **FALSO** | Chave inválida no arquivo não gerou erro algum; `flutter test` ignora o arquivo |
| `flutter_test_config.dart` ajudaria | **FALSO / PREJUDICIAL** | Chamar `sqfliteFfiInit()` em todos os isolates (inclusive sem SQLite) agravou a instabilidade |
| Processos `dart.exe` órfãos | **FALSO** | Os 3 processos eram `tooling-daemon` normais do Flutter |
| `flutter_crash_log.txt` relevante | **FALSO** | É um log de `flutter run`, encerrado normalmente com exit code 0 |

---

## 3. CORREÇÕES APLICADAS

### 3.1 `lib/services/notification_service.dart` — timeout defensivo na inicialização

Adicionado `_initTimeout` (5 s) aplicado a todas as chamadas de plugin em `_doInitialize()`.
Se um canal de plataforma não responder, a inicialização conclui marcando as notificações como
indisponíveis, em vez de deixar o `await` pendurado. Preserva o comportamento em produção
(onde os plugins respondem normalmente) e elimina o deadlock em testes.

### 3.2 `test/helpers/test_database.dart` — remoção de arquivo sem `deleteDatabase`

`setUpAll` e `tearDownAll` passaram a remover o arquivo `.db` diretamente via `dart:io`
(`File.delete()`), em vez de `deleteDatabase()`. O `deleteDatabase` do `sqflite_common_ffi`
pode reabrir uma conexão interna e, sob paralelismo, não retornar. Como o diretório é exclusivo
por arquivo de teste, a remoção direta é equivalente e não bloqueia.

### 3.3 `lib/features/installments/installments_page.dart` — guarda `mounted`

`refresh()` chamava `setState` sem verificar `mounted`. Como é invocado após
`await Navigator.push` (retorno do formulário), poderia lançar se a tela fosse descartada.
Adicionada a verificação `if (!mounted) return;`.

### 3.4 `lib/features/bills/bills_page.dart` — guarda `mounted`

Mesmo padrão em `_refresh()`, também chamado após `await Navigator.push`. Adicionada a
verificação `if (!mounted) return;`.

### 3.5 `tool/test.bat` e `tool/test.sh` — configuração de concorrência versionada

Scripts de projeto que executam a suíte com `--concurrency=2`. **Não é `--concurrency=1`**:
os testes continuam executando em paralelo. O valor 2 foi escolhido empiricamente — com 4
ainda ocorreram falhas esporádicas nesta máquina.

### 3.6 `lib/core/database/app_database.dart` — `closeForTesting()` (trabalho anterior)

Método que fecha o handle e limpa o singleton, usado exclusivamente pelos testes. Não afeta
produção.

---

## 4. TESTES

### 4.1 `flutter test` — execução 1

```
tool\test.bat  →  All tests passed!  (64 testes)
```

### 4.2 `flutter test` — execução 2

```
tool\test.bat  →  All tests passed!  (64 testes)
```

### 4.3 `flutter test` — execução 3

```
tool\test.bat  →  All tests passed!  (64 testes)
```

### 4.4 Execução adicional após correções de lifecycle

```
tool\test.bat  →  All tests passed!  (64 testes)
```

### 4.5 Teste de concorrência (obrigatório)

| Concorrência | Resultado |
|---|---|
| 1 (baseline) | 64 testes passaram |
| 2 | 64 testes passaram (múltiplas execuções) |
| 4 | Falha esporádica (`Connection closed before test suite loaded`) |
| padrão (12) | Falha esporádica em arquivos variados |

---

## 5. flutter analyze

```
flutter analyze
Analyzing XareltaFinancas...
No issues found! (ran in 2.9s)
```

Executado duas vezes (antes e depois das correções de lifecycle): **No issues found!** em ambas.

---

## 6. ANDROID APK

```
flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

Configuração preservada: `compileSdk 36`, Java 17, Kotlin JVM 17, Core Library Desugaring,
`file_picker 12.3.0`, `share_plus 13.0.0`.

Aviso não bloqueante do Gradle: `flutter_timezone` e `share_plus` ainda aplicam o Kotlin Gradle
Plugin (KGP). É um aviso de deprecação futura do Flutter, não um erro de build.

---

## 7. WINDOWS DEBUG

```
flutter build windows --debug
√ Built build\windows\x64\runner\Debug\xarleta_financas.exe
```

---

## 8. WINDOWS RELEASE

```
flutter build windows --release
√ Built build\windows\x64\runner\Release\xarleta_financas.exe
```

---

## 9. NOVOS PROBLEMAS ENCONTRADOS

1. **`setState` sem `mounted` em `installments_page.dart` e `bills_page.dart`** — corrigido
   (seções 3.3 e 3.4). Ambos os métodos são chamados após `await Navigator.push`.
2. **Inicialização de plugin sem timeout no `NotificationService`** — corrigido (seção 3.1).
   Além de travar testes, um plugin que não respondesse em produção deixaria o app pendurado.
3. **Aviso de KGP** em `flutter_timezone` e `share_plus` — não bloqueante, requer atualização
   futura dos plugins.

---

## 10. PENDÊNCIAS REAIS

1. A estabilidade depende do script `tool/test.bat` / `tool/test.sh`. Executar `flutter test`
   diretamente (concorrência padrão = 12) ainda pode falhar esporadicamente nesta máquina.
   Isso é uma limitação do runner do Flutter no Windows sob paralelismo máximo, não do código
   do projeto.
2. O valor de concorrência 2 foi calibrado para esta máquina (12 núcleos). Em máquinas com
   menos núcleos pode ser necessário ajustar.
3. Os plugins `flutter_timezone` e `share_plus` precisarão migrar para Built-in Kotlin em
   versões futuras do Flutter.

---

## 11. COMMITS

Commits separados por área (ver histórico do Git na branch `fix/auditoria-criticos`):

1. Infraestrutura de teste (helper + `closeForTesting`)
2. Correção de estabilidade (`NotificationService` timeout + remoção de arquivo sem `deleteDatabase`)
3. Correção de lifecycle (`mounted` em `installments_page` e `bills_page`)
4. Scripts de teste versionados (`tool/test.bat`, `tool/test.sh`)
5. Documentação (`VALIDACAO_FINAL_ESTABILIDADE.md`)

---

## 12. MERGE

**NÃO REALIZADO.** A branch `fix/auditoria-criticos` permanece isolada, conforme solicitado.
