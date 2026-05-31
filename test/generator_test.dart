import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/generator/password_generator.dart';

void main() {
  group('GeneratorModule', () {
    final generator = PasswordGenerator();

    // 1. Generate password with all character sets
    test('Generate password with all character sets', () async {
      // act
      final password = await generator.generate(
        length: 16,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSymbols: true,
      );

      // assert
      expect(password.length, equals(16));
      expect(password.contains(RegExp(r'[A-Z]')), isTrue);
      expect(password.contains(RegExp(r'[a-z]')), isTrue);
      expect(password.contains(RegExp(r'[0-9]')), isTrue);
      // verify at least one symbol from the charset
      final containsSymbol = PasswordGenerator.symbolChars.split('').any((char) => password.contains(char));
      expect(containsSymbol, isTrue);
    });

    // 2. Generate password with only uppercase
    test('Generate password with only uppercase', () async {
      // act
      final password = await generator.generate(
        length: 12,
        includeUppercase: true,
        includeLowercase: false,
        includeNumbers: false,
        includeSymbols: false,
      );

      // assert
      expect(password.length, equals(12));
      expect(password.contains(RegExp(r'^[A-Z]+$')), isTrue);
    });

    // 3. Generate password with only numbers
    test('Generate password with only numbers', () async {
      // act
      final password = await generator.generate(
        length: 10,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: true,
        includeSymbols: false,
      );

      // assert
      expect(password.length, equals(10));
      expect(password.contains(RegExp(r'^[0-9]+$')), isTrue);
    });

    // 4. Verify length boundaries (8 minimum, 128 maximum)
    test('Verify length boundaries (exceptions thrown outside range)', () {
      // arrange & act & assert
      expect(
        () => generator.generate(
          length: 7, // below minimum
          includeUppercase: true,
          includeLowercase: true,
          includeNumbers: true,
          includeSymbols: true,
        ),
        throwsArgumentError,
      );

      expect(
        () => generator.generate(
          length: 129, // above maximum
          includeUppercase: true,
          includeLowercase: true,
          includeNumbers: true,
          includeSymbols: true,
        ),
        throwsArgumentError,
      );
    });

    // 5. Verify strength evaluation for each level
    test('Verify strength evaluation for various passwords', () {
      // Very Weak password (length < 8, lowercase only) -> score = 1 + 1 (lower) = 2 (<= 2)
      final strength1 = generator.evaluateStrength(
        password: 'abc',
        mustHaveUppercase: false,
        mustHaveLowercase: false,
        mustHaveNumbers: false,
        mustHaveSymbols: false,
      );
      expect(strength1, equals(PasswordStrength.veryWeak));

      // Weak password (length 8, mixed case + numbers) -> score = 1 (len) + 1 (upper) + 1 (lower) + 1 (num) = 4 (<= 4)
      final strength2 = generator.evaluateStrength(
        password: 'Abc12345',
        mustHaveUppercase: false,
        mustHaveLowercase: false,
        mustHaveNumbers: false,
        mustHaveSymbols: false,
      );
      expect(strength2, equals(PasswordStrength.weak));

      // Fair password (length 12, mixed case + numbers) -> score = 2 (len) + 1 (upper) + 1 (lower) + 1 (num) = 5 (<= 6)
      final strength3 = generator.evaluateStrength(
        password: 'Abc123456789',
        mustHaveUppercase: false,
        mustHaveLowercase: false,
        mustHaveNumbers: false,
        mustHaveSymbols: false,
      );
      expect(strength3, equals(PasswordStrength.fair));

      // Strong password (length 24+, mixed case + numbers + symbols) -> score = 4 (len) + 1 (upper) + 1 (lower) + 1 (num) + 2 (sym) = 9 (<= 10)
      final strength4 = generator.evaluateStrength(
        password: 'SuperComplexPassword123!@#',
        mustHaveUppercase: false,
        mustHaveLowercase: false,
        mustHaveNumbers: false,
        mustHaveSymbols: false,
      );
      expect(strength4, equals(PasswordStrength.strong));
    });

    // 6. Verify cryptographically random output
    test('Verify cryptographically random non-deterministic output', () async {
      // act
      final password1 = await generator.generate(
        length: 20,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSymbols: true,
      );

      final password2 = await generator.generate(
        length: 20,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSymbols: true,
      );

      // assert
      expect(password1, isNot(equals(password2)));
    });
  });
}
