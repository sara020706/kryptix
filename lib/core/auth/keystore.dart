import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Keystore {
  static const String _vaultKeyStorageKey = 'kryptix_wrapped_key';
  static const String _vaultSaltStorageKey = 'kryptix_salt';
  static const String _vaultArgon2StorageKey = 'kryptix_argon2_params';

  static const String _autoLockStorageKey = 'kryptix_auto_lock_minutes';

  final FlutterSecureStorage _storage;

  Keystore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> storeAutoLockMinutes(int minutes) async {
    try {
      await _storage.write(key: _autoLockStorageKey, value: minutes.toString());
    } catch (e) {
      throw Exception('Failed to store auto-lock minutes: $e');
    }
  }

  Future<int> retrieveAutoLockMinutes() async {
    try {
      final value = await _storage.read(key: _autoLockStorageKey);
      if (value == null) {
        return 5;
      }
      return int.tryParse(value) ?? 5;
    } catch (e) {
      return 5;
    }
  }

  Future<void> wrapAndStoreVaultKey({
    required Uint8List vaultKey,
    required String argon2ParamsJson,
    required String saltBase64,
  }) async {
    try {
      final keyHex = _bytesToHex(vaultKey);

      await Future.wait([
        _storage.write(key: _vaultKeyStorageKey, value: keyHex),
        _storage.write(key: _vaultArgon2StorageKey, value: argon2ParamsJson),
        _storage.write(key: _vaultSaltStorageKey, value: saltBase64),
      ]);
    } catch (e) {
      throw Exception('Failed to store vault key in keystore: $e');
    }
  }

  Future<Uint8List?> retrieveWrappedVaultKey() async {
    try {
      final keyHex =
          await _storage.read(key: _vaultKeyStorageKey);
      if (keyHex == null) {
        return null;
      }
      return _hexToBytes(keyHex);
    } catch (e) {
      throw Exception('Failed to retrieve vault key from keystore: $e');
    }
  }

  Future<String?> retrieveArgon2Params() async {
    try {
      return await _storage.read(key: _vaultArgon2StorageKey);
    } catch (e) {
      throw Exception('Failed to retrieve argon2 params: $e');
    }
  }

  Future<String?> retrieveSalt() async {
    try {
      return await _storage.read(key: _vaultSaltStorageKey);
    } catch (e) {
      throw Exception('Failed to retrieve salt: $e');
    }
  }

  Future<bool> hasStoredVaultKey() async {
    try {
      final key = await _storage.read(key: _vaultKeyStorageKey);
      return key != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearVaultKey() async {
    try {
      await Future.wait([
        _storage.delete(key: _vaultKeyStorageKey),
        _storage.delete(key: _vaultArgon2StorageKey),
        _storage.delete(key: _vaultSaltStorageKey),
      ]);
    } catch (e) {
      throw Exception('Failed to clear vault key: $e');
    }
  }

  static String _bytesToHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final byte in bytes) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
