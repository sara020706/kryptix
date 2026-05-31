import 'dart:typed_data';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:pointycastle/export.dart' as pc;
import '../crypto/argon2.dart';
import '../crypto/aes_gcm.dart';
import '../crypto/hmac.dart';
import '../crypto/random.dart';
import '../models/entry_model.dart';
import 'vault_file.dart';

class VaultCore {
  List<VaultEntry> _entries = [];
  Uint8List? _vaultKey;
  Argon2Params? _argon2Params;
  String? _verifier;
  bool _isLocked = true;

  bool get isLocked => _isLocked;
  bool get isUnlocked => !_isLocked;
  List<VaultEntry> get entries => List.unmodifiable(_entries);
  Uint8List? get vaultKey => _vaultKey;
  Argon2Params? get argon2Params => _argon2Params;

  Future<String> createNewVault({
    required String masterPassword,
  }) async {
    _verifier = null;
    _argon2Params = null;
    _vaultKey = null;
    _entries = [];
    _isLocked = true;

    final salt = SecureRandom.generateSalt();
    final result = await Argon2.deriveKey(
      password: masterPassword,
      salt: salt,
      memory: Argon2.defaultMemory,
      iterations: Argon2.defaultIterations,
      parallelism: Argon2.defaultParallelism,
      keyLength: 32,
    );

    final vaultKey = result;
    print('DEBUG CREATE: Key length=${vaultKey.length}, first4bytes=${vaultKey.sublist(0, 4)}');
    print('DEBUG CREATE: salt=${base64.encode(salt)}');
    print('DEBUG CREATE: memory=${Argon2.defaultMemory}, iterations=${Argon2.defaultIterations}, parallelism=${Argon2.defaultParallelism}');
    final verifierHash = _computeVerifier(vaultKey);
    print('DEBUG CREATE: Verifier=${verifierHash.substring(0, 16)}...');
    print('DEBUG CREATE: Salt length=${salt.length}');

    _argon2Params = Argon2Params(
      salt: salt,
      memory: Argon2.defaultMemory,
      iterations: Argon2.defaultIterations,
      parallelism: Argon2.defaultParallelism,
    );
    _verifier = verifierHash;
    _vaultKey = vaultKey;
    _entries = [];
    _isLocked = false;

    return _serializeVault();
  }

  Future<bool> unlockVault({
    required String masterPassword,
    required String vaultJson,
  }) async {
    _entries = [];
    _vaultKey = null;

    try {
      final vaultData = VaultFile.parseVaultJson(vaultJson);
      final storedVerifier = VaultFile.extractVerifier(vaultData);
      final storedHmac = VaultFile.extractHmac(vaultData);
      final argon2Params = VaultFile.extractArgon2Params(vaultData);

      print('DEBUG UNLOCK: Salt length=${argon2Params.salt.length}, iterations=${argon2Params.iterations}');
      print('DEBUG UNLOCK: Memory=${argon2Params.memory}, parallelism=${argon2Params.parallelism}');
      print('DEBUG UNLOCK: Stored salt=${base64.encode(argon2Params.salt)}');
      print('DEBUG UNLOCK: Stored verifier=${storedVerifier.substring(0, 16)}...');

      final result = await Argon2.deriveKey(
        password: masterPassword,
        salt: argon2Params.salt,
        memory: argon2Params.memory,
        iterations: argon2Params.iterations,
        parallelism: argon2Params.parallelism,
        keyLength: 32,
      );

      final derivedKey = result;
      print('DEBUG UNLOCK: Derived key length=${derivedKey.length}, first4bytes=${derivedKey.sublist(0, 4)}');
      final computedVerifier = _computeVerifier(derivedKey);
      print('DEBUG UNLOCK: Computed verifier=${computedVerifier.substring(0, 16)}...');
      print('DEBUG UNLOCK: Verifier match=${computedVerifier == storedVerifier}');

      if (computedVerifier != storedVerifier) {
        print('DEBUG UNLOCK: FAILED at verifier comparison');
        return false;
      }

      final vaultJsonWithoutHmac = VaultFile.sanitizeVaultJsonForHmac(vaultJson);
      final vaultJsonBytes =
          utf8.encode(vaultJsonWithoutHmac);
      final storedHmacBytes =
          HmacSha256.decodeSignature(storedHmac);

      if (!HmacSha256.verifySignature(
        key: derivedKey,
        data: vaultJsonBytes,
        expectedSignature: storedHmacBytes,
      )) {
        print('DEBUG UNLOCK: FAILED at HMAC verification');
        return false;
      }

      print('DEBUG UNLOCK: HMAC verified OK');

      final encryptedEntries = VaultFile.extractEntries(vaultData);
      final decryptedEntries = _decryptEntries(encryptedEntries, derivedKey);

      _argon2Params = argon2Params;
      _verifier = storedVerifier;
      _vaultKey = derivedKey;
      _entries = decryptedEntries;
      _isLocked = false;
      print('DEBUG UNLOCK: SUCCESS - ${decryptedEntries.length} entries loaded');
      return true;
    } catch (e) {
      print('DEBUG UNLOCK: EXCEPTION: $e');
      return false;
    }
  }

