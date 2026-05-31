import 'package:argon2/argon2.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'random.dart';

class _Argon2IsolateParams {
  final String password;
  final Uint8List salt;
  final int iterations;
  final int memoryPowerOf2;
  final int parallelism;
  final int keyLength;

  _Argon2IsolateParams({
    required this.password,
    required this.salt,
    required this.iterations,
    required this.memoryPowerOf2,
    required this.parallelism,
    required this.keyLength,
  });
}

Uint8List _deriveKeyInIsolate(_Argon2IsolateParams p) {
  final passwordBytes = utf8.encode(p.password);

  final params = Argon2Parameters(
    Argon2Parameters.ARGON2_id,
    p.salt,
    iterations: p.iterations,
    memoryPowerOf2: p.memoryPowerOf2,
    lanes: p.parallelism,
    version: Argon2Parameters.ARGON2_VERSION_13,
  );

  final generator = Argon2BytesGenerator();
  generator.init(params);

  final result = Uint8List(p.keyLength);
  generator.generateBytes(passwordBytes, result, 0, result.length);

  return result;
}

class Argon2 {
  static const int defaultMemory = 262144;
  static const int defaultIterations = 3;
  static const int defaultParallelism = 4;
  static const int defaultSaltLength = 32;

  static Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
    int memory = defaultMemory,
    int iterations = defaultIterations,
    int parallelism = defaultParallelism,
    int keyLength = 32,
  }) async {
    try {
      int memoryPowerOf2 = 18;
      int temp = memory;
      int count = 0;
      while (temp > 1) {
        temp >>= 1;
        count++;
      }
      memoryPowerOf2 = count;

      print('DEBUG ARGON2: memory=$memory -> memoryPowerOf2=$memoryPowerOf2, iterations=$iterations, parallelism=$parallelism, keyLength=$keyLength');
      return await Isolate.run(() => _deriveKeyInIsolate(
        _Argon2IsolateParams(
          password: password,
          salt: salt,
          iterations: iterations,
          memoryPowerOf2: memoryPowerOf2,
          parallelism: parallelism,
          keyLength: keyLength,
        ),
      ));
    } catch (e) {
      throw Exception('Argon2 key derivation failed: $e');
    }
  }

  static Future<Uint8List> deriveKeyWithRandomSalt({
    required String password,
    int memory = defaultMemory,
    int iterations = defaultIterations,
    int parallelism = defaultParallelism,
    int keyLength = 32,
    int saltLength = defaultSaltLength,
  }) async {
    final salt = SecureRandom.generateSalt(length: saltLength);
    return deriveKey(
      password: password,
      salt: salt,
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
      keyLength: keyLength,
    );
  }

  static Uint8List generateNewSalt({int length = defaultSaltLength}) {
    return SecureRandom.generateSalt(length: length);
  }
}

class Argon2Params {
  final Uint8List salt;
  final int memory;
  final int iterations;
  final int parallelism;

  Argon2Params({
    required this.salt,
    required this.memory,
    required this.iterations,
    required this.parallelism,
  });

  factory Argon2Params.withDefaults({required Uint8List salt}) {
    return Argon2Params(
      salt: salt,
      memory: Argon2.defaultMemory,
      iterations: Argon2.defaultIterations,
      parallelism: Argon2.defaultParallelism,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'salt': _encodeBase64(salt),
      'memory': memory,
      'iterations': iterations,
      'parallelism': parallelism,
    };
  }

  factory Argon2Params.fromJson(Map<String, dynamic> json) {
    return Argon2Params(
      salt: _decodeBase64(json['salt'] as String),
      memory: json['memory'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
    );
  }

  static String _encodeBase64(Uint8List data) {
    return base64Encode(data);
  }

  static Uint8List _decodeBase64(String encoded) {
    return base64Decode(encoded);
  }
}

String base64Encode(Uint8List data) {
  return base64.encode(data);
}

Uint8List base64Decode(String encoded) {
  return base64.decode(encoded);
}
