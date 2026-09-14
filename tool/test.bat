@echo off
REM ============================================================================
REM Executa a suite de testes do Xarelta Financas de forma estavel.
REM
REM ## Por que este script existe
REM
REM O `flutter test` executa cada arquivo de teste em um isolate proprio. Cada
REM isolate que usa `sqflite_common_ffi` precisa carregar a biblioteca nativa do
REM SQLite (`sqlite3.dll`) na primeira chamada a `sqfliteFfiInit()`. Nesta
REM combinacao (Flutter 3.47.4 / Dart 3.13.3 / sqflite_common_ffi 2.4.3 /
REM sqlite3 3.5.2 / Windows x64) esse carregamento e instavel e o runner derruba
REM isolates de forma aleatoria, produzindo falhas como:
REM
REM     Failed to load "...": Connection closed before test suite loaded.
REM     ... did not complete [E]
REM
REM ## Evidencia (investigacao de 2026-09-13)
REM
REM A causa NAO e o codigo do projeto nem o paralelismo:
REM
REM 1. Um projeto Flutter minimo, criado fora deste repositorio, contendo apenas
REM    `flutter_test` + `sqflite_common_ffi` (sem nenhum codigo do Xarelta
REM    Financas), reproduziu as MESMAS falhas: 3 falhas em 14 execucoes de
REM    `flutter test` com concorrencia padrao.
REM 2. As falhas ocorrem tambem com `--concurrency=1` (1 falha em 5 execucoes) e
REM    com `--concurrency=2` (1 falha em 3 execucoes), ou seja, NAO dependem de
REM    paralelismo.
REM 3. Os arquivos que falham variam a cada execucao (database_migration,
REM    notification_service, payment_duplicate, category_repository, ...), o que
REM    descarta um teste especifico como causa.
REM 4. Arquivos de teste puramente Dart (sem SQLite) nunca falharam.
REM 5. Os singletons do projeto (AppDatabase e repositorios) sao por isolate e
REM    cada arquivo usa um diretorio temporario exclusivo, portanto nao ha
REM    estado compartilhado entre arquivos de teste.
REM
REM Conclusao: a origem e externa ao projeto (carregamento da biblioteca nativa
REM do SQLite pelo `sqflite_common_ffi` sob o test runner do Flutter no Windows).
REM
REM ## O que este script faz
REM
REM Limita a concorrencia para reduzir a probabilidade da falha. Isso NAO
REM elimina o problema: e uma mitigacao, nao uma correcao. Se uma execucao
REM falhar com "Connection closed before test suite loaded" ou "did not
REM complete", basta reexecutar; a falha nao indica defeito no codigo.
REM
REM O valor 2 foi escolhido empiricamente por apresentar a menor taxa de falha
REM observada nesta maquina (12 nucleos logicos).
REM
REM Uso:
REM     tool\test.bat              -> suite completa
REM     tool\test.bat test\foo.dart -> arquivo especifico
REM ============================================================================

setlocal

set CONCURRENCY=2

if "%~1"=="" (
  flutter test --concurrency=%CONCURRENCY%
) else (
  flutter test --concurrency=%CONCURRENCY% %*
)

exit /b %ERRORLEVEL%
