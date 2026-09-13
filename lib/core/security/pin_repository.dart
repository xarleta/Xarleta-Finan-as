import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Armazena o PIN do aplicativo de forma segura.
///
/// O PIN nunca é persistido em texto puro: é guardado como hash SHA-256
/// combinado a um salt aleatório exclusivo. O salt é gerado no momento da
/// gravação e persistido separadamente, permitindo verificar o PIN sem
/// conhecer o valor original.
///
/// Bancos/instalações antigas que ainda possuem o PIN em texto puro são
/// migradas automaticamente na primeira verificação bem-sucedida, sem
/// bloquear o usuário existente.
class PinRepository {
  PinRepository._();
  static final instance = PinRepository._();

  static const _pinKey = 'security_pin';
  static const _saltKey = 'security_pin_salt';
  static const _enabledKey = 'security_pin_enabled';

  static final _pinPattern = RegExp(r'^\d{4,8}$');

  final Random _random = Random.secure();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_pinKey) ?? '').isNotEmpty;
  }

  Future<void> save(String pin) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw ArgumentError('O PIN deve ter entre 4 e 8 números.');
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();

    await prefs.setString(_saltKey, salt);
    await prefs.setString(_pinKey, _hash(pin, salt));
    await prefs.setBool(_enabledKey, true);
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey) ?? '';

    if (stored.isEmpty) return false;

    final salt = prefs.getString(_saltKey);

    if (salt == null || salt.isEmpty) {
      // Formato legado: PIN em texto puro. Compara e, em caso de sucesso,
      // migra imediatamente para o formato com hash + salt.
      if (stored == pin) {
        await save(pin);
        return true;
      }
      return false;
    }

    return _constantTimeEquals(stored, _hash(pin, salt));
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_saltKey);
    await prefs.setBool(_enabledKey, false);
  }

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// Comparação em tempo constante para reduzir risco de timing attack.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
