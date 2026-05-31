class VaultEntry {
  final String id;
  final String siteName;
  final String username;
  final String password;
  final String notes;

  VaultEntry({
    required this.id,
    required this.siteName,
    required this.username,
    required this.password,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'site_name': siteName,
      'username': username,
      'password': password,
      'notes': notes,
    };
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  VaultEntry copyWith({
    String? id,
    String? siteName,
    String? username,
    String? password,
    String? notes,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      siteName: siteName ?? this.siteName,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
    );
  }
}

class EncryptedVaultEntry {
  final String id;
  final String nonce;
  final String ciphertext;

  EncryptedVaultEntry({
    required this.id,
    required this.nonce,
    required this.ciphertext,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nonce': nonce,
      'ciphertext': ciphertext,
    };
  }

  factory EncryptedVaultEntry.fromJson(Map<String, dynamic> json) {
    return EncryptedVaultEntry(
      id: json['id'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
    );
  }
}
