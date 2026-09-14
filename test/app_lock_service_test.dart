import 'package:flutter/material.dart';
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

  group('AppLockGate — cenários de desbloqueio (BUG 5)', () {
    /// Aguarda a resolução do `_load()` assíncrono do gate.
    ///
    /// Não é possível usar `pumpAndSettle` porque, enquanto `_checking` é
    /// `true`, o gate exibe um `CircularProgressIndicator` — uma animação
    /// contínua que nunca "assenta". Além disso, `_load()` aguarda `Future`s
    /// reais de `SharedPreferences` (canal de plataforma mockado), que só
    /// progridem dentro de `tester.runAsync`. Por isso: executa os `Future`s
    /// reais em `runAsync` e depois bombeia um frame para aplicar o `setState`.
    Future<void> settleGate(WidgetTester tester) async {
      await tester.runAsync(() async {
        // Dá tempo para os `Future`s de SharedPreferences/PinRepository
        // concluírem no isolate real.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'cenário 1: sem PIN e sem biometria entra normalmente',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          const MaterialApp(
            home: AppLockGate(child: Text('conteúdo do app')),
          ),
        );
        await settleGate(tester);

        expect(find.text('conteúdo do app'), findsOneWidget);
        expect(find.text('USAR BIOMETRIA'), findsNothing);
        expect(find.text('DESBLOQUEAR'), findsNothing);
      },
    );

    testWidgets(
      'cenário 2: PIN habilitado e biometria desligada pede o PIN',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PinRepository.instance.save('1234');

        await tester.pumpWidget(
          const MaterialApp(
            home: AppLockGate(child: Text('conteúdo do app')),
          ),
        );
        await settleGate(tester);

        // Bloqueado: mostra o campo de PIN e não mostra biometria.
        expect(find.text('conteúdo do app'), findsNothing);
        expect(find.text('DESBLOQUEAR'), findsOneWidget);
        expect(find.text('USAR BIOMETRIA'), findsNothing);

        // PIN correto desbloqueia.
        await tester.enterText(find.byType(TextField), '1234');
        await tester.tap(find.text('DESBLOQUEAR'));
        await settleGate(tester);

        expect(find.text('conteúdo do app'), findsOneWidget);
      },
    );

    testWidgets(
      'cenário 2: PIN incorreto mantém o bloqueio',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PinRepository.instance.save('1234');

        await tester.pumpWidget(
          const MaterialApp(
            home: AppLockGate(child: Text('conteúdo do app')),
          ),
        );
        await settleGate(tester);

        await tester.enterText(find.byType(TextField), '0000');
        await tester.tap(find.text('DESBLOQUEAR'));
        await settleGate(tester);

        expect(find.text('conteúdo do app'), findsNothing);
        expect(find.text('DESBLOQUEAR'), findsOneWidget);
      },
    );

    testWidgets(
      'cenário 3: PIN + biometria habilitada mantém uma saída utilizável '
      '(sem estado morto)',
      (tester) async {
        // Em ambiente de teste não há biometria real, então o cenário 3 puro
        // (biometria disponível) não pode ser exercitado de ponta a ponta.
        // O que é verificável aqui é o estado de fallback: com PIN habilitado,
        // o usuário sempre tem uma saída e nunca fica preso.
        SharedPreferences.setMockInitialValues({});
        await PinRepository.instance.save('1234');
        await AppLockService.instance.setBiometricsEnabled(true);

        await tester.pumpWidget(
          const MaterialApp(
            home: AppLockGate(child: Text('conteúdo do app')),
          ),
        );
        await settleGate(tester);

        // Biometria indisponível no ambiente de teste → cai no PIN, que é a
        // forma utilizável. O app não fica em estado morto.
        expect(find.text('conteúdo do app'), findsNothing);
        expect(find.text('DESBLOQUEAR'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '1234');
        await tester.tap(find.text('DESBLOQUEAR'));
        await settleGate(tester);

        expect(find.text('conteúdo do app'), findsOneWidget);
      },
    );
  });
}
