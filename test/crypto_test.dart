import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/crypto/aes_gcm.dart';
import 'package:vaultx/core/crypto/argon2.dart';
import 'package:vaultx/core/crypto/hmac.dart';
import 'package:vaultx/core/crypto/random.dart';

void main() {
  group('CryptoModule', () {
    // 1. Argon2id key derivation with known inputs
    test('Argon2id key derivation correctness', () async {
      // arrange
      final password = 'super_secret_master_password';
      final salt = Uint8List.fromList(List.generate(32, (i) => i));

      // act
      final key = await Argon2.deriveKey(
        password: password,
        salt: salt,
        memory: 16384, // Reduced for test speed
        iterations: 2,
        parallelism: 1,
        keyLength: 32,
      );

      // assert
      expect(key, isNotNull);
      expect(key.length, equals(32));
    });

    // 2. AES-256-GCM encryption correctness
    test('AES-256-GCM encryption correctness', () {
      // arrange
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i * 2));

      // act
      final ciphertext = AesGcm.encrypt(plaintext: plaintext, key: key, nonce: nonce);

      // assert
      expect(ciphertext, isNotNull);
      expect(ciphertext.length, greaterThan(plaintext.length));
    });

    // 3. AES-256-GCM decryption correctness
    test('AES-256-GCM decryption correctness', () {
      // arrange
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i * 2));

      // act
      final ciphertext = AesGcm.encrypt(plaintext: plaintext, key: key, nonce: nonce);
      final decrypted = AesGcm.decrypt(ciphertext: ciphertext, key: key, nonce: nonce);

      // assert
      expect(decrypted, equals(plaintext));
    });

    // 4. AES-256-GCM tamper detection
    test('AES-256-GCM tamper detection', () {
      // arrange
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i * 2));

      final ciphertext = AesGcm.encrypt(plaintext: plaintext, key: key, nonce: nonce);
      
      // Tamper with the authentication tag at the end of the ciphertext
      ciphertext[ciphertext.length - 1] ^= 0xFF;

      // act & assert
      expect(() => AesGcm.decrypt(ciphertext: ciphertext, key: key, nonce: nonce), throwsException);
    });

    // 5. HMAC-SHA256 computation
    test('HMAC-SHA256 computation', () {
      // arrange
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList([10, 20, 30, 40]);

      // act
      final signature = HmacSha256.computeSignature(key: key, data: data);

      // assert
      expect(signature, isNotNull);
      expect(signature.length, equals(32));
    });

    // 6. HMAC-SHA256 verification
    test('HMAC-SHA256 verification', () {
      // arrange
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList([10, 20, 30, 40]);
      final signature = HmacSha256.computeSignature(key: key, data: data);

      // act
      final isVerified = HmacSha256.verifySignature(key: key, data: data, expectedSignature: signature);

      // assert
      expect(isVerified, isTrue);
    });

    // 7. HMAC tamper detection
    test('HMAC tamper detection', () {
      // arrange
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList([10, 20, 30, 40]);
      final signature = HmacSha256.computeSignature(key: key, data: data);

      // Tamper with the signature
      signature[0] ^= 0xFF;

      // act
      final isVerified = HmacSha256.verifySignature(key: key, data: data, expectedSignature: signature);

      // assert
      expect(isVerified, isFalse);
    });

    // 8. Secure random generation
    test('Secure random generation', () {
      // act
      final bytes1 = SecureRandom.generateBytes(16);
      final bytes2 = SecureRandom.generateBytes(16);

      // assert
      expect(bytes1.length, equals(16));
      expect(bytes2.length, equals(16));
      expect(bytes1, isNot(equals(bytes2))); // verify non-deterministic outputs
    });

    // 9. Nonce uniqueness
    test('Nonce uniqueness', () {
      // act
      final nonce1 = SecureRandom.generateNonce(length: 12);
      final nonce2 = SecureRandom.generateNonce(length: 12);

      // assert
      expect(nonce1, isNot(equals(nonce2)));
    });
  });
}
