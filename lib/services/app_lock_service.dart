import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/pin_repository.dart';
import 'security_service.dart';

/// Estado de bloqueio do aplicativo.
///
/// O bloqueio só é considerado ativo quando o **usuário** configurou
/// explicitamente uma forma de proteção:
/// - PIN habilitado; ou
/// - biometria habilitada pelo usuário (flag persistida).
///
/// A mera disponibilidade de biometria no aparelho **não** bloqueia o app.
/// Isso evita que a primeira execução em um aparelho com biometria cadastrada
/// prenda o usuário em uma tela de bloqueio sem nenhuma forma de desbloqueio.
class AppLockService {
  AppLockService._();
  static final instance = AppLockService._();

  /// Flag persistida que indica que o usuário habilitou a biometria.
  static const _biometricsEnabledKey = 'security_biometrics_enabled';

  Future<bool> isPinEnabled() async {
    try {
      return await PinRepository.instance.isEnabled();
    } catch (e) {
      _log('isPinEnabled falhou: $e');
      return false;
    }
  }

  /// Indica se a biometria está disponível **e utilizável** no aparelho.
  Future<bool> isBiometricsAvailable() async {
    try {
      return await SecurityService.instance.canUseBiometrics();
    } catch (e) {
      _log('isBiometricsAvailable falhou: $e');
      return false;
    }
  }

