import 'dart:typed_data';
import 'dart:convert';
import 'package:pointycastle/export.dart';
import 'package:vaultx/core/crypto/random.dart' as vault_random;

class AesGcm {
  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  static Uint8List encrypt({
    required Uint8List plaintext,
    required Uint8List key,
    required Uint8List nonce,
  }) {
    if (key.length != keyLength) {
      throw Exception('AES key must be $keyLength bytes, got ${key.length}');
    }
    if (nonce.length != nonceLength) {
      throw Exception(
          'Nonce must be $nonceLength bytes, got ${nonce.length}');
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8,
      nonce,
      Uint8List(0),
    );

    cipher.init(true, params);
    return cipher.process(plaintext);
  }

  static Uint8List encryptWithRandomNonce({
    required Uint8List plaintext,
    required Uint8List key,
  }) {
    final nonce = vault_random.SecureRandom.generateNonce(length: nonceLength);
    final ciphertext = encrypt(plaintext: plaintext, key: key, nonce: nonce);
    return Uint8List.fromList([...nonce, ...ciphertext]);
  }

  static Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
  }) {
    if (key.length != keyLength) {
      throw Exception('AES key must be $keyLength bytes, got ${key.length}');
    }
    if (nonce.length != nonceLength) {
      throw Exception(
          'Nonce must be $nonceLength bytes, got ${nonce.length}');
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8,
      nonce,
      Uint8List(0),
    );

    cipher.init(false, params);

    try {
      return cipher.process(ciphertext);
    } on ArgumentError {
      throw Exception('AES-GCM decryption failed: authentication tag invalid');
    }
  }

  static Uint8List decryptWithEmbeddedNonce({
    required Uint8List encryptedData,
    required Uint8List key,
  }) {
    if (encryptedData.length < nonceLength + tagLength) {
      throw Exception('Encrypted data too short to contain nonce and tag');
    }

    final nonce = encryptedData.sublist(0, nonceLength);
    final ciphertext = encryptedData.sublist(nonceLength);

    return decrypt(ciphertext: ciphertext, key: key, nonce: nonce);
  }

  static String encryptToBase64({
    required String plaintext,
    required Uint8List key,
  }) {
    final plaintextBytes = utf8.encode(plaintext);
    final encryptedBytes = encryptWithRandomNonce(
      plaintext: plaintextBytes,
      key: key,
    );
    return _toBase64(encryptedBytes);
  }

  static String decryptFromBase64({
    required String encrypted,
    required Uint8List key,
  }) {
    final encryptedBytes = _fromBase64(encrypted);
    final decryptedBytes = decryptWithEmbeddedNonce(
      encryptedData: encryptedBytes,
      key: key,
    );
    return utf8.decode(decryptedBytes);
  }

  static String _toBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  static Uint8List _fromBase64(String encoded) {
    return base64.decode(encoded);
  }
}
