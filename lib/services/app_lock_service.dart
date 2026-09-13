import 'package:flutter/material.dart';
import '../core/security/pin_repository.dart';
import 'security_service.dart';

class AppLockService {
  AppLockService._();
  static final instance = AppLockService._();

  Future<bool> isLockEnabled() async {
    return await PinRepository.instance.isEnabled() ||
        await SecurityService.instance.canUseBiometrics();
  }

  Future<bool> unlockWithPin(String pin) async {
    return PinRepository.instance.verify(pin);
  }

  Future<bool> unlockWithBiometrics() async {
    return SecurityService.instance.authenticate();
  }
}

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    bool pinEnabled = false;
    try {
      pinEnabled = await PinRepository.instance.isEnabled();
    } catch (_) {
      // Falhas na leitura do PIN não devem bloquear a inicialização.
    }
    if (mounted) {
      setState(() {
        _locked = pinEnabled;
        _checking = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _relock();
    }
  }

  Future<void> _relock() async {
    bool pinEnabled = false;
    try {
      pinEnabled = await PinRepository.instance.isEnabled();
    } catch (_) {
      return;
    }
    if (mounted && pinEnabled) setState(() => _locked = true);
  }

  Future<void> _unlockPin() async {
    final ok = await AppLockService.instance.unlockWithPin(_pin.text);
    if (mounted && ok) {
      _pin.clear();
      setState(() => _locked = false);
    }
  }

  Future<void> _unlockBiometric() async {
    final ok = await AppLockService.instance.unlockWithBiometrics();
    if (mounted && ok) setState(() => _locked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 52),
                  const SizedBox(height: 16),
                  const Text('Xarleta Finanças',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Digite seu PIN para continuar'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    autofocus: true,
                    onSubmitted: (_) => _unlockPin(),
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _unlockPin,
                      child: const Text('DESBLOQUEAR'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _unlockBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('USAR BIOMETRIA'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

