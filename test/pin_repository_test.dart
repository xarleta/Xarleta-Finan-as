import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xarleta_financas/core/security/pin_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('salva o PIN sem armazenar o valor em texto puro', () async {
    await PinRepository.instance.save('1234');

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('security_pin');

    expect(stored, isNotNull);
    expect(stored, isNot('1234'));
    expect(stored, startsWith('pbkdf2\$'));
    expect(prefs.getString('security_pin_salt'), isNotEmpty);
    expect(await PinRepository.instance.isEnabled(), isTrue);
    expect(await PinRepository.instance.hasPin(), isTrue);
  });

  test('verifica o PIN correto e rejeita o incorreto', () async {
    await PinRepository.instance.save('4321');

    expect(await PinRepository.instance.verify('4321'), isTrue);
    expect(await PinRepository.instance.verify('0000'), isFalse);
  });

  test('rejeita PIN fora do formato esperado', () async {
    expect(
      () => PinRepository.instance.save('12'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => PinRepository.instance.save('abcdef'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => PinRepository.instance.save('123456789'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('migra PIN legado em texto puro na primeira verificacao', () async {
    SharedPreferences.setMockInitialValues({
      'security_pin': '9876',
      'security_pin_enabled': true,
    });

    expect(await PinRepository.instance.verify('9876'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('security_pin'), isNot('9876'));
    expect(prefs.getString('security_pin'), startsWith('pbkdf2\$'));
    expect(prefs.getString('security_pin_salt'), isNotEmpty);
    expect(await PinRepository.instance.verify('9876'), isTrue);
  });

  test('rejeita PIN incorreto no formato legado sem migrar', () async {
    SharedPreferences.setMockInitialValues({
      'security_pin': '9876',
      'security_pin_enabled': true,
    });

    expect(await PinRepository.instance.verify('0000'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('security_pin'), '9876');
  });

  test('verifica e migra o formato intermediario SHA-256 com salt', () async {
    const pin = '2468';
    const salt = 'salt-fixo-de-teste';
    final sha = sha256.convert(utf8.encode('$salt:$pin')).toString();

    SharedPreferences.setMockInitialValues({
      'security_pin': sha,
      'security_pin_salt': salt,
      'security_pin_enabled': true,
    });

    expect(await PinRepository.instance.verify(pin), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('security_pin');
    expect(stored, isNot(sha));
    expect(stored, startsWith('pbkdf2\$'));
    expect(await PinRepository.instance.verify(pin), isTrue);
  });

  test('rejeita PIN incorreto no formato SHA-256 sem migrar', () async {
    const pin = '2468';
    const salt = 'salt-fixo-de-teste';
    final sha = sha256.convert(utf8.encode('$salt:$pin')).toString();

    SharedPreferences.setMockInitialValues({
      'security_pin': sha,
      'security_pin_salt': salt,
      'security_pin_enabled': true,
    });

    expect(await PinRepository.instance.verify('1111'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('security_pin'), sha);
  });

  test('formato PBKDF2 armazenado e verificado apos nova gravacao', () async {
    await PinRepository.instance.save('1357');

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('security_pin')!;
    final parts = stored.split(r'$');

    expect(parts.length, 4);
    expect(parts[0], 'pbkdf2');
    expect(int.tryParse(parts[1]), isNotNull);
    expect(parts[2], isNotEmpty);
    expect(parts[3], isNotEmpty);

    expect(await PinRepository.instance.verify('1357'), isTrue);
    expect(await PinRepository.instance.verify('7531'), isFalse);
  });

  test('remove o PIN e desativa o bloqueio', () async {
    await PinRepository.instance.save('5555');
    await PinRepository.instance.remove();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('security_pin'), isNull);
    expect(prefs.getString('security_pin_salt'), isNull);
    expect(await PinRepository.instance.isEnabled(), isFalse);
    expect(await PinRepository.instance.hasPin(), isFalse);
  });

  test('verify retorna false quando nao ha PIN cadastrado', () async {
    expect(await PinRepository.instance.verify('1234'), isFalse);
  });

  test('disable mantem o PIN armazenado mas desativa o bloqueio', () async {
    await PinRepository.instance.save('1122');
    await PinRepository.instance.disable();

    expect(await PinRepository.instance.isEnabled(), isFalse);
    expect(await PinRepository.instance.hasPin(), isTrue);
    expect(await PinRepository.instance.verify('1122'), isTrue);
  });
}
