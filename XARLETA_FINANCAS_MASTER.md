# XARLETA FINANÇAS — DOCUMENTO MESTRE DO PROJETO

## 1. Objetivo

Aplicativo pessoal de controle financeiro para uso no próprio celular Android, sem necessidade de Play Store. O foco é simplicidade, velocidade, funcionamento offline e edição de qualquer dado.

## 2. Nome

Xarleta Finanças

## 3. Princípios

- Interface limpa
- Pouca poluição visual
- Navegação didática
- Dados locais
- Funcionamento offline
- Edição e exclusão de registros
- Cálculos centralizados
- Leve para celular

## 4. Módulos

### Dashboard
- Saldo
- Ganhos
- Gastos
- Visão rápida

### Ganhos e gastos
- Cadastro
- Edição
- Exclusão
- Busca
- Filtros
- Categorias

### Contas e vencimentos
- Valor
- Vencimento
- Categoria
- Lembrete
- Recorrência
- Marcar como paga

### Parcelamentos
- Compra
- Valor total
- Valor da parcela
- Total de parcelas
- Pagas
- Restantes
- Próximo vencimento

### Trabalho e entregas
- Atividade
- Ganhos
- Gastos
- Horas
- Quilometragem
- Lucro líquido
- R$/hora

### Metas
- Nome
- Valor alvo
- Prazo
- Progresso
- Aportes

### Reservas
- Nome
- Saldo
- Adicionar
- Retirar
- Histórico

### Categorias
- Ganhos
- Gastos
- Categorias padrão
- Personalização

### Análises
- Hoje
- Semana
- Mês
- Ano
- Personalizado
- Comparação com período anterior
- Ganhos x gastos
- Gastos por categoria
- Média diária
- Maior categoria de gasto

### Notificações
- Lembrete de contas
- Canal Android
- Teste
- Cancelamento ao pagar ou excluir

### Segurança
- Biometria
- Estrutura para PIN persistente

### Dados
- Backup JSON
- Motor de restauração
- Exportação CSV
- Compartilhamento

### Configurações
- Tema sistema
- Tema claro
- Tema escuro
- Notificações
- Segurança
- Backup
- Exportação
- Categorias

## 5. Banco de dados

Tabelas:
- transactions
- bills
- installments
- work_sessions
- goals
- reserves
- categories
- goal_contributions
- reserve_movements
- app_settings

## 6. Regras críticas

1. Todos os cálculos de análise devem usar o mesmo repositório.
2. Conta paga não pode manter lembrete ativo.
3. Conta excluída deve cancelar o lembrete.
4. Conta editada deve substituir o lembrete anterior.
5. Backup não deve apagar dados antes da validação.
6. Restauração deve usar transação.
7. Valores financeiros não devem ser duplicados em telas diferentes.
8. Todo lançamento deve poder ser corrigido.

## 7. Arquitetura

Flutter + SQLite.

Estrutura:
- core
- features
- services

Serviços:
- NotificationService
- BillReminderService
- SecurityService
- BackupService
- ExportService

## 8. Dependências

- sqflite
- intl
- shared_preferences
- flutter_local_notifications
- timezone
- flutter_timezone
- local_auth
- csv
- fl_chart
- share_plus

## 9. Status consolidado

Implementado ou presente:
- Base offline
- Transações
- Trabalho
- Contas
- Parcelamentos
- Metas
- Reservas
- Categorias
- Análises
- Notificações
- Backup
- Exportação
- Biometria
- Configurações

Pendente para fechamento definitivo:
- PIN persistente
- Seleção de arquivo para restauração
- Integração completa do BillReminderService em todos os pontos do CRUD
- Teste em aparelho Android real
- Revisão de todos os fluxos
- Geração do APK release

## 10. Próxima fase correta

A próxima fase não é adicionar novos módulos. É testar e fechar:
1. Compilação
2. Erros do analyzer
3. CRUD
4. Banco
5. Cálculos
6. Notificações
7. Backup
8. Restauração
9. Segurança
10. APK


## 11. V8 — Auditoria

Foi feita validação estrutural. O Flutter SDK não estava disponível neste ambiente, portanto compilação e APK continuam pendentes de teste real.

PIN persistente foi adicionado nesta versão como base. Integração de bloqueio na abertura e restauração por seleção de arquivo continuam como fechamento técnico.


## 12. V9 — Fechamento das integrações

Adicionado:
- Bloqueio na abertura do aplicativo
- Relock quando o aplicativo vai para segundo plano
- PIN persistente
- Biometria
- Seleção de backup JSON
- Confirmação de restauração
- Validação antes de apagar dados
- Backup de todas as tabelas principais
- Preparação para APK

Pendente exclusivamente de validação externa:
- Flutter analyze
- Flutter test
- teste Android real
- geração do APK


## 13. V10 — Integração real do código

Correções aplicadas diretamente no código:
- BillRepository agora sincroniza lembretes ao criar e editar.
- Marcar conta como paga cancela o lembrete.
- Excluir conta cancela o lembrete.
- Conta recorrente paga gera próxima conta e agenda novo lembrete.
- Restaurar backup agora está acessível pela interface real.
- PIN está acessível pela tela real de segurança.
- Inicialização de notificações foi tornada idempotente.
- Arquivos de patch não integrados foram removidos para reduzir confusão.

Status:
A próxima etapa obrigatória continua sendo compilar em Flutter/Android real.


## 14. V11 — Auditoria estática pré-compilação

Foi executada uma auditoria estática de:
- arquivos Dart
- imports relativos
- duplicidade de nomes de classes

Essa etapa não substitui o compilador Flutter.

Fluxo final obrigatório:
1. flutter pub get
2. dart format .
3. flutter analyze
4. flutter test
5. flutter run
6. flutter build apk --release


## 15. V12 — Auditoria semântica pré-Flutter

Verificado:
- pacotes importados contra pubspec
- arquivos críticos
- contrato básico entre BillRepository e BillModel
- artefatos de patches anteriores

Resultado da auditoria:
- nenhum pacote importado sem dependência declarada
- nenhum arquivo crítico ausente
- nenhuma inconsistência óbvia detectada no contrato básico de contas

A compilação real continua sendo a etapa final obrigatória.
