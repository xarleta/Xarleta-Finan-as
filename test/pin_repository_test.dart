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
  });

  test('migra PIN legado em texto puro na primeira verificacao', () async {
    SharedPreferences.setMockInitialValues({
      'security_pin': '9876',
      'security_pin_enabled': true,
    });

    expect(await PinRepository.instance.verify('9876'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('security_pin'), isNot('9876'));
    expect(prefs.getString('security_pin_salt'), isNotEmpty);
    expect(await PinRepository.instance.verify('9876'), isTrue);
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
}
