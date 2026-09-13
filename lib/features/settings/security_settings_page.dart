import 'package:flutter/material.dart';
import '../../services/app_lock_service.dart';
import '../../services/security_service.dart';
import 'pin_settings_page.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool? _available;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await SecurityService.instance.canUseBiometrics();
    final enabled = await AppLockService.instance.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        // Se a biometria foi habilitada mas não está mais disponível,
        // reflete o estado real para não induzir o usuário a erro.
        _enabled = enabled && available;
      });
    }
  }

  /// Habilita a biometria somente após uma autenticação real bem-sucedida.
  Future<void> _enableBiometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await SecurityService.instance.authenticateDetailed();
      if (!mounted) return;

      switch (result) {
        case BiometricResult.success:
          await AppLockService.instance.setBiometricsEnabled(true);
          if (!mounted) return;
          setState(() => _enabled = true);
          _showMessage('Biometria ativada.');
          break;
        case BiometricResult.failed:
          _showMessage('Autenticação não concluída. Biometria não ativada.');
          break;
        case BiometricResult.unavailable:
          _showMessage('Biometria indisponível neste aparelho.');
          setState(() => _available = false);
          break;
        case BiometricResult.error:
          _showMessage('Não foi possível ativar a biometria.');
          break;
      }
    } catch (e) {
      if (mounted) _showMessage('Não foi possível ativar a biometria.');
      debugPrint('[SecuritySettingsPage] _enableBiometrics erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableBiometrics() async {
    await AppLockService.instance.setBiometricsEnabled(false);
    if (mounted) {
      setState(() => _enabled = false);
      _showMessage('Biometria desativada.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          child: SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometria'),
            subtitle: Text(
              _available == null
                  ? 'Verificando disponibilidade...'
                  : (!_available!
                      ? 'Não disponível neste aparelho'
                      : (_enabled
                          ? 'Ativada — usada para desbloquear o app'
                          : 'Disponível — toque para ativar')),
            ),
            value: _enabled,
            onChanged: (_available != true || _busy)
                ? null
                : (value) {
                    if (value) {
                      _enableBiometrics();
                    } else {
                      _disableBiometrics();
                    }
                  },
          ),
        ),
      ],
    ),
  );
}
