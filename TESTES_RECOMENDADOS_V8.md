# Testes obrigatórios antes do APK

## Cálculos
- 100 ganho e 40 gasto = saldo 60
- filtro mensal não inclui mês anterior
- comparação anterior usa mesmo tamanho de período

## Contas
- criar conta gera lembrete
- editar substitui lembrete
- pagar cancela lembrete
- excluir cancela lembrete

## Parcelamentos
- parcela paga aumenta contador
- não ultrapassa total
- restante nunca fica negativo

## Reservas
- depósito soma
- retirada não permite saldo negativo

## Backup
- JSON contém tabelas existentes
- restauração válida mantém integridade
- JSON inválido não apaga dados

## Segurança
- PIN aceita 4 a 8 números
- PIN errado falha
- PIN correto libera
