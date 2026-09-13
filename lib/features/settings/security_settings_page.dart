import 'package:flutter/material.dart';
import '../../services/security_service.dart';
import 'pin_settings_page.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool? _available;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await SecurityService.instance.canUseBiometrics();
    if (mounted) setState(() => _available = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Segurança')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('PIN do aplicativo'),
            subtitle: const Text('Criar, alterar ou desativar PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PinSettingsPage()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometria'),
            subtitle: Text(
              _available == null
                  ? 'Verificando disponibilidade...'
                  : (_available! ? 'Disponível neste aparelho' : 'Não disponível'),
            ),
            onTap: _available == true
                ? () async {
                    final ok = await SecurityService.instance.authenticate();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Autenticação realizada.' : 'Autenticação não concluída.',
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
      ],
    ),
  );
}

