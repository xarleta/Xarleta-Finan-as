import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Estado da inicialização, para evitar corrida entre chamadas simultâneas.
  /// - `idle`: ainda não iniciada;
  /// - `initializing`: em andamento (guarda o Future compartilhado);
  /// - `initialized`: concluída com sucesso;
  /// - `failed`: falhou (não repete automaticamente).
  _InitState _state = _InitState.idle;
  Future<void>? _initFuture;

  static const _channel = AndroidNotificationChannel(
    'xarleta_financas_bills',
    'Lembretes de contas',
    description: 'Lembretes de vencimento e pagamentos',
    importance: Importance.high,
  );

  /// Indica se a inicialização das notificações foi concluída com sucesso.
  bool get isInitialized => _initialized;

  Future<void> initialize() {
    // Já concluída: nada a fazer.
    if (_state == _InitState.initialized) return Future.value();

    // Em andamento: reaproveita o Future compartilhado, evitando que duas
    // chamadas concorrentes executem a inicialização em paralelo.
    if (_state == _InitState.initializing && _initFuture != null) {
      return _initFuture!;
    }

    _state = _InitState.initializing;
    _initFuture = _doInitialize();
    return _initFuture!;
  }

  /// Tempo máximo aguardado pelas chamadas de plugin durante a inicialização.
  ///
  /// Em plataformas sem implementação do plugin (desktop, testes) ou com o
  /// canal de plataforma indisponível, as chamadas de método podem nunca
  /// responder. Sem um limite, o `await` ficaria pendurado indefinidamente e
  /// travaria quem aguarda a inicialização — inclusive o fluxo de pagamento de
  /// contas, que sincroniza lembretes. O timeout garante que a inicialização
  /// sempre conclua, marcando as notificações como indisponíveis.
  static const _initTimeout = Duration(seconds: 5);

  Future<void> _doInitialize() async {
    // A inicialização nunca deve lançar exceção para fora: falhas de
    // notificação (ex.: plataformas sem suporte a flutter_timezone) não
    // podem impedir o aplicativo de iniciar.
    try {
      tz.initializeTimeZones();

      try {
        final zone = await FlutterTimezone.getLocalTimezone()
            .timeout(_initTimeout);
        tz.setLocalLocation(tz.getLocation(zone));
      } catch (_) {
        // Mantém o fuso padrão do pacote timezone (UTC) quando a
        // plataforma não expõe o fuso local.
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ),
      );

      await _plugin.initialize(settings).timeout(_initTimeout);

      final android =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(_channel).timeout(_initTimeout);

      await android?.requestNotificationsPermission().timeout(_initTimeout);

      _initialized = true;
      _state = _InitState.initialized;
    } catch (_) {
      // Notificações ficam indisponíveis, mas o app continua funcional.
      _initialized = false;
      _state = _InitState.failed;
    }
  }

  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await initialize();

    // Plataformas sem implementação do plugin (ex.: desktop) não devem
    // propagar erro: o agendamento é um efeito secundário e não pode
    // interromper a operação principal (criar/editar conta).
    if (!_initialized) return;

    final when = tz.TZDateTime.from(
      scheduledAt,
      tz.local,
    );

    if (when.isBefore(
      tz.TZDateTime.now(tz.local),
    )) {
      return;
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'xarleta_financas_bills',
            'Lembretes de contas',
            channelDescription:
            'Lembretes de vencimento e pagamentos',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode:
        AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Falha ao agendar não deve interromper o fluxo principal.
    }
  }

  Future<void> cancel(int id) async {
    await initialize();

    // Sem inicialização bem-sucedida o plugin não está disponível
    // (ex.: desktop/testes); cancelar é um efeito secundário e não pode
    // lançar exceção para o chamador.
    if (!_initialized) return;

    try {
      await _plugin.cancel(id);
    } catch (_) {
      // Falha ao cancelar não deve interromper o fluxo principal.
    }
  }

  Future<void> showTest() async {
    await initialize();

    if (!_initialized) return;

    await _plugin.show(
      999999,
      'Xarleta Finanças',
      'Notificações estão funcionando.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'xarleta_financas_bills',
          'Lembretes de contas',
          importance: Importance.high,
        ),
      ),
    );
  }
}

/// Estados possíveis da inicialização das notificações.
enum _InitState { idle, initializing, initialized, failed }