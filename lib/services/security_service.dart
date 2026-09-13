import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  static final instance = SecurityService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
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

