import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../categories/categories_page.dart';
import 'data_management_page.dart';
import 'notification_settings_page.dart';
import 'security_settings_page.dart';

class SettingsPageV6 extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsPageV6({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  String _themeLabel() {
    return switch (themeMode) {
      ThemeMode.system => 'Sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
    };
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Configurações',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Aparência'),
              subtitle: Text(_themeLabel()),
              onTap: () => _themeDialog(context),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Lembretes e notificações'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Segurança e biometria'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SecuritySettingsPage(),
                ),
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Dados, backup e exportação'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DataManagementPage(),
                ),
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Inicializar notificações'),
              subtitle: const Text(
                'Necessário na primeira configuração',
              ),
              onTap: () async {
                await NotificationService.instance.initialize();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sistema de notificações inicializado.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          const Card(
            child: ListTile(
              leading: Icon(Icons.dashboard_customize_outlined),
              title: Text('Personalizar dashboard'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Editar categorias'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoriesPage(),
                ),
              ),
            ),
          ),
        ],
      );

  Future<void> _themeDialog(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sistema'),
              onTap: () => Navigator.pop(
                bottomSheetContext,
                ThemeMode.system,
              ),
            ),
            ListTile(
              title: const Text('Claro'),
              onTap: () => Navigator.pop(
                bottomSheetContext,
                ThemeMode.light,
              ),
            ),
            ListTile(
              title: const Text('Escuro'),
              onTap: () => Navigator.pop(
                bottomSheetContext,
                ThemeMode.dark,
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      onThemeChanged(selected);
    }
  }
}