import 'package:flutter/material.dart';
import '../../core/security/pin_repository.dart';
import '../../services/app_lock_service.dart';

class PinSettingsPage extends StatefulWidget {
  const PinSettingsPage({super.key});

  @override
  State<PinSettingsPage> createState() => _PinSettingsPageState();
}

class _PinSettingsPageState extends State<PinSettingsPage> {
  final _controller = TextEditingController();
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _enabled = await PinRepository.instance.isEnabled();
    } catch (e) {
      debugPrint('[PinSettingsPage] _load falhou: $e');
      _enabled = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await PinRepository.instance.save(_controller.text);
      if (!mounted) return;
      setState(() => _enabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN salvo.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// Desativa o PIN.
  ///
  /// Se a biometria também não estiver habilitada/utilizável, o app deixaria
  /// de ter qualquer forma de desbloqueio — o que é aceitável (o usuário
  /// optou por remover a proteção), mas avisamos para evitar surpresa.
  Future<void> _disable() async {
    try {
      await PinRepository.instance.disable();
      if (!mounted) return;
      setState(() => _enabled = false);

      final biometricsUsable =
          await AppLockService.instance.isBiometricsEnabled() &&
              await AppLockService.instance.isBiometricsAvailable();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            biometricsUsable
                ? 'PIN desativado. A biometria continua ativa.'
                : 'PIN desativado. O app não está mais protegido.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PinSettingsPage] _disable falhou: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível desativar o PIN.')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PIN do aplicativo')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _enabled
                    ? 'PIN ativado. Você pode alterar ou desativar.'
                    : 'Defina um PIN de 4 a 8 números.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              FilledButton(
                onPressed: _save,
                child: const Text('SALVAR PIN'),
              ),
              if (_enabled)
                OutlinedButton(
                  onPressed: _disable,
                  child: const Text('DESATIVAR'),
                ),
            ],
          ),
  );
}

