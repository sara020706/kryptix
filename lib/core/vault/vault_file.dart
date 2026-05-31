import 'dart:typed_data';
import 'dart:convert';
import '../crypto/argon2.dart';
import '../crypto/hmac.dart';
import '../models/entry_model.dart';

class VaultFile {
  static const String currentVersion = '2.4.0';
  static const String appName = 'VaultX';

  static String createVaultJson({
    required List<EncryptedVaultEntry> entries,
    required Argon2Params argon2Params,
    required String verifier,
    required String hmacSignature,
    String? exportedAt,
  }) {
    final vaultData = {
      'version': currentVersion,
      'app_name': appName,
      'exported_at': exportedAt ?? DateTime.now().toUtc().toIso8601String(),
      'argon2': argon2Params.toJson(),
      'verifier': verifier,
      'hmac': hmacSignature,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(vaultData);
  }

  static Map<String, dynamic> parseVaultJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        throw Exception('Vault JSON must be a map');
      }
      return decoded as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse vault JSON: $e');
    }
  }

  static String extractVersion(Map<String, dynamic> vaultData) {
    return vaultData['version'] as String? ?? '1.0.0';
  }

  static String extractVerifier(Map<String, dynamic> vaultData) {
    return vaultData['verifier'] as String? ?? '';
  }

  static String extractHmac(Map<String, dynamic> vaultData) {
    return vaultData['hmac'] as String? ?? '';
  }

  static Argon2Params extractArgon2Params(Map<String, dynamic> vaultData) {
    final argon2Json = vaultData['argon2'] as Map<String, dynamic>?;
    if (argon2Json == null) {
      throw Exception('Missing argon2 parameters in vault');
    }
    return Argon2Params.fromJson(argon2Json);
  }

  static List<EncryptedVaultEntry> extractEntries(
    Map<String, dynamic> vaultData,
  ) {
    final entriesJson = vaultData['entries'] as List? ?? [];
    return entriesJson
        .map((e) => EncryptedVaultEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String createVaultJsonWithoutSignature({
    required List<EncryptedVaultEntry> entries,
    required Argon2Params argon2Params,
    required String verifier,
    String? exportedAt,
  }) {
    final vaultData = {
      'version': currentVersion,
      'app_name': appName,
      'exported_at': exportedAt ?? DateTime.now().toUtc().toIso8601String(),
      'argon2': argon2Params.toJson(),
      'verifier': verifier,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(vaultData);
  }

  static String computeHmacForJson({
    required String vaultJsonWithoutHmac,
    required Uint8List vaultKey,
  }) {
    final jsonBytes = utf8.encode(vaultJsonWithoutHmac);
    final signature = HmacSha256.computeSignature(
      key: vaultKey,
      data: jsonBytes,
    );
    return HmacSha256.encodeSignature(signature);
  }

  static String sanitizeVaultJsonForHmac(String vaultJson) {
    final data = jsonDecode(vaultJson) as Map<String, dynamic>;
    data.remove('hmac');
    return jsonEncode(data);
  }
}
