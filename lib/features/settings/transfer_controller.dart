import 'package:kryptix/core/vault/vault_core.dart';
import 'package:kryptix/core/vault/transfer.dart';

class TransferController {
  final VaultCore vault;

  TransferController({required this.vault});

  Future<TransferResult> exportVault({
    required String masterPassword,
  }) async {
    return VaultTransfer.exportVault(
      vault: vault,
      masterPassword: masterPassword,
    );
  }

  Future<TransferResult> importVault({
    required String vaultJson,
    required String masterPassword,
  }) async {
    return VaultTransfer.importVault(
      vaultJson: vaultJson,
      masterPassword: masterPassword,
    );
  }

  Future<TransferResult> mergeVaults({
    required String importVaultJson,
    required String importMasterPassword,
    MergeStrategy strategy = MergeStrategy.keepBoth,
  }) async {
    return VaultTransfer.mergeVaults(
      targetVault: vault,
      importVaultJson: importVaultJson,
      importMasterPassword: importMasterPassword,
      strategy: strategy,
    );
  }

  String generateExportFilename() {
    return VaultTransfer.generateExportFilename();
  }

  Future<TransferResult> saveVaultToFile({
    required String vaultJson,
    required String filePath,
  }) async {
    return VaultTransfer.saveVaultToFile(
      vaultJson: vaultJson,
      filePath: filePath,
    );
  }

  Future<TransferResult> loadVaultFromFile({
    required String filePath,
  }) async {
    return VaultTransfer.loadVaultFromFile(
      filePath: filePath,
    );
  }

  String getExportStats() {
    return 'Vault contains ${vault.entries.length} entries';
  }
}
