import 'package:kryptix/core/crypto/random.dart' as vault_random;

class PasswordGenerator {
  static const int minLength = 8;
  static const int maxLength = 128;

  static const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String numberChars = '0123456789';
  static const String symbolChars =
      '!@#\$%^&*()_+-=[]{}|;:,.<>?/~';

  Future<String> generate({
    required int length,
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSymbols,
  }) async {
    if (length < minLength || length > maxLength) {
      throw ArgumentError(
          'Length must be between $minLength and $maxLength');
    }

    if (!includeUppercase &&
        !includeLowercase &&
        !includeNumbers &&
        !includeSymbols) {
      throw ArgumentError(
          'At least one character set must be selected');
    }

    final charset = _buildCharset(
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSymbols: includeSymbols,
    );

    if (charset.isEmpty) {
      throw StateError('Character set is empty');
    }

    String password = '';
    final charsetBytes = charset.codeUnits;

    for (int i = 0; i < length; i++) {
      final randomIndices = vault_random.SecureRandom.generateRandomInRange(
        charsetBytes.length,
        1,
      );
      final randomIndex = randomIndices[0];
      password += charset[randomIndex];
    }

    if (!_validatePassword(
      password,
      includeUppercase,
      includeLowercase,
      includeNumbers,
      includeSymbols,
    )) {
      return generate(
        length: length,
        includeUppercase: includeUppercase,
        includeLowercase: includeLowercase,
        includeNumbers: includeNumbers,
        includeSymbols: includeSymbols,
      );
    }

    return password;
  }

  Future<String> generateWithDefaults() async {
    return generate(
      length: 16,
      includeUppercase: true,
      includeLowercase: true,
      includeNumbers: true,
      includeSymbols: true,
    );
  }

  PasswordStrength evaluateStrength({
    required String password,
    required bool mustHaveUppercase,
    required bool mustHaveLowercase,
    required bool mustHaveNumbers,
    required bool mustHaveSymbols,
  }) {
    if (password.isEmpty) {
      return PasswordStrength.veryWeak;
    }

    int score = 0;

    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    if (password.length >= 24) score += 1;

    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSymbols = symbolChars.split('').any((c) => password.contains(c));

    if (hasUppercase) score += 1;
    if (hasLowercase) score += 1;
    if (hasNumbers) score += 1;
    if (hasSymbols) score += 2;

    if (mustHaveUppercase && !hasUppercase) score = 0;
    if (mustHaveLowercase && !hasLowercase) score = 0;
    if (mustHaveNumbers && !hasNumbers) score = 0;
    if (mustHaveSymbols && !hasSymbols) score = 0;

    if (score <= 2) return PasswordStrength.veryWeak;
    if (score <= 4) return PasswordStrength.weak;
    if (score <= 6) return PasswordStrength.fair;
    if (score <= 8) return PasswordStrength.good;
    if (score <= 10) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  String _buildCharset({
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSymbols,
  }) {
    String charset = '';
    if (includeUppercase) charset += uppercaseChars;
    if (includeLowercase) charset += lowercaseChars;
    if (includeNumbers) charset += numberChars;
    if (includeSymbols) charset += symbolChars;
    return charset;
  }

  bool _validatePassword(
    String password,
    bool mustHaveUppercase,
    bool mustHaveLowercase,
    bool mustHaveNumbers,
    bool mustHaveSymbols,
  ) {
    if (mustHaveUppercase &&
        !password.contains(RegExp(r'[A-Z]'))) {
      return false;
    }
    if (mustHaveLowercase &&
        !password.contains(RegExp(r'[a-z]'))) {
      return false;
    }
    if (mustHaveNumbers &&
        !password.contains(RegExp(r'[0-9]'))) {
      return false;
    }
    if (mustHaveSymbols &&
        !symbolChars.split('').any((c) => password.contains(c))) {
      return false;
    }
    return true;
  }
}

enum PasswordStrength {
  veryWeak,
  weak,
  fair,
  good,
  strong,
  veryStrong,
}

extension PasswordStrengthDisplay on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.veryWeak:
        return 'Very Weak';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  String get color {
    switch (this) {
      case PasswordStrength.veryWeak:
        return 'red';
      case PasswordStrength.weak:
        return 'orange';
      case PasswordStrength.fair:
        return 'yellow';
      case PasswordStrength.good:
        return 'lightGreen';
      case PasswordStrength.strong:
        return 'green';
      case PasswordStrength.veryStrong:
        return 'darkGreen';
    }
  }
}
