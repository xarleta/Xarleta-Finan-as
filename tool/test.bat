@echo off
REM ============================================================================
REM Executa a suite de testes do Xarelta Financas de forma estavel.
REM
REM ## Por que este script existe
REM
REM O `flutter test` executa cada arquivo de teste em um isolate proprio, em
REM paralelo, usando por padrao o numero de nucleos logicos da maquina como
REM limite de concorrencia. Em maquinas com muitos nucleos (ex.: 12), todos os
REM arquivos de teste sao iniciados simultaneamente.
REM
REM Cada isolate precisa carregar a biblioteca nativa do SQLite (`sqlite3.dll`)
REM na primeira chamada a `sqfliteFfiInit()`. Quando muitos isolates carregam a
REM biblioteca nativa ao mesmo tempo, o carregamento concorre e o runner derruba
REM isolates, produzindo falhas aleatorias como:
REM
REM     Failed to load "...": Connection closed before test suite loaded.
REM     ... did not complete [E]
REM
REM Essas falhas nao estao relacionadas a logica dos testes: o mesmo teste passa
REM ou falha de forma nao deterministica, e ate arquivos de teste puramente Dart
REM (sem SQLite) sao afetados, o que comprova que a origem e o esgotamento de
REM recursos do runner sob paralelismo maximo.
REM
REM ## O que este script faz
REM
REM Limita a concorrencia a um valor que a maquina sustenta com folga. Os testes
REM continuam executando em paralelo (nao e `--concurrency=1`), apenas em uma
REM quantidade que evita a corrida no carregamento da biblioteca nativa e o
REM esgotamento de recursos do runner.
REM
REM O valor 2 foi escolhido empiricamente: com 4 ainda ocorreram falhas
REM esporadicas de carregamento de isolate nesta maquina (12 nucleos logicos),
REM enquanto 2 se mostrou estavel em execucoes consecutivas da suite completa.
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
