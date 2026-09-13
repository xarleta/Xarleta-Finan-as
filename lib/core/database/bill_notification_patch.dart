// INTEGRAÇÃO OBRIGATÓRIA COM O CRUD DE CONTAS
//
// Ao criar/editar uma conta:
// 1. NotificationService.instance.cancel(billId)
// 2. calcular dueDate - reminderDays
// 3. NotificationService.instance.scheduleBillReminder(...)
//
// Ao marcar como paga:
// NotificationService.instance.cancel(billId)
//
// Ao excluir:
// NotificationService.instance.cancel(billId)
//
// Assim não existem notificações duplicadas ou lembretes de contas já pagas.

