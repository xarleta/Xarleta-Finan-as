import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'core/database/database_platform.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  configureDatabaseFactory();

  // A inicialização das notificações é disparada sem bloquear o runApp.
  // Falhas de notificação não podem impedir o aplicativo de iniciar.
  unawaited(NotificationService.instance.initialize());

  runApp(const XarletaFinancasApp());
}