  /// Indica se o usuário habilitou a biometria nas configurações.
  Future<bool> isBiometricsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricsEnabledKey) ?? false;
    } catch (e) {
      _log('isBiometricsEnabled falhou: $e');
      return false;
    }
  }

  /// Persiste a preferência do usuário sobre a biometria.
  ///
  /// Só deve ser chamado **após** validar que a biometria está disponível e
  /// que uma autenticação real foi concluída com sucesso.
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsEnabledKey, enabled);
  }

  /// Indica se o bloqueio deve estar ativo.
  ///
  /// Considera apenas configurações feitas pelo usuário. Se a biometria foi
  /// habilitada mas deixou de estar disponível (biometrias removidas do
  /// aparelho), ela não conta como proteção válida — evitando estado morto.
  Future<bool> isLockEnabled() async {
    if (await isPinEnabled()) return true;
    if (!await isBiometricsEnabled()) return false;
    return isBiometricsAvailable();
  }

  /// Indica se existe alguma forma de desbloqueio utilizável.
  ///
  /// Usado para impedir que o app entre em um estado sem saída.
  Future<bool> hasUsableUnlockMethod() async {
    if (await isPinEnabled()) return true;
    if (!await isBiometricsEnabled()) return false;
    return isBiometricsAvailable();
  }

  Future<bool> unlockWithPin(String pin) async {
    return PinRepository.instance.verify(pin);
  }

  Future<BiometricResult> unlockWithBiometrics() async {
    return SecurityService.instance.authenticateDetailed();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AppLockService] $message');
    }
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
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _unlocking = false;

  /// `true` quando o usuário pediu explicitamente para usar o PIN (após a
  /// biometria falhar/cancelar). Enquanto `false` e a biometria estiver
  /// habilitada, a tela mostra apenas o botão de biometria e dispara a
  /// autenticação automaticamente, sem exigir o PIN primeiro.
  bool _usePinFallback = false;

  /// Evita disparar a biometria automática mais de uma vez por bloqueio.
  bool _biometricPrompted = false;

  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final pinEnabled = await AppLockService.instance.isPinEnabled();
    final biometricsEnabled =
        await AppLockService.instance.isBiometricsEnabled();
    final biometricsAvailable =
        await AppLockService.instance.isBiometricsAvailable();

    // Só bloqueia se houver uma forma de desbloqueio realmente utilizável.
    // Se a biometria foi habilitada mas não está mais disponível e não há PIN,
    // o app abre normalmente em vez de prender o usuário.
    final hasUsableUnlock =
        pinEnabled || (biometricsEnabled && biometricsAvailable);

    if (!mounted) return;

    setState(() {
      _pinEnabled = pinEnabled;
      _biometricsEnabled = biometricsEnabled;
      _biometricsAvailable = biometricsAvailable;
      _locked = hasUsableUnlock;
      _checking = false;
      // Ao (re)bloquear, volta ao estado inicial: biometria primeiro (quando
      // habilitada), PIN apenas como fallback explícito.
      _usePinFallback = false;
      _biometricPrompted = false;
    });

    // Cenário 3: PIN + biometria habilitados → pede a biometria diretamente,
    // sem exigir o PIN antes. O disparo é feito após o primeiro frame para
    // que o diálogo nativo apareça sobre a tela já montada. A flag
    // `_biometricPrompted` impede disparos repetidos caso `_load` seja
    // chamado mais de uma vez sem que o bloqueio tenha sido resolvido.
    if (hasUsableUnlock && biometricsEnabled && biometricsAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _locked && !_biometricPrompted) _unlockBiometric();
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
        _showMessage('PIN incorreto.');
      }
    } catch (e) {
      if (mounted) _showMessage('Não foi possível validar o PIN.');
      debugPrint('[AppLockGate] _unlockPin erro: $e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _unlockBiometric() async {
    if (_unlocking) return;
    _biometricPrompted = true;
    setState(() => _unlocking = true);
    try {
      final result = await AppLockService.instance.unlockWithBiometrics();
      if (!mounted) return;

      switch (result) {
        case BiometricResult.success:
          setState(() => _locked = false);
          break;
        case BiometricResult.failed:
          // Biometria cancelada/recusada: não insiste em loop. Libera o
          // fallback para PIN (quando existir) e informa o usuário.
          setState(() {
            _usePinFallback = true;
            _biometricPrompted = false;
          });
          _showMessage(
            _pinEnabled
                ? 'Autenticação não concluída. Use o PIN para continuar.'
                : 'Autenticação não concluída. Tente novamente.',
          );
          break;
        case BiometricResult.unavailable:
          setState(() {
            _biometricsAvailable = false;
            _usePinFallback = true;
            _biometricPrompted = false;
          });
          _showMessage(
            'Biometria indisponível neste aparelho. Use o PIN para continuar.',
          );
          break;
        case BiometricResult.error:
          setState(() {
            _usePinFallback = true;
            _biometricPrompted = false;
          });
          _showMessage(
            _pinEnabled
                ? 'Não foi possível usar a biometria. Use o PIN para continuar.'
                : 'Não foi possível usar a biometria. Tente novamente.',
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usePinFallback = true;
          _biometricPrompted = false;
        });
        _showMessage('Não foi possível usar a biometria.');
      }
      debugPrint('[AppLockGate] _unlockBiometric erro: $e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

    final showBiometrics = _biometricsEnabled && _biometricsAvailable;

    // Cenário 3: biometria habilitada e disponível → mostra a opção de
    // biometria em destaque (disparada automaticamente em `_load`). O campo de
    // PIN só aparece quando o usuário pede o fallback ou quando não há
    // biometria utilizável.
    final showPinField = _pinEnabled && (!showBiometrics || _usePinFallback);

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
                    showPinField
                        ? 'Digite seu PIN para continuar'
                        : 'Confirme sua identidade para continuar',
                  ),
                  const SizedBox(height: 20),
                  if (showBiometrics) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _unlocking ? null : _unlockBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('USAR BIOMETRIA'),
                      ),
                    ),
                  ],
                  if (showPinField) ...[
                    if (showBiometrics) const SizedBox(height: 16),
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
                  // Fallback explícito: com biometria em destaque, oferece a
                  // opção de usar o PIN sem forçar um loop de biometria.
                  if (showBiometrics && _pinEnabled && !_usePinFallback) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _unlocking
                          ? null
                          : () => setState(() => _usePinFallback = true),
                      child: const Text('USAR PIN'),
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
