import 'package:shared_preferences/shared_preferences.dart';

class PinRepository {
  PinRepository._();
  static final instance = PinRepository._();

  static const _pinKey = 'security_pin';
  static const _enabledKey = 'security_pin_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_pinKey) ?? '').isNotEmpty;
  }

  Future<void> save(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('O PIN deve ter entre 4 e 8 números.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_enabledKey, true);
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_pinKey) ?? '') == pin;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_enabledKey, false);
  }
}

