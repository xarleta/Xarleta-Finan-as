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

  static const _channel = AndroidNotificationChannel(
    'xarleta_financas_bills',
    'Lembretes de contas',
    description: 'Lembretes de vencimento e pagamentos',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    final zone = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(zone),
    );

    const settings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
    );

    await _plugin.initialize(settings);

    final android =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(_channel);

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await initialize();

    final when = tz.TZDateTime.from(
      scheduledAt,
      tz.local,
    );

    if (when.isBefore(
      tz.TZDateTime.now(tz.local),
    )) {
      return;
    }

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
  }

  Future<void> cancel(int id) async {
    await initialize();

    await _plugin.cancel(id);
  }

  Future<void> showTest() async {
    await initialize();

    await _plugin.show(
      999999,
      'Xarleta Finan�as',
      'Notifica��es est�o funcionando.',
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