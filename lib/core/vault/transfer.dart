import 'dart:io';
import 'vault_core.dart';
import 'vault_file.dart';

class VaultTransfer {
  static Future<TransferResult> exportVault({
    required VaultCore vault,
    required String masterPassword,
  }) async {
    try {
      if (vault.isLocked) {
        return TransferResult(
          success: false,
          message: 'Vault is locked. Unlock before exporting.',
        );
      }

      final vaultJson = vault.serializeVault();

      if (vaultJson.isEmpty) {
        return TransferResult(
          success: false,
          message: 'Failed to serialize vault',
        );
      }

      return TransferResult(
        success: true,
        message: 'Vault exported successfully',
        data: vaultJson,
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  static Future<TransferResult> importVault({
    required String vaultJson,
    required String masterPassword,
  }) async {
    try {
      final vaultData = VaultFile.parseVaultJson(vaultJson);

      final version = VaultFile.extractVersion(vaultData);
      if (version != VaultFile.currentVersion) {
        return TransferResult(
          success: false,
          message:
              'Incompatible vault version: $version (expected ${VaultFile.currentVersion})',
        );
      }

      final testVault = VaultCore();
      final unlockSuccess = await testVault.unlockVault(
        masterPassword: masterPassword,
        vaultJson: vaultJson,
      );

      if (!unlockSuccess) {
        return TransferResult(
          success: false,
          message: 'Invalid master password or corrupted vault file',
        );
      }

      return TransferResult(
        success: true,
        message: 'Vault import validated successfully',
        data: vaultJson,
        importedEntriesCount: testVault.entries.length,
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: 'Import validation failed: $e',
      );
    }
  }

  static Future<TransferResult> mergeVaults({
    required VaultCore targetVault,
    required String importVaultJson,
    required String importMasterPassword,
    MergeStrategy strategy = MergeStrategy.keepBoth,
  }) async {
    try {
      if (targetVault.isLocked) {
        return TransferResult(
          success: false,
          message: 'Target vault is locked',
        );
      }

      final sourceVault = VaultCore();
      final unlockSuccess = await sourceVault.unlockVault(
        masterPassword: importMasterPassword,
        vaultJson: importVaultJson,
      );

      if (!unlockSuccess) {
        return TransferResult(
          success: false,
          message: 'Cannot unlock import vault',
        );
      }

      int mergedCount = 0;
      int duplicateCount = 0;
      int replacedCount = 0;

      for (final sourceEntry in sourceVault.entries) {
        final existingIndex = targetVault.entries
            .indexWhere((e) => e.siteName.toLowerCase() == sourceEntry.siteName.toLowerCase() && e.username == sourceEntry.username);

        if (existingIndex == -1) {
          targetVault.addEntry(
            siteName: sourceEntry.siteName,
            username: sourceEntry.username,
            password: sourceEntry.password,
            notes: sourceEntry.notes,
          );
          mergedCount++;
        } else {
          if (strategy == MergeStrategy.keepBoth) {
            targetVault.addEntry(
              siteName: '${sourceEntry.siteName} (import)',
              username: sourceEntry.username,
              password: sourceEntry.password,
              notes: sourceEntry.notes,
            );
            duplicateCount++;
          } else if (strategy == MergeStrategy.overwrite) {
            targetVault.editEntry(
              entryId: targetVault.entries[existingIndex].id,
              siteName: sourceEntry.siteName,
              username: sourceEntry.username,
              password: sourceEntry.password,
              notes: sourceEntry.notes,
            );
            replacedCount++;
          } else if (strategy == MergeStrategy.keepExisting) {
            duplicateCount++;
          }
        }
      }

      final updatedVaultJson = targetVault.serializeVault();

      return TransferResult(
        success: true,
        message:
            'Merge complete: $mergedCount new, $duplicateCount duplicates, $replacedCount replaced',
        data: updatedVaultJson,
        mergeStats: MergeStats(
          mergedCount: mergedCount,
          duplicateCount: duplicateCount,
          replacedCount: replacedCount,
        ),
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: 'Merge failed: $e',
      );
    }
  }

  static String generateExportFilename() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'kryptix_backup_$timestamp.vlt';
  }

  static Future<TransferResult> saveVaultToFile({
    required String vaultJson,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      await file.writeAsString(vaultJson);

      return TransferResult(
        success: true,
        message: 'Vault saved to $filePath',
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: 'Failed to save vault file: $e',
      );
    }
  }

  static Future<TransferResult> loadVaultFromFile({
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return TransferResult(
          success: false,
          message: 'File not found: $filePath',
        );
      }

      final vaultJson = await file.readAsString();

      try {
        VaultFile.parseVaultJson(vaultJson);
      } catch (e) {
        return TransferResult(
          success: false,
          message: 'Invalid vault file format',
        );
      }

      return TransferResult(
        success: true,
        message: 'Vault loaded from file',
        data: vaultJson,
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: 'Failed to load vault file: $e',
      );
    }
  }
}

enum MergeStrategy {
  keepBoth,
  overwrite,
  keepExisting,
}

class MergeStats {
  final int mergedCount;
  final int duplicateCount;
  final int replacedCount;

  MergeStats({
    required this.mergedCount,
    required this.duplicateCount,
    required this.replacedCount,
  });

  int get totalProcessed => mergedCount + duplicateCount + replacedCount;
}

class TransferResult {
  final bool success;
  final String message;
  final String? data;
  final int? importedEntriesCount;
  final MergeStats? mergeStats;

  TransferResult({
    required this.success,
    required this.message,
    this.data,
    this.importedEntriesCount,
    this.mergeStats,
  });
}
