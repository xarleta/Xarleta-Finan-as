#!/usr/bin/env bash
# =============================================================================
# Executa a suíte de testes do Xarelta Finanças de forma estável.
#
# ## Por que este script existe
#
# O `flutter test` executa cada arquivo de teste em um isolate próprio, em
# paralelo, usando por padrão o número de núcleos lógicos da máquina como
# limite de concorrência. Em máquinas com muitos núcleos (ex.: 12), todos os
# arquivos de teste são iniciados simultaneamente.
#
# Cada isolate precisa carregar a biblioteca nativa do SQLite (`sqlite3.dll` no
# Windows, `libsqlite3.so` no Linux) na primeira chamada a `sqfliteFfiInit()`.
# Quando muitos isolates carregam a biblioteca nativa ao mesmo tempo, o
# carregamento concorre e o runner derruba isolates, produzindo falhas
# aleatórias como:
#
#     Failed to load "...": Connection closed before test suite loaded.
#     ... did not complete [E]
#
# Essas falhas não estão relacionadas à lógica dos testes: o mesmo teste passa
# ou falha de forma não determinística, e até arquivos de teste puramente Dart
# (sem SQLite) são afetados, o que comprova que a origem é o esgotamento de
# recursos do runner sob paralelismo máximo.
#
# ## O que este script faz
#
# Limita a concorrência a um valor que a máquina sustenta com folga. Os testes
# continuam executando em paralelo (não é `--concurrency=1`), apenas em uma
# quantidade que evita a corrida no carregamento da biblioteca nativa e o
# esgotamento de recursos do runner.
#
# O valor 2 foi escolhido empiricamente: com 4 ainda ocorreram falhas
# esporádicas de carregamento de isolate nesta máquina (12 núcleos lógicos),
# enquanto 2 se mostrou estável em execuções consecutivas da suíte completa.
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
