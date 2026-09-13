import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  const SettingsPage({super.key, required this.themeMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Configurações', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Aparência'),
          subtitle: Text(_themeLabel()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _chooseTheme(context),
        ),
      ),
      const Card(child: ListTile(leading: Icon(Icons.dashboard_customize_outlined), title: Text('Personalizar dashboard'))),
      const Card(child: ListTile(leading: Icon(Icons.category_outlined), title: Text('Editar categorias'))),
      const Card(child: ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Lembretes e notificações'))),
      const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('PIN e biometria'))),
      const Card(child: ListTile(leading: Icon(Icons.backup_outlined), title: Text('Backup e restauração'))),
      const Card(child: ListTile(leading: Icon(Icons.file_upload_outlined), title: Text('Exportar dados'))),
    ],
  );

  String _themeLabel() => switch (themeMode) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
    _ => 'Sistema',
  };

  Future<void> _chooseTheme(BuildContext context) async {
    final result = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('Sistema'), onTap: () => Navigator.pop(context, ThemeMode.system)),
        ListTile(title: const Text('Claro'), onTap: () => Navigator.pop(context, ThemeMode.light)),
        ListTile(title: const Text('Escuro'), onTap: () => Navigator.pop(context, ThemeMode.dark)),
      ])),
    );
    if (result != null) onThemeChanged(result);
  }
}

