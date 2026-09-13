import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lembretes e notificações')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Testar notificação'),
            subtitle: const Text('Confirma se o aparelho permite os alertas'),
            trailing: FilledButton(
              onPressed: () async {
                await NotificationService.instance.showTest();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificação de teste enviada.')),
                  );
                }
              },
              child: const Text('TESTAR'),
            ),
          ),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cada conta cadastrada deve usar reminder_days para agendar um alerta antes do vencimento. '
              'Ao editar ou pagar a conta, o lembrete anterior deve ser cancelado.',
            ),
          ),
        ),
      ],
    ),
  );
}

