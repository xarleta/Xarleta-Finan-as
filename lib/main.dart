import 'package:flutter/material.dart';
import 'app.dart';
import 'core/database/database_platform.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  configureDatabaseFactory();

  await NotificationService.instance.initialize();

  runApp(const XarletaFinancasApp());
}
