#!/usr/bin/env bash
# =============================================================================
# Executa a suíte de testes do Xarelta Finanças de forma estável.
#
# ## Por que este script existe
#
# O `flutter test` executa cada arquivo de teste em um isolate próprio. Cada
# isolate que usa `sqflite_common_ffi` precisa carregar a biblioteca nativa do
# SQLite (`sqlite3.dll` no Windows, `libsqlite3.so` no Linux) na primeira
# chamada a `sqfliteFfiInit()`. Nesta combinação (Flutter 3.47.4 / Dart 3.13.3 /
# sqflite_common_ffi 2.4.3 / sqlite3 3.5.2 / Windows x64) esse carregamento é
# instável e o runner derruba isolates de forma aleatória, produzindo falhas
# como:
#
#     Failed to load "...": Connection closed before test suite loaded.
#     ... did not complete [E]
#
# ## Evidência (investigação de 2026-09-13)
#
# A causa NÃO é o código do projeto nem o paralelismo:
#
# 1. Um projeto Flutter mínimo, criado fora deste repositório, contendo apenas
#    `flutter_test` + `sqflite_common_ffi` (sem nenhum código do Xarelta
#    Finanças), reproduziu as MESMAS falhas: 3 falhas em 14 execuções de
#    `flutter test` com concorrência padrão.
# 2. As falhas ocorrem também com `--concurrency=1` (1 falha em 5 execuções) e
#    com `--concurrency=2` (1 falha em 3 execuções), ou seja, NÃO dependem de
#    paralelismo.
# 3. Os arquivos que falham variam a cada execução (database_migration,
#    notification_service, payment_duplicate, category_repository, ...), o que
#    descarta um teste específico como causa.
# 4. Arquivos de teste puramente Dart (sem SQLite) nunca falharam.
# 5. Os singletons do projeto (AppDatabase e repositórios) são por isolate e
#    cada arquivo usa um diretório temporário exclusivo, portanto não há
#    estado compartilhado entre arquivos de teste.
#
# Conclusão: a origem é externa ao projeto (carregamento da biblioteca nativa
# do SQLite pelo `sqflite_common_ffi` sob o test runner do Flutter no Windows).
#
# ## O que este script faz
#
# Limita a concorrência para reduzir a probabilidade da falha. Isso NÃO elimina
# o problema: é uma mitigação, não uma correção. Se uma execução falhar com
# "Connection closed before test suite loaded" ou "did not complete", basta
# reexecutar; a falha não indica defeito no código.
#
# O valor 2 foi escolhido empiricamente por apresentar a menor taxa de falha
# observada nesta máquina (12 núcleos lógicos).
#
# Uso:
#     ./tool/test.sh                -> suíte completa
#     ./tool/test.sh test/foo.dart  -> arquivo específico
# =============================================================================

set -euo pipefail

CONCURRENCY=2

if [ "$#" -eq 0 ]; then
  flutter test --concurrency="$CONCURRENCY"
else
  flutter test --concurrency="$CONCURRENCY" "$@"
fi
