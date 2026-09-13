import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  static final instance = SecurityService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Indica se há biometria **realmente utilizável** no aparelho.
  ///
  /// Não basta o dispositivo "suportar" biometria (`isDeviceSupported`): é
  /// preciso que exista ao menos uma biometria cadastrada. Caso contrário
  /// (ex.: Windows sem Windows Hello configurado), o app poderia se bloquear
  /// sem oferecer nenhuma forma de desbloqueio.
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Desbloqueie o Xarleta Finanças',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

