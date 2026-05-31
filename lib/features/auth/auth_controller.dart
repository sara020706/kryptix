import 'package:kryptix/core/vault/vault_core.dart';
import 'package:kryptix/core/auth/keystore.dart';
import 'package:kryptix/core/auth/biometric.dart';
import 'package:kryptix/core/auth/rate_limiter.dart';
import 'package:kryptix/core/auth/auth_state.dart';
import 'package:kryptix/core/storage/file_manager.dart';
import 'package:kryptix/core/models/entry_model.dart';
import 'dart:convert';

class AuthController {
  final VaultCore vault;
  final Keystore keystore;
  final BiometricAuth biometric;
  final RateLimiter rateLimiter;
  final AuthState authState;

  AuthController({
    required this.vault,
    required this.keystore,
    required this.biometric,
    required this.rateLimiter,
    required this.authState,
  });

  Future<bool> isFirstTimeSetup() async {
    return !(await FileManager.vaultFileExists());
  }

  Future<AuthResult> setupMasterPassword({
    required String masterPassword,
    required String confirmPassword,
  }) async {
    if (masterPassword != confirmPassword) {
      return AuthResult(
        success: false,
        message: 'Passwords do not match',
      );
    }

    if (!_isPasswordStrong(masterPassword)) {
      return AuthResult(
        success: false,
        message: 'Password too weak. Use 12+ characters with mixed case, numbers, and symbols',
      );
    }

    try {
      await vault.createNewVault(
        masterPassword: masterPassword,
      );

      if (vault.vaultKey == null) {
        return AuthResult(
          success: false,
          message: 'Failed to create vault key',
        );
      }

      final vaultJson = vault.serializeVault();
      await FileManager.saveVaultToFile(vaultJson);

      await keystore.wrapAndStoreVaultKey(
        vaultKey: vault.vaultKey!,
        argon2ParamsJson: _serializeArgon2Params(vault),
        saltBase64: _extractSaltBase64(vault),
      );

      authState.markAuthenticated();

      return AuthResult(
        success: true,
        message: 'Vault setup complete',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to setup vault: $e',
      );
    }
  }

  Future<AuthResult> unlockVaultWithPassword({
    required String masterPassword,
    required String vaultJson,
  }) async {
    final delayRemaining = rateLimiter.getRemainingDelaySync();
    if (delayRemaining != null) {
      return AuthResult(
        success: false,
        message: 'Too many wrong attempts. Wait ${rateLimiter.formatDelay(delayRemaining)} before trying again',
        isRateLimited: true,
      );
    }

    try {
      String loadedVaultJson = vaultJson;
      if (vaultJson.isEmpty) {
        loadedVaultJson = await FileManager.loadVaultFromFile();
      }

      final success = await vault.unlockVault(
        masterPassword: masterPassword,
        vaultJson: loadedVaultJson,
      );

      if (!success) {
        await rateLimiter.recordWrongAttempt();
        return AuthResult(
          success: false,
          message: 'Wrong password (${rateLimiter.wrongAttempts} attempt${rateLimiter.wrongAttempts > 1 ? 's' : ''})',
        );
      }

      if (vault.vaultKey != null) {
        await keystore.wrapAndStoreVaultKey(
          vaultKey: vault.vaultKey!,
          argon2ParamsJson: _serializeArgon2Params(vault),
          saltBase64: _extractSaltBase64(vault),
        );
      }

      await rateLimiter.recordSuccessfulAttempt();
      authState.markAuthenticated();

      return AuthResult(
        success: true,
        message: 'Vault unlocked',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to unlock vault: $e',
      );
    }
  }

