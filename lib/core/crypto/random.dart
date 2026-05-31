import 'dart:math';
import 'dart:typed_data';

class SecureRandom {
  static final _random = Random.secure();

  static Uint8List generateBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static Uint8List generateSalt({int length = 32}) {
    return generateBytes(length);
  }

  static Uint8List generateNonce({int length = 12}) {
    return generateBytes(length);
  }

  static List<int> generateRandomInRange(int max, int length) {
    final result = <int>[];
    for (int i = 0; i < length; i++) {
      result.add(_random.nextInt(max));
    }
    return result;
  }
}
