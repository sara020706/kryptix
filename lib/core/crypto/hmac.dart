import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class HmacSha256 {
  static const int keyLength = 32;

  static Uint8List computeSignature({
    required Uint8List key,
    required Uint8List data,
  }) {
    if (key.length != keyLength) {
      throw Exception(
          'HMAC key must be $keyLength bytes, got ${key.length} bytes');
    }

    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return Uint8List.fromList(hmac.process(data));
  }

  static bool verifySignature({
    required Uint8List key,
    required Uint8List data,
    required Uint8List expectedSignature,
  }) {
    final computedSignature = computeSignature(key: key, data: data);
    return _constantTimeEquals(computedSignature, expectedSignature);
  }

  static String encodeSignature(Uint8List signature) {
    return _toHex(signature);
  }

  static Uint8List decodeSignature(String encoded) {
    return _fromHex(encoded);
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  static String _toHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final byte in bytes) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _fromHex(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
