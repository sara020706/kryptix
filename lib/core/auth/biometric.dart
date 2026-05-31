import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _localAuth;

  BiometricAuth({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometricOnly({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      return false;
    }
  }

  String biometricTypeToString(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Recognition';
      case BiometricType.strong:
        return 'Biometric';
      case BiometricType.weak:
        return 'Device Pattern';
    }
  }
}
