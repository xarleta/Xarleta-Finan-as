import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Resultado de uma tentativa de autenticação biométrica.
///
/// Diferencia os cenários que antes eram todos colapsados em `false`,
/// permitindo que a UI ofereça o fallback correto em cada caso.
enum BiometricResult {
  /// Autenticação concluída com sucesso.
  success,

  /// O usuário cancelou o diálogo ou a autenticação não foi aceita.
  failed,

  /// Não há biometria utilizável (sem hardware, sem cadastro ou plugin
  /// indisponível). Não deve ser tratado como falha do usuário.
  unavailable,

  /// Ocorreu um erro inesperado na plataforma.
  error,
}

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
    } on PlatformException catch (e) {
      _log('canUseBiometrics falhou: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      _log('canUseBiometrics erro inesperado: $e');
      return false;
    }
  }

  /// Executa a autenticação biométrica real e informa o desfecho.
  ///
  /// Nunca engole exceções: erros de plataforma são registrados em debug e
  /// convertidos em [BiometricResult.error] / [BiometricResult.unavailable]
  /// para que a UI possa reagir (mensagem, fallback para PIN, etc.).
  Future<BiometricResult> authenticateDetailed() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Desbloqueie o Xarleta Finanças',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      _log('authenticate falhou: ${e.code} ${e.message}');
      // Códigos que indicam indisponibilidade real de biometria.
      const unavailableCodes = {
        'NotAvailable',
        'NotEnrolled',
        'NoBiometricHardware',
        'NoCredentials',
        'PasscodeNotSet',
      };
      if (unavailableCodes.contains(e.code)) {
        return BiometricResult.unavailable;
      }
      return BiometricResult.error;
    } catch (e) {
      _log('authenticate erro inesperado: $e');
      return BiometricResult.error;
    }
  }

  /// Compatibilidade: retorna `true` apenas em caso de sucesso.
  Future<bool> authenticate() async {
    final result = await authenticateDetailed();
    return result == BiometricResult.success;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SecurityService] $message');
    }
  }
}