  Future<AuthResult> unlockVaultWithBiometric({
    required String vaultJson,
    required String reason,
  }) async {
    final canUseBio = await biometric.canUseBiometrics();
    if (!canUseBio) {
      return AuthResult(
        success: false,
        message: 'Biometric authentication not available',
      );
    }

    try {
      final authenticated = await biometric.authenticate(reason: reason);
      if (!authenticated) {
        return AuthResult(
          success: false,
          message: 'Biometric authentication failed',
        );
      }

      final vaultKey = await keystore.retrieveWrappedVaultKey();
      if (vaultKey == null) {
        return AuthResult(
          success: false,
          message: 'No biometric credentials set up. Please unlock with master password once.',
        );
      }

      String loadedVaultJson = vaultJson;
      if (loadedVaultJson.isEmpty) {
        loadedVaultJson = await FileManager.loadVaultFromFile();
      }

      final success = await vault.unlockVaultWithKey(
        vaultKey: vaultKey,
        vaultJson: loadedVaultJson,
      );

      if (!success) {
        return AuthResult(
          success: false,
          message: 'Biometric unlock failed: Integrity check or decryption failed',
        );
      }

      await rateLimiter.recordSuccessfulAttempt();
      authState.markAuthenticated();

      return AuthResult(
        success: true,
        message: 'Authenticated with biometric',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Biometric authentication error: $e',
      );
    }
  }

  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required String vaultJson,
  }) async {
    if (newPassword != confirmPassword) {
      return AuthResult(
        success: false,
        message: 'New passwords do not match',
      );
    }

    if (!_isPasswordStrong(newPassword)) {
      return AuthResult(
        success: false,
        message: 'New password too weak',
      );
    }

    if (currentPassword == newPassword) {
      return AuthResult(
        success: false,
        message: 'New password must be different from current',
      );
    }

    try {
      final unlockSuccess = await vault.unlockVault(
        masterPassword: currentPassword,
        vaultJson: vaultJson,
      );

      if (!unlockSuccess) {
        return AuthResult(
          success: false,
          message: 'Current password is incorrect',
        );
      }

      final existingEntries = List<VaultEntry>.from(vault.entries);

      vault.lockVault();

      await vault.createNewVault(
        masterPassword: newPassword,
      );

      for (final entry in existingEntries) {
        vault.addEntry(
          siteName: entry.siteName,
          username: entry.username,
          password: entry.password,
          notes: entry.notes,
        );
      }

      final updatedVaultJson = vault.serializeVault();
      await FileManager.saveVaultToFile(updatedVaultJson);

      await keystore.clearVaultKey();

      authState.markAuthenticated();

      return AuthResult(
        success: true,
        message: 'Master password changed successfully',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to change password: $e',
      );
    }
  }

  Future<AuthResult> rekeyVaultWithNewPassword({
    required List<VaultEntry> existingEntries,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      return AuthResult(
        success: false,
        message: 'Passwords do not match',
      );
    }

    if (!_isPasswordStrong(newPassword)) {
      return AuthResult(
        success: false,
        message: 'Password too weak. Use 12+ characters with mixed case, numbers, and symbols',
      );
    }

    try {
      // Create a brand new vault using the new password
      await vault.createNewVault(
        masterPassword: newPassword,
      );

      if (vault.vaultKey == null) {
        return AuthResult(
          success: false,
          message: 'Failed to create new vault key',
        );
      }

      // Re-populate all existing entries
      for (final entry in existingEntries) {
        vault.addEntry(
          siteName: entry.siteName,
          username: entry.username,
          password: entry.password,
          notes: entry.notes,
        );
      }

      // Serialize and save to file
      final vaultJson = vault.serializeVault();
      await FileManager.saveVaultToFile(vaultJson);

      // Store the new vault key in the biometric keystore
      await keystore.wrapAndStoreVaultKey(
        vaultKey: vault.vaultKey!,
        argon2ParamsJson: _serializeArgon2Params(vault),
        saltBase64: _extractSaltBase64(vault),
      );

      authState.markAuthenticated();

      return AuthResult(
        success: true,
        message: 'Vault successfully re-encrypted with new master password',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to rekey vault: $e',
      );
    }
  }

  void lockVault() {
    vault.lockVault();
    authState.markUnauthenticated();
  }

  bool _isPasswordStrong(String password) {
    if (password.length < 12) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'))) {
      return false;
    }
    return true;
  }

  String _serializeArgon2Params(VaultCore vault) {
    if (vault.vaultKey == null || vault.argon2Params == null) {
      return '{}';
    }
    return jsonEncode(vault.argon2Params!.toJson());
  }

  String _extractSaltBase64(VaultCore vault) {
    if (vault.vaultKey == null || vault.argon2Params == null) {
      return '';
    }
    final paramsMap = vault.argon2Params!.toJson();
    return paramsMap['salt'] as String? ?? '';
  }
}

class AuthResult {
  final bool success;
  final String message;
  final bool isRateLimited;

  AuthResult({
    required this.success,
    required this.message,
    this.isRateLimited = false,
  });
}
