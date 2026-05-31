import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileManager {
  static const String _vaultFileName = 'vault.vlt';

  static Future<String> getVaultFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_vaultFileName';
  }

  static Future<bool> vaultFileExists() async {
    try {
      final filePath = await getVaultFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  static Future<void> saveVaultToFile(String vaultJson) async {
    try {
      final filePath = await getVaultFilePath();
      final file = File(filePath);
      await file.writeAsString(vaultJson);
    } catch (e) {
      throw Exception('Failed to save vault file: $e');
    }
  }

  static Future<String> loadVaultFromFile() async {
    try {
      final filePath = await getVaultFilePath();
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Vault file does not exist');
      }
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to load vault file: $e');
    }
  }

  static Future<void> deleteVaultFile() async {
    try {
      final filePath = await getVaultFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete vault file: $e');
    }
  }
}
