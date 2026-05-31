import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryptix/core/vault/vault_core.dart';
import 'package:kryptix/core/vault/vault_file.dart';
import 'package:kryptix/core/models/entry_model.dart';

void main() {
  group('VaultModule', () {
    // 1. Vault creation with correct structure
    test('Vault creation with correct structure', () async {
      // arrange
      final vault = VaultCore();

      // act
      final serialized = await vault.createNewVault(masterPassword: 'secureMasterPassword123');

      // assert
      expect(serialized, isNotEmpty);
      final jsonMap = jsonDecode(serialized) as Map<String, dynamic>;
      expect(jsonMap['version'], equals(VaultFile.currentVersion));
      expect(jsonMap['app_name'], equals('Kryptix'));
      expect(jsonMap['argon2'], isNotNull);
      expect(jsonMap['verifier'], isNotEmpty);
      expect(jsonMap['hmac'], isNotEmpty);
      expect(jsonMap['entries'], isEmpty);
      expect(vault.isLocked, isFalse);
    });

    // 2. Vault unlock with correct password
    test('Vault unlock with correct password', () async {
      // arrange
      final vault = VaultCore();
      final serialized = await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      vault.lockVault();

      // act
      final unlocked = await vault.unlockVault(
        masterPassword: 'secureMasterPassword123',
        vaultJson: serialized,
      );

      // assert
      expect(unlocked, isTrue);
      expect(vault.isLocked, isFalse);
    });

    // 3. Vault unlock with wrong password
    test('Vault unlock with wrong password', () async {
      // arrange
      final vault = VaultCore();
      final serialized = await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      vault.lockVault();

      // act
      final unlocked = await vault.unlockVault(
        masterPassword: 'wrongMasterPassword',
        vaultJson: serialized,
      );

      // assert
      expect(unlocked, isFalse);
      expect(vault.isLocked, isTrue);
    });

    // 4. Vault unlock with tampered HMAC
    test('Vault unlock with tampered HMAC', () async {
      // arrange
      final vault = VaultCore();
      final serialized = await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      
      // Tamper with the HMAC value in the JSON
      final jsonMap = jsonDecode(serialized) as Map<String, dynamic>;
      jsonMap['hmac'] = 'a' * 64; // dummy hmac
      final tamperedSerialized = jsonEncode(jsonMap);
      
      vault.lockVault();

      // act
      final unlocked = await vault.unlockVault(
        masterPassword: 'secureMasterPassword123',
        vaultJson: tamperedSerialized,
      );

      // assert
      expect(unlocked, isFalse);
      expect(vault.isLocked, isTrue);
    });

    // 5. Vault unlock with tampered entry
    test('Vault unlock with tampered entry', () async {
      // arrange
      final vault = VaultCore();
      await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      vault.addEntry(siteName: 'Gmail', username: 'user@gmail.com', password: 'password', notes: 'test');
      final serialized = vault.serializeVault();
      
      // Tamper with entry data
      final jsonMap = jsonDecode(serialized) as Map<String, dynamic>;
      final entriesList = jsonMap['entries'] as List;
      final entryMap = entriesList[0] as Map<String, dynamic>;
      entryMap['ciphertext'] = 'a' * 32; // tampered ciphertext
      final tamperedSerialized = jsonEncode(jsonMap);

      vault.lockVault();

      // act
      final unlocked = await vault.unlockVault(
        masterPassword: 'secureMasterPassword123',
        vaultJson: tamperedSerialized,
      );

      // assert
      expect(unlocked, isFalse);
      expect(vault.isLocked, isTrue);
    });

    // 6. Add entry and verify correct encryption
    test('Add entry and verify correct encryption', () async {
      // arrange
      final vault = VaultCore();
      await vault.createNewVault(masterPassword: 'secureMasterPassword123');

      // act
      vault.addEntry(
        siteName: 'Gmail',
        username: 'user@gmail.com',
        password: 'gmailPassword123',
        notes: 'Personal account',
      );

      // assert
      expect(vault.entries.length, equals(1));
      final entry = vault.entries[0];
      expect(entry.siteName, equals('Gmail'));
      expect(entry.username, equals('user@gmail.com'));
      expect(entry.password, equals('gmailPassword123'));
      expect(entry.notes, equals('Personal account'));
    });

    // 7. Edit entry and verify re-encryption
    test('Edit entry and verify re-encryption', () async {
      // arrange
      final vault = VaultCore();
      await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      vault.addEntry(siteName: 'Gmail', username: 'user@gmail.com', password: 'password', notes: 'test');
      final entryId = vault.entries[0].id;

      // act
      vault.editEntry(
        entryId: entryId,
        siteName: 'Google',
        username: 'user@google.com',
        password: 'newPassword123',
        notes: 'Work account',
      );

      // assert
      expect(vault.entries.length, equals(1));
      final entry = vault.entries[0];
      expect(entry.siteName, equals('Google'));
      expect(entry.username, equals('user@google.com'));
      expect(entry.password, equals('newPassword123'));
    });

    // 8. Delete entry and verify removed
    test('Delete entry and verify removed', () async {
      // arrange
      final vault = VaultCore();
      await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      vault.addEntry(siteName: 'Gmail', username: 'user@gmail.com', password: 'password', notes: 'test');
      final entryId = vault.entries[0].id;

      // act
      vault.deleteEntry(entryId);

      // assert
      expect(vault.entries, isEmpty);
    });

    // 9. Serialize vault and verify HMAC updated
    test('Serialize vault and verify HMAC updated', () async {
      // arrange
      final vault = VaultCore();
      final originalSerialized = await vault.createNewVault(masterPassword: 'secureMasterPassword123');
      final originalHmac = (jsonDecode(originalSerialized) as Map<String, dynamic>)['hmac'];

      // act
      vault.addEntry(siteName: 'Gmail', username: 'user@gmail.com', password: 'password', notes: 'test');
      final newSerialized = vault.serializeVault();
      final newHmac = (jsonDecode(newSerialized) as Map<String, dynamic>)['hmac'];

      // assert
      expect(newHmac, isNot(equals(originalHmac)));
    });

    // 10. Lock vault and verify key dereferenced
    test('Lock vault and verify key dereferenced', () async {
      // arrange
      final vault = VaultCore();
      await vault.createNewVault(masterPassword: 'secureMasterPassword123');

      // act
      vault.lockVault();

      // assert
      expect(vault.isLocked, isTrue);
      expect(vault.vaultKey, isNull);
    });
  });
}
