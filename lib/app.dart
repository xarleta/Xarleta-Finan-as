import 'package:flutter/material.dart';
import 'core/settings/settings_repository.dart';
import 'core/state/app_route_observer.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'services/app_lock_service.dart';

class XarletaFinancasApp extends StatefulWidget {
  const XarletaFinancasApp({super.key});

  @override
  State<XarletaFinancasApp> createState() => _XarletaFinancasAppState();
}

class _XarletaFinancasAppState extends State<XarletaFinancasApp> {
  final SettingsRepository _settingsRepository = SettingsRepository();

  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    ThemeMode themeMode = ThemeMode.system;
    try {
      themeMode = await _settingsRepository.themeMode();
    } catch (_) {
      // Mantém o tema do sistema se as preferências locais falharem.
    }

    if (!mounted) return;

    setState(() {
      _themeMode = themeMode;
      _loading = false;
    });
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });

    await _settingsRepository.saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xarleta Contador',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      // Permite que as telas com `DataChangeListenerMixin` saibam quando
      // voltam a ser a rota visível (ex.: após fechar um diálogo) e apliquem
      // recargas que ficaram pendentes enquanto estavam cobertas.
      navigatorObservers: [appRouteObserver],
      home: _loading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : AppLockGate(
              child: AppShell(
                themeMode: _themeMode,
                onThemeChanged: _changeTheme,
              ),
            ),
    );
  }
}
