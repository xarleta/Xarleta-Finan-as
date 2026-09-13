import 'package:flutter/material.dart';
import '../core/security/pin_repository.dart';
import 'security_service.dart';

/// Estado de bloqueio do aplicativo.
///
/// O bloqueio é considerado ativo quando o PIN está habilitado **ou** quando
/// a biometria está disponível no aparelho. Isso garante que usuários que
/// habilitaram apenas a biometria também tenham o app protegido.
class AppLockService {
  AppLockService._();
  static final instance = AppLockService._();

  Future<bool> isPinEnabled() async {
    try {
      return await PinRepository.instance.isEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      return await SecurityService.instance.canUseBiometrics();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLockEnabled() async {
    if (await isPinEnabled()) return true;
    return isBiometricsAvailable();
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
  bool _pinEnabled = false;
  bool _biometricsAvailable = false;
  bool _unlocking = false;
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final pinEnabled = await AppLockService.instance.isPinEnabled();
    final biometrics = await AppLockService.instance.isBiometricsAvailable();

    if (mounted) {
      setState(() {
        _pinEnabled = pinEnabled;
        _biometricsAvailable = biometrics;
        _locked = pinEnabled || biometrics;
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
    // Evita re-bloquear enquanto uma autenticação está em andamento,
    // prevenindo loops de bloqueio durante o diálogo biométrico.
    if (_unlocking) return;

    final enabled = await AppLockService.instance.isLockEnabled();
    if (mounted && enabled) setState(() => _locked = true);
  }

  Future<void> _unlockPin() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      final ok = await AppLockService.instance.unlockWithPin(_pin.text);
      if (!mounted) return;
      if (ok) {
        _pin.clear();
        setState(() => _locked = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorreto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _unlockBiometric() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      final ok = await AppLockService.instance.unlockWithBiometrics();
      if (mounted && ok) setState(() => _locked = false);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
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
                  Text(
                    _pinEnabled
                        ? 'Digite seu PIN para continuar'
                        : 'Confirme sua identidade para continuar',
                  ),
                  const SizedBox(height: 20),
                  if (_pinEnabled) ...[
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
                        onPressed: _unlocking ? null : _unlockPin,
                        child: const Text('DESBLOQUEAR'),
                      ),
                    ),
                  ],
                  if (_biometricsAvailable) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _unlocking ? null : _unlockBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('USAR BIOMETRIA'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
