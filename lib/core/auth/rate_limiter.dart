import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RateLimiter {
  static const int _thresholdWrong1 = 3;
  static const int _delayMs1 = 5000;

  static const int _thresholdWrong2 = 5;
  static const int _delayMs2 = 30000;

  static const int _thresholdWrong3 = 10;
  static const int _delayMs3 = 300000;

  static const String _wrongAttemptsKey = 'vaultx_wrong_attempts';
  static const String _lastWrongAttemptTimeKey = 'vaultx_last_wrong_attempt_time';

  final FlutterSecureStorage _storage;

  int _wrongAttempts = 0;
  DateTime? _lastWrongAttemptTime;

  RateLimiter({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  int get wrongAttempts => _wrongAttempts;

  Future<void> initialize() async {
    try {
      final attemptsStr = await _storage.read(key: _wrongAttemptsKey);
      if (attemptsStr != null) {
        _wrongAttempts = int.tryParse(attemptsStr) ?? 0;
      }
      final timeStr = await _storage.read(key: _lastWrongAttemptTimeKey);
      if (timeStr != null) {
        _lastWrongAttemptTime = DateTime.tryParse(timeStr);
      }
    } catch (e) {
      _wrongAttempts = 0;
      _lastWrongAttemptTime = null;
    }
  }

  Future<void> recordWrongAttempt() async {
    _wrongAttempts++;
    _lastWrongAttemptTime = DateTime.now();
    try {
      await _storage.write(key: _wrongAttemptsKey, value: _wrongAttempts.toString());
      await _storage.write(key: _lastWrongAttemptTimeKey, value: _lastWrongAttemptTime!.toIso8601String());
    } catch (e) {}
  }

  Future<void> recordSuccessfulAttempt() async {
    _wrongAttempts = 0;
    _lastWrongAttemptTime = null;
    try {
      await _storage.delete(key: _wrongAttemptsKey);
      await _storage.delete(key: _lastWrongAttemptTimeKey);
    } catch (e) {}
  }

  Future<Duration?> getRemainingDelay() async {
    if (_lastWrongAttemptTime == null) {
      return null;
    }

    int delayMs = 0;

    if (_wrongAttempts >= _thresholdWrong3) {
      delayMs = _delayMs3;
    } else if (_wrongAttempts >= _thresholdWrong2) {
      delayMs = _delayMs2;
    } else if (_wrongAttempts >= _thresholdWrong1) {
      delayMs = _delayMs1;
    } else {
      return null;
    }

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastWrongAttemptTime!).inMilliseconds;
    final remainingMs = delayMs - elapsedMs;

    if (remainingMs > 0) {
      return Duration(milliseconds: remainingMs);
    }

    return null;
  }

  bool isRateLimited() {
    return getRemainingDelaySync() != null;
  }

  Duration? getRemainingDelaySync() {
    if (_lastWrongAttemptTime == null) {
      return null;
    }

    int delayMs = 0;

    if (_wrongAttempts >= _thresholdWrong3) {
      delayMs = _delayMs3;
    } else if (_wrongAttempts >= _thresholdWrong2) {
      delayMs = _delayMs2;
    } else if (_wrongAttempts >= _thresholdWrong1) {
      delayMs = _delayMs1;
    } else {
      return null;
    }

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastWrongAttemptTime!).inMilliseconds;
    final remainingMs = delayMs - elapsedMs;

    if (remainingMs > 0) {
      return Duration(milliseconds: remainingMs);
    }

    return null;
  }

  Future<void> reset() async {
    _wrongAttempts = 0;
    _lastWrongAttemptTime = null;
    try {
      await _storage.delete(key: _wrongAttemptsKey);
      await _storage.delete(key: _lastWrongAttemptTimeKey);
    } catch (e) {}
  }

  String formatDelay(Duration delay) {
    if (delay.inSeconds < 60) {
      return '${delay.inSeconds} seconds';
    } else if (delay.inMinutes < 60) {
      return '${delay.inMinutes} minutes ${delay.inSeconds % 60} seconds';
    } else {
      return '${delay.inHours} hours ${(delay.inMinutes % 60)} minutes';
    }
  }
}
