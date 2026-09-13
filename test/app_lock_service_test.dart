import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xarleta_financas/core/security/pin_repository.dart';
import 'package:xarleta_financas/services/app_lock_service.dart';

/// Testes da lógica de bloqueio do aplicativo.
///
/// Cobrem os cenários críticos relatados no bug de biometria:
/// - primeira execução não deve bloquear o app;
/// - biometria marcada como habilitada mas indisponível não pode criar
///   estado morto (sem forma de desbloqueio);
/// - PIN continua funcionando como fallback;
/// - a flag de biometria só é considerada quando o usuário a habilitou.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppLockService.isLockEnabled', () {
    test('sem PIN e sem biometria habilitada não bloqueia', () async {
      expect(await AppLockService.instance.isPinEnabled(), isFalse);
      expect(await AppLockService.instance.isBiometricsEnabled(), isFalse);
      expect(await AppLockService.instance.isLockEnabled(), isFalse);
    });

    test('com PIN habilitado bloqueia', () async {
      await PinRepository.instance.save('1234');

      expect(await AppLockService.instance.isLockEnabled(), isTrue);
    });

    test(
      'biometria habilitada mas indisponível não bloqueia (evita estado morto)',
      () async {
        // Simula o usuário que habilitou biometria em outro momento, mas o
        // aparelho não tem biometria utilizável agora (sem hardware/cadastro).
        await AppLockService.instance.setBiometricsEnabled(true);

        // Em ambiente de teste não há biometria real, então
        // isBiometricsAvailable() retorna false.
        expect(await AppLockService.instance.isBiometricsAvailable(), isFalse);
        expect(await AppLockService.instance.isLockEnabled(), isFalse);
        expect(await AppLockService.instance.hasUsableUnlockMethod(), isFalse);
      },
    );

    test('PIN habilitado mantém bloqueio mesmo sem biometria', () async {
      await PinRepository.instance.save('1234');
      await AppLockService.instance.setBiometricsEnabled(true);

      expect(await AppLockService.instance.isLockEnabled(), isTrue);
      expect(await AppLockService.instance.hasUsableUnlockMethod(), isTrue);
    });
  });

  group('AppLockService flag de biometria', () {
    test('flag começa desabilitada', () async {
      expect(await AppLockService.instance.isBiometricsEnabled(), isFalse);
    });

    test('flag é persistida ao habilitar', () async {
      await AppLockService.instance.setBiometricsEnabled(true);
      expect(await AppLockService.instance.isBiometricsEnabled(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('security_biometrics_enabled'), isTrue);
    });

    test('flag é removida ao desabilitar', () async {
      await AppLockService.instance.setBiometricsEnabled(true);
      await AppLockService.instance.setBiometricsEnabled(false);

      expect(await AppLockService.instance.isBiometricsEnabled(), isFalse);
    });
  });

  group('AppLockService desbloqueio com PIN', () {
    test('aceita o PIN correto', () async {
      await PinRepository.instance.save('4321');

      expect(await AppLockService.instance.unlockWithPin('4321'), isTrue);
    });

    test('rejeita o PIN incorreto', () async {
      await PinRepository.instance.save('4321');

      expect(await AppLockService.instance.unlockWithPin('0000'), isFalse);
    });
  });

  group('Recuperação de estado inconsistente', () {
    test(
      'estado antigo (biometria sem flag) não bloqueia o app',
      () async {
        // Antes da correção, a mera disponibilidade de biometria bloqueava o
        // app. Agora só a flag explícita do usuário conta. Sem flag e sem PIN,
        // o app deve abrir normalmente.
        SharedPreferences.setMockInitialValues({
          'security_pin_enabled': false,
        });

        expect(await AppLockService.instance.isLockEnabled(), isFalse);
      },
    );

    test(
      'PIN desabilitado mas ainda armazenado não bloqueia',
      () async {
        SharedPreferences.setMockInitialValues({
          'security_pin': 'pbkdf2\$120000\$salt\$hash',
          'security_pin_enabled': false,
        });

        expect(await AppLockService.instance.isPinEnabled(), isFalse);
        expect(await AppLockService.instance.isLockEnabled(), isFalse);
      },
    );
  });
}
