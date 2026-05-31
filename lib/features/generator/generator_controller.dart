import 'package:vaultx/core/generator/password_generator.dart';

class GeneratorController {
  final PasswordGenerator _generator = PasswordGenerator();

  Future<String> generatePassword({
    required int length,
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSymbols,
  }) async {
    return _generator.generate(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSymbols: includeSymbols,
    );
  }

  Future<String> generateDefaultPassword() async {
    return _generator.generateWithDefaults();
  }

  PasswordStrength evaluatePasswordStrength({
    required String password,
    required bool mustHaveUppercase,
    required bool mustHaveLowercase,
    required bool mustHaveNumbers,
    required bool mustHaveSymbols,
  }) {
    return _generator.evaluateStrength(
      password: password,
      mustHaveUppercase: mustHaveUppercase,
      mustHaveLowercase: mustHaveLowercase,
      mustHaveNumbers: mustHaveNumbers,
      mustHaveSymbols: mustHaveSymbols,
    );
  }

  String getStrengthLabel(PasswordStrength strength) {
    return strength.label;
  }

  String getStrengthColor(PasswordStrength strength) {
    return strength.color;
  }

  int get minLength => PasswordGenerator.minLength;
  int get maxLength => PasswordGenerator.maxLength;
}
