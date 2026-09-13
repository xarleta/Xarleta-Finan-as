import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Armazena o PIN do aplicativo de forma segura.
///
/// O PIN nunca é persistido em texto puro. Ele é derivado com **PBKDF2-HMAC-
/// SHA256** (função de derivação lenta, resistente a força bruta) usando um
/// salt aleatório exclusivo e um número elevado de iterações.
///
/// Formatos suportados na verificação (compatibilidade retroativa):
/// - `pbkdf2$<iteracoes>$<salt>$<hash>` — formato atual (preferido);
/// - hash SHA-256 simples com salt separado — formato intermediário;
/// - PIN em texto puro — formato legado.
///
/// Sempre que um formato antigo é verificado com sucesso, ele é migrado
/// automaticamente para o formato PBKDF2, sem bloquear o usuário.
class PinRepository {
  PinRepository._();

  static final instance = PinRepository._();

  static const _pinKey = 'security_pin';
  static const _saltKey = 'security_pin_salt';
  static const _enabledKey = 'security_pin_enabled';

  /// Prefixo identificador do formato PBKDF2.
  static const _pbkdf2Prefix = 'pbkdf2';

  /// Número de iterações do PBKDF2. Valor alto o suficiente para tornar a
  /// força bruta offline custosa, mantendo o desbloqueio rápido no aparelho.
  static const _iterations = 120000;

  /// Tamanho da chave derivada, em bytes.
  static const _keyLength = 32;

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
    await prefs.setString(_pinKey, _derivePbkdf2(pin, salt, _iterations));
    await prefs.setBool(_enabledKey, true);
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey) ?? '';

    if (stored.isEmpty) return false;

    // Formato atual: PBKDF2 embutido no próprio valor armazenado.
    if (stored.startsWith('$_pbkdf2Prefix\$')) {
      final parts = stored.split(r'$');
      if (parts.length == 4) {
        final iterations = int.tryParse(parts[1]);
        final salt = parts[2];
        final expected = parts[3];

        if (iterations != null && iterations > 0 && salt.isNotEmpty) {
          final computed = base64Url.encode(
            _pbkdf2(utf8.encode(pin), utf8.encode(salt), iterations, _keyLength),
          );
          if (_constantTimeEquals(expected, computed)) {
            return true;
          }
          return false;
        }
      }
      return false;
    }

    final salt = prefs.getString(_saltKey);

    if (salt == null || salt.isEmpty) {
      // Formato legado: PIN em texto puro. Compara e, em caso de sucesso,
      // migra imediatamente para o formato PBKDF2.
      if (stored == pin) {
        await save(pin);
        return true;
      }
      return false;
    }

    // Formato intermediário: SHA-256 simples com salt separado. Em caso de
    // sucesso, migra para PBKDF2.
    if (_constantTimeEquals(stored, _sha256(pin, salt))) {
      await save(pin);
      return true;
    }

    return false;
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

  /// Deriva o PIN com PBKDF2-HMAC-SHA256 e retorna no formato
  /// `pbkdf2$<iteracoes>$<salt>$<hash>`.
  String _derivePbkdf2(String pin, String salt, int iterations) {
    final derived = _pbkdf2(
      utf8.encode(pin),
      utf8.encode(salt),
      iterations,
      _keyLength,
    );
    return '$_pbkdf2Prefix\$$iterations\$$salt\$${base64Url.encode(derived)}';
  }

  /// Hash SHA-256 simples (usado apenas para ler o formato intermediário).
  String _sha256(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// Implementação de PBKDF2-HMAC-SHA256 (RFC 2898) usando o package `crypto`.
  Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength / 32).ceil();
    final output = BytesBuilder();

    for (var block = 1; block <= blockCount; block++) {
      // U1 = HMAC(password, salt || INT_32_BE(block))
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xff
        ..[1] = (block >> 16) & 0xff
        ..[2] = (block >> 8) & 0xff
        ..[3] = block & 0xff;

      var u = Uint8List.fromList(
        hmac.convert([...salt, ...blockIndex]).bytes,
      );
      final result = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < result.length; j++) {
          result[j] ^= u[j];
        }
      }

      output.add(result);
    }

    return Uint8List.fromList(output.toBytes().sublist(0, keyLength));
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
