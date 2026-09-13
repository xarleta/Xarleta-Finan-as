import 'package:flutter/material.dart';
import '../../core/security/pin_repository.dart';

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
    } catch (_) {
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
                  onPressed: () async {
                    await PinRepository.instance.disable();
                    if (mounted) setState(() => _enabled = false);
                  },
                  child: const Text('DESATIVAR'),
                ),
            ],
          ),
  );
}

