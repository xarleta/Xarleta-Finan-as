import 'package:flutter_test/flutter_test.dart';
import 'package:xarleta_financas/services/notification_service.dart';

/// Testes de robustez do serviço de notificações.
///
/// Em plataformas sem implementação do plugin (ex.: desktop/testes), as
/// operações de notificação são efeitos secundários e NÃO podem lançar
/// exceção para o chamador — caso contrário, uma falha de notificação
/// interromperia operações principais já concluídas (ex.: pagar uma conta).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize não lança exceção quando o plugin não está disponível',
      () async {
    await expectLater(NotificationService.instance.initialize(), completes);
  });

  test('cancel não lança exceção quando o plugin não está disponível',
      () async {
    await expectLater(NotificationService.instance.cancel(123), completes);
  });

  test('scheduleBillReminder não lança exceção sem plugin disponível',
      () async {
    await expectLater(
      NotificationService.instance.scheduleBillReminder(
        id: 456,
        title: 'Teste',
        body: 'Corpo',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      ),
      completes,
    );
  });
}
