// Patch de integração para o Dashboard principal.
//
// Regra:
// O Dashboard deve consultar FinanceAnalyticsRepository para:
// - saldo do período
// - ganhos
// - gastos
// - comparação
// - maior categoria
//
// Isso substitui valores fixos e evita cálculos duplicados.
//
// Para atualizar automaticamente após qualquer alteração,
// navegações que retornarem `true` devem chamar setState()
// ou utilizar um controlador global de estado na próxima refatoração.

