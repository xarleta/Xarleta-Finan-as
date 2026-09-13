# Status de Desenvolvimento

## FUNCIONANDO

- Inicializacao Flutter, tema claro/escuro/sistema persistido e navegacao por
  barra inferior.
- Dashboard, hub de financas, atalhos de adicao e tela de analises.
- Ganhos e gastos; contas e vencimentos; parcelamentos; trabalho e entregas;
  metas; reservas; e categorias.
- Formularios com retorno para recarregar a lista de origem.
- Estados de carregamento, lista vazia, erro compreensivel e nova tentativa nas
  telas financeiras revisadas.
- Banco SQLite schema versao 8 e migracao de banco legado com preservacao de
  dados, coberta por teste automatizado.
- PIN e bloqueio do aplicativo; consulta e autenticacao biometrica conforme
  suporte do dispositivo.
- Backup JSON, restauracao transacional e exportacao CSV.
- Build Windows, incluindo SQLite via FFI (`sqlite3.dll`).

## CORRIGIDO

- Restaurado `AppLockGate` em `app.dart`, que havia deixado de envolver o
  shell durante a manutencao de persistencia de tema.
- Adicionada inicializacao SQLite FFI condicional para Windows/Linux; antes,
  o executavel Windows compilava mas nao possuia implementacao SQLite
  registrada.
- Adicionado teste da migracao de uma base versao 2 para a versao 8, com
  preservacao de transacao existente e verificacao de todas as tabelas.
- Adicionadas mensagens de erro e acao de nova tentativa em telas financeiras
  que antes exibiam somente o botao de recarga.

## PENDENTE

- Executar testes de interface automatizados que percorram visualmente todas
  as telas em Windows e em dispositivo Android/iOS.
- Validar em aparelhos reais as permissoes e entrega de notificacoes locais.
- Validar PIN e biometria em dispositivos com e sem hardware biometricamente
  compativel.
- Realizar cenarios manuais completos de backup/restauracao com arquivos reais
  e dados de volume representativo.
- Avaliar se telas e arquivos legados nao referenciados devem ser consolidados
  ou removidos em manutencao futura, depois de confirmar que nao sao usados.

## ATENCAO

- Nao reduzir a versao do banco. Novas alteracoes de schema devem incrementar
  a versao e usar migracoes cumulativas, nao destrutivas e testadas.
- `BackupService.restoreJson` substitui os dados atuais apos confirmacao; toda
  alteracao em tabelas deve atualizar a lista de backup e a validacao de
  restauracao.
- O SQLite FFI e configurado somente em Windows/Linux por importacao
  condicional. Nao substitua essa configuracao por importacao direta de
  `dart:io`, pois isso quebraria a compilacao web.
- A base local e dado do usuario: nunca deve ser versionada. O `.gitignore`
  cobre bancos, WAL/SHM e o diretorio de banco FFI de testes.
- Os diretorios `lib_backup_antes_correcao` e `lib_backup_codificacao` foram
  preservados no disco, mas sao ignorados pelo Git para evitar versionamento
  acidental de snapshots redundantes.
- O repositorio possui um commit inicial que registra o estado validado desta
  preparacao. Antes de novas alteracoes, use `git status` para confirmar os
  arquivos que serao incluidos no proximo commit.
