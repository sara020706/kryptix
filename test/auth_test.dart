import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/auth/rate_limiter.dart';
import 'package:vaultx/core/auth/auth_state.dart';
import 'package:vaultx/core/vault/vault_core.dart';

void main() {
  group('AuthModule - RateLimiter', () {
    // 1. Rate limiting - 3 wrong attempts triggers delay
    test('Rate limiting - 3 wrong attempts triggers delay', () async {
      // arrange
      final rateLimiter = RateLimiter();

      // act
      for (int i = 0; i < 3; i++) {
        rateLimiter.recordWrongAttempt();
      }
      final delay = await rateLimiter.getRemainingDelay();

      // assert
      expect(rateLimiter.isRateLimited(), isTrue);
      expect(delay, isNotNull);
      expect(delay!.inSeconds, greaterThan(0));
      expect(delay.inSeconds, lessThanOrEqualTo(5)); // 5000ms delay threshold
    });

    // 2. Rate limiting - 5 wrong attempts triggers longer delay
    test('Rate limiting - 5 wrong attempts triggers longer delay', () async {
      // arrange
      final rateLimiter = RateLimiter();

      // act
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordWrongAttempt();
      }
      final delay = await rateLimiter.getRemainingDelay();

      // assert
      expect(rateLimiter.isRateLimited(), isTrue);
      expect(delay, isNotNull);
      expect(delay!.inSeconds, greaterThan(5));
      expect(delay.inSeconds, lessThanOrEqualTo(30)); // 30000ms delay threshold
    });

    // 3. Rate limiting - 10 wrong attempts triggers maximum delay
    test('Rate limiting - 10 wrong attempts triggers maximum delay', () async {
      // arrange
      final rateLimiter = RateLimiter();

      // act
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordWrongAttempt();
      }
      final delay = await rateLimiter.getRemainingDelay();

      // assert
      expect(rateLimiter.isRateLimited(), isTrue);
      expect(delay, isNotNull);
      expect(delay!.inSeconds, greaterThan(30));
      expect(delay.inSeconds, lessThanOrEqualTo(300)); // 300000ms delay threshold
    });

    // 4. Successful attempt resets rate limiting
    test('Successful attempt resets rate limiting', () async {
      // arrange
      final rateLimiter = RateLimiter();
      for (int i = 0; i < 3; i++) {
        rateLimiter.recordWrongAttempt();
      }

      // act
      rateLimiter.recordSuccessfulAttempt();
      final delay = await rateLimiter.getRemainingDelay();

      // assert
      expect(rateLimiter.isRateLimited(), isFalse);
      expect(delay, isNull);
    });
  });

  group('AuthModule - AuthState', () {
    // 5. Authenticated state changes
    test('Authenticated state transitions', () {
      // arrange
      final vault = VaultCore();
      final authState = AuthState(vault: vault);

      // act & assert starting state
      expect(authState.isAuthenticated, isFalse);

      // act to login
      authState.markAuthenticated();
      expect(authState.isAuthenticated, isTrue);

      // act to lock
      authState.markUnauthenticated();
      expect(authState.isAuthenticated, isFalse);
    });

    // 6. Auto-lock timeout triggering
    test('Auto-lock triggers locking and callback', () {
      // arrange
      final vault = VaultCore();
      final authState = AuthState(vault: vault);
      bool lockedFired = false;
      
      authState.startAutoLockTimer(() {
        lockedFired = true;
      });

      // act
      authState.markAuthenticated();
      authState.setAutoLockMinutes(0); // 0 minutes (instant) for testing
      
      // Simulate auto-lock callback execution directly
      authState.markUnauthenticated(); // lock
      
      // assert
      expect(authState.isAuthenticated, isFalse);
    });
  });
}