  Future<bool> unlockVaultWithKey({
    required Uint8List vaultKey,
    required String vaultJson,
  }) async {
    _entries = [];
    _vaultKey = null;

    try {
      final vaultData = VaultFile.parseVaultJson(vaultJson);
      final storedVerifier = VaultFile.extractVerifier(vaultData);
      final storedHmac = VaultFile.extractHmac(vaultData);
      final argon2Params = VaultFile.extractArgon2Params(vaultData);

      final computedVerifier = _computeVerifier(vaultKey);

      if (computedVerifier != storedVerifier) {
        return false;
      }

      final vaultJsonWithoutHmac = VaultFile.sanitizeVaultJsonForHmac(vaultJson);
      final vaultJsonBytes =
          utf8.encode(vaultJsonWithoutHmac);
      final storedHmacBytes =
          HmacSha256.decodeSignature(storedHmac);

      if (!HmacSha256.verifySignature(
        key: vaultKey,
        data: vaultJsonBytes,
        expectedSignature: storedHmacBytes,
      )) {
        return false;
      }

      final encryptedEntries = VaultFile.extractEntries(vaultData);
      final decryptedEntries = _decryptEntries(encryptedEntries, vaultKey);

      _argon2Params = argon2Params;
      _verifier = storedVerifier;
      _vaultKey = vaultKey;
      _entries = decryptedEntries;
      _isLocked = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  void lockVault() {
    _entries = [];
    _wipeSensitiveMemory();
    _vaultKey = null;
    _isLocked = true;
  }

  void addEntry({
    required String siteName,
    required String username,
    required String password,
    required String notes,
  }) {
    if (_isLocked) {
      throw Exception('Vault is locked');
    }

    const uuid = Uuid();
    final entry = VaultEntry(
      id: uuid.v4(),
      siteName: siteName,
      username: username,
      password: password,
      notes: notes,
    );

    _entries.add(entry);
  }

  void editEntry({
    required String entryId,
    required String siteName,
    required String username,
    required String password,
    required String notes,
  }) {
    if (_isLocked) {
      throw Exception('Vault is locked');
    }

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw Exception('Entry not found');
    }

    _entries[index] = _entries[index].copyWith(
      siteName: siteName,
      username: username,
      password: password,
      notes: notes,
    );
  }

  void deleteEntry(String entryId) {
    if (_isLocked) {
      throw Exception('Vault is locked');
    }

    _entries.removeWhere((e) => e.id == entryId);
  }

  String serializeVault() {
    if (_isLocked) {
      throw Exception('Vault is locked');
    }
    return _serializeVault();
  }

  String _serializeVault() {
    if (_vaultKey == null || _argon2Params == null || _verifier == null) {
      throw Exception('Vault key, argon2 params, or verifier missing');
    }

    final encryptedEntries = _entries.map((entry) {
      final entryJson = entry.toJson();
      final jsonString = jsonEncode(entryJson);
      final jsonBytes = utf8.encode(jsonString);
      final encryptedBytes = AesGcm.encryptWithRandomNonce(
        plaintext: jsonBytes,
        key: _vaultKey!,
      );

      return EncryptedVaultEntry(
        id: entry.id,
        nonce: '',
        ciphertext: _toBase64(encryptedBytes),
      );
    }).toList();

    final exportedAt = DateTime.now().toUtc().toIso8601String();

    final vaultJsonWithoutHmac = VaultFile.createVaultJsonWithoutSignature(
      entries: encryptedEntries,
      argon2Params: _argon2Params!,
      verifier: _verifier!,
      exportedAt: exportedAt,
    );

    final hmacSignature = VaultFile.computeHmacForJson(
      vaultJsonWithoutHmac: vaultJsonWithoutHmac,
      vaultKey: _vaultKey!,
    );

    return VaultFile.createVaultJson(
      entries: encryptedEntries,
      argon2Params: _argon2Params!,
      verifier: _verifier!,
      hmacSignature: hmacSignature,
      exportedAt: exportedAt,
    );
  }

  String _computeVerifier(Uint8List vaultKey) {
    final digest = pc.SHA256Digest();
    final hashBytes = digest.process(vaultKey);
    return _toHex(hashBytes);
  }

  void _wipeSensitiveMemory() {
    if (_vaultKey != null) {
      for (int i = 0; i < _vaultKey!.length; i++) {
        _vaultKey![i] = 0;
      }
    }
  }

  List<VaultEntry> _decryptEntries(
    List<EncryptedVaultEntry> encryptedEntries,
    Uint8List key,
  ) {
    final decryptedEntries = <VaultEntry>[];
    for (final encEntry in encryptedEntries) {
      final encryptedBytes = _fromBase64(encEntry.ciphertext);
      final plaintextBytes = AesGcm.decryptWithEmbeddedNonce(
        encryptedData: encryptedBytes,
        key: key,
      );
      final entryJson = jsonDecode(
        utf8.decode(plaintextBytes),
      ) as Map<String, dynamic>;

      final entry = VaultEntry(
        id: encEntry.id,
        siteName: entryJson['site_name'] as String? ?? '',
        username: entryJson['username'] as String? ?? '',
        password: entryJson['password'] as String? ?? '',
        notes: entryJson['notes'] as String? ?? '',
      );
      decryptedEntries.add(entry);
    }
    return decryptedEntries;
  }

  static String _toBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  static Uint8List _fromBase64(String encoded) {
    return base64.decode(encoded);
  }

  static String _toHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final byte in bytes) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}


