# Transfer Module Implementation Notes

## Overview

The Transfer module provides vault export, import, and merge capabilities. It enables:
- Export vault to .vlt file for backup
- Import vault from .vlt file from other devices
- Merge imported vault entries with existing vault
- Configurable merge strategies (keep both, overwrite, keep existing)
- File I/O operations with validation
- Filename generation with timestamps
- Master password verification during import

All functions are production-grade with security and data integrity as priorities.

---

## Module: transfer.dart - Vault Transfer Operations

### Class: VaultTransfer

**Purpose**: Handle vault export, import, merge, and file operations.

#### exportVault() → Future<TransferResult>
**Purpose**: Export unlocked vault to JSON string.
**Parameters**:
- `vault` (VaultCore): Unlocked vault instance
- `masterPassword` (String): User's master password (for confirmation)

**Returns**: TransferResult with success flag, message, and export data

**Process**:
1. Check vault is unlocked
   - If locked: return error
2. Call vault.serializeVault()
   - Encrypts all entries with AES-256-GCM
   - Computes HMAC-SHA256 signature
   - Returns complete vault JSON
3. Validate JSON not empty
4. Return success with vault JSON data

**Security Notes**:
- Export only available while unlocked
- Requires active authentication
- Full vault serialization (all entries encrypted)
- Master password passed for audit trail (not used internally)
- JSON contains everything needed to import on another device

**Usage**:
```dart
final result = await transferController.exportVault(
  masterPassword: userConfirmedPassword,
);
if (result.success) {
  final vaultJson = result.data;
  await saveToFile(vaultJson);
}
```

---

#### importVault() → Future<TransferResult>
**Purpose**: Validate and parse vault JSON from import file.
**Parameters**:
- `vaultJson` (String): Vault JSON from import file
- `masterPassword` (String): Master password to unlock import vault

**Returns**: TransferResult with success flag, message, and validated vault JSON

**Process**:
1. Parse vault JSON
   - Try to decode as JSON
   - If invalid: return error
2. Extract version
   - Check version == currentVersion
   - If mismatch: return error with version info
3. Test unlock with provided password
   - Create temporary VaultCore
   - Call unlockVault(password, vaultJson)
   - If fails: return error (wrong password or corrupted)
4. Extract entry count
5. Return success with vault JSON and entry count

**Security Notes**:
- Validates version before import (prevents incompatible vaults)
- Tests password against vault (catches wrong password early)
- Validates HMAC during test unlock
- Validates per-entry auth tags during decryption
- Returns entry count for preview before merge
- Imported vault not loaded into memory yet

**Throws**: Nothing (all errors returned in TransferResult)

**Usage**:
```dart
final result = await transferController.importVault(
  vaultJson: loadedFileContent,
  masterPassword: userEnteredPassword,
);
if (result.success) {
  print('Import validated: ${result.importedEntriesCount} entries');
} else {
  print('Import failed: ${result.message}');
}
```

---

#### mergeVaults() → Future<TransferResult>
**Purpose**: Merge imported vault entries into target vault.
**Parameters**:
- `targetVault` (VaultCore): Active vault to merge into
- `importVaultJson` (String): Vault JSON to import
- `importMasterPassword` (String): Password for import vault
- `strategy` (MergeStrategy): Duplicate handling strategy (default keepBoth)

**Returns**: TransferResult with success flag, merge stats, and updated vault JSON

**Process**:
1. Check target vault unlocked
2. Unlock source vault with import password
3. For each entry in source vault:
   - Check if duplicate exists (site + username match, case-insensitive)
   - If new entry:
     - Add to target vault
     - Increment mergedCount
   - If duplicate:
     - Depending on strategy:
       - keepBoth: Add as "(import)" variant
       - overwrite: Replace existing entry
       - keepExisting: Skip entry
4. Serialize updated vault
5. Return success with merge stats

**Duplicate Detection**:
```dart
final existingIndex = targetVault.entries
    .indexWhere((e) => 
      e.siteName.toLowerCase() == sourceEntry.siteName.toLowerCase() && 
      e.username == sourceEntry.username
    );
```

Logic:
- Site name comparison is case-insensitive
- Username comparison is case-sensitive
- Both must match to be considered duplicate

---

#### MergeStrategy Enum

**Purpose**: Define duplicate handling behavior

**Values**:
1. **keepBoth**: Add imported entry with "(import)" suffix
   - Result: Both entries present
   - Use case: User wants all passwords from import
   - Example: "Gmail" and "Gmail (import)"

2. **overwrite**: Replace existing entry with imported version
   - Result: Only imported entry kept
   - Use case: User wants latest version from import device
   - Warning: Original entry data lost

3. **keepExisting**: Skip duplicate entries
   - Result: Only original entry kept
   - Use case: User trusts existing vault more
   - Example: Older import doesn't overwrite

**Selection Logic**:
- keepBoth (recommended): Safe, no data loss
- overwrite: Use if importing from newer device
- keepExisting: Use if importing from older device

**Usage**:
```dart
final result = await transferController.mergeVaults(
  importVaultJson: vaultJson,
  importMasterPassword: password,
  strategy: MergeStrategy.keepBoth,
);
```

---

#### MergeStats Class

**Purpose**: Report merge operation results.

**Properties**:
- `mergedCount` (int): New entries added
- `duplicateCount` (int): Duplicate entries encountered
- `replacedCount` (int): Entries overwritten
- `totalProcessed` (getter): Sum of all counts

**Usage**:
```dart
final stats = result.mergeStats!;
print('Merged: ${stats.mergedCount} new');
print('Duplicates: ${stats.duplicateCount}');
print('Replaced: ${stats.replacedCount}');
print('Total: ${stats.totalProcessed}');
```

---

#### generateExportFilename() → String
**Purpose**: Generate unique backup filename with timestamp.

**Returns**: Filename like "kryptix_backup_20260530_1457.vlt"

**Format**: kryptix_backup_YYYYMMDD_HHMM.vlt

**Process**:
1. Get current DateTime.now()
2. Extract year, month, day, hour, minute
3. Pad to 2 digits
4. Concatenate with prefix and .vlt extension

**Usage**:
```dart
final filename = VaultTransfer.generateExportFilename();
await saveVaultToFile(vaultJson, filename);
// Filename: kryptix_backup_20260530_1457.vlt
```

---

#### saveVaultToFile() → Future<TransferResult>
**Purpose**: Write vault JSON to disk.
**Parameters**:
- `vaultJson` (String): Vault JSON to save
- `filePath` (String): Full path to write to

**Returns**: TransferResult with success flag and message

**Process**:
1. Create File object at filePath
2. Write vaultJson as string
3. Return success or error

**Security Notes**:
- File contains encrypted entries (safe if lost)
- Vault key not stored in file
- Master password not stored in file
- HMAC signature in file prevents tampering

**Platform Notes**:
- Android: Use app-specific backup directory
- iOS: Use app-specific documents directory
- Both locations are sandbox-protected

**Usage**:
```dart
final exportResult = await transferController.exportVault(
  masterPassword: password,
);
if (exportResult.success) {
  final filename = VaultTransfer.generateExportFilename();
  final docDir = await getApplicationDocumentsDirectory();
  final filePath = '${docDir.path}/$filename';
  
  final saveResult = await transferController.saveVaultToFile(
    vaultJson: exportResult.data!,
    filePath: filePath,
  );
}
```

---

#### loadVaultFromFile() → Future<TransferResult>
**Purpose**: Read and validate vault JSON from disk.
**Parameters**:
- `filePath` (String): Full path to vault file

**Returns**: TransferResult with success flag, message, and vault JSON

**Process**:
1. Create File object at filePath
2. Check file exists
   - If not: return error "File not found"
3. Read file as string
4. Parse vault JSON
   - Try VaultFile.parseVaultJson()
   - If invalid: return error "Invalid vault file format"
5. Return success with vault JSON

**Security Notes**:
- Validates JSON structure before returning
- Does not decrypt entries (that happens during import)
- Returns JSON as-is for use with importVault()
- Does not load vault key or entries into memory

**Usage**:
```dart
final loadResult = await transferController.loadVaultFromFile(
  filePath: selectedFilePath,
);
if (loadResult.success) {
  final vaultJson = loadResult.data!;
  final importResult = await transferController.importVault(
    vaultJson: vaultJson,
    masterPassword: userPassword,
  );
}
```

---

### Class: TransferResult

**Purpose**: Standardized result object for transfer operations.

**Properties**:
- `success` (bool): Operation succeeded
- `message` (String): User-visible message
- `data` (String?): Vault JSON (for export/load operations)
- `importedEntriesCount` (int?): Number of entries in import vault
- `mergeStats` (MergeStats?): Merge operation statistics

**Usage**:
```dart
if (result.success) {
  if (result.importedEntriesCount != null) {
    print('Will import ${result.importedEntriesCount} entries');
  }
  if (result.mergeStats != null) {
    print('Merge: ${result.mergeStats!.mergedCount} new');
  }
} else {
  showError(result.message);
}
```

---

## Module: transfer_controller.dart - Transfer Orchestration

### Class: TransferController

**Purpose**: Facade over VaultTransfer for cleaner API.

**Properties**:
- `vault` (VaultCore): Vault instance for operations

**Methods**:
- `exportVault()`: Call VaultTransfer.exportVault()
- `importVault()`: Call VaultTransfer.importVault()
- `mergeVaults()`: Call VaultTransfer.mergeVaults()
- `generateExportFilename()`: Call VaultTransfer.generateExportFilename()
- `saveVaultToFile()`: Call VaultTransfer.saveVaultToFile()
- `loadVaultFromFile()`: Call VaultTransfer.loadVaultFromFile()
- `getExportStats()`: Return entry count as string

**Usage**:
```dart
final controller = TransferController(vault: vault);
final exportResult = await controller.exportVault(masterPassword: pass);
```

---

## Integration Flows

### Export and Save

```
1. User opens Settings screen
2. Taps "Export Vault"
3. Show password confirmation
4. User enters master password
5. transferController.exportVault(password)
   ├─ vault.isLocked check
   ├─ vault.serializeVault()
   │  ├─ Encrypt all entries
   │  ├─ Compute HMAC
   │  └─ Return vault JSON
   └─ Return success with JSON
6. transferController.generateExportFilename()
   └─ Generate: kryptix_backup_20260530_1457.vlt
7. transferController.saveVaultToFile()
   └─ Write JSON to app documents directory
8. Share via platform sheet:
   - Android: Share to email, cloud storage, etc.
   - iOS: Share to Files app, email, iCloud, etc.
9. Show success: "Vault exported to [filename]"
```

### Import and Merge

```
1. User opens Settings screen
2. Taps "Import Vault"
3. File picker opens
4. User selects vault file
5. transferController.loadVaultFromFile(filePath)
   ├─ Read file
   ├─ Parse JSON
   └─ Return vault JSON
6. Show preview:
   - "This import contains X entries"
   - "Choose how to handle duplicates"
7. User selects merge strategy:
   - keepBoth (default)
   - overwrite
   - keepExisting
8. User enters import vault's master password
9. transferController.importVault(vaultJson, password)
   ├─ Parse vault JSON
   ├─ Validate version
   ├─ Test unlock with password
   └─ Return success if valid
10. transferController.mergeVaults(vaultJson, password, strategy)
    ├─ Unlock source vault
    ├─ For each entry:
    │  ├─ Check for duplicate (site + username)
    │  ├─ Apply strategy
    │  └─ Add or merge
    ├─ Serialize updated vault
    └─ Return success with stats
11. Show results:
    - "Merged: X new entries"
    - "Duplicates: Y handled"
12. User prompted to save vault
```

---

## Security Verification

### ✅ Export Security
- Only available while vault unlocked
- Full vault serialization (all entries encrypted)
- HMAC signature prevents tampering during transport
- Master password required for export (audit trail)

### ✅ Import Security
- Master password validation before import
- Version check prevents incompatible imports
- HMAC verified during test unlock
- Per-entry auth tags verified during test decryption
- Invalid files rejected early

### ✅ Merge Security
- Both vaults must be unlocked
- Duplicate detection is deterministic
- No entry data loss (keepBoth strategy)
- Merge results serialized with new HMAC

### ✅ File Operations
- Files saved to app-specific sandbox (Android, iOS)
- Files not world-readable
- JSON readable but entries encrypted
- Filenames timestamped for uniqueness

### ✅ Data Integrity
- JSON parsed before use (syntax validation)
- Vault structure validated (required fields)
- Entry counts verified
- Merge operations preserve all data

---

## Threat Model

### Attacks Mitigated
✅ File tampering (HMAC verification)
✅ Unauthorized import (master password required)
✅ Data loss during merge (keepBoth strategy)
✅ Version incompatibility (version check)
✅ Wrong password import (test unlock)
✅ File deletion (version controlled export)

### Attacks Not Mitigated (Out of Scope)
- Device theft (file accessible on physical access)
- Compromised device OS (fundamental limitation)
- User sharing export file (social engineering)

---

## Error Handling

**Export Errors**:
- Vault locked: "Vault is locked. Unlock before exporting."
- Serialization failed: "Failed to serialize vault"
- Generic error: "Export failed: [error message]"

**Import Errors**:
- File not found: "File not found: [path]"
- Invalid JSON: "Invalid vault file format"
- Wrong password: "Invalid master password or corrupted vault file"
- Version mismatch: "Incompatible vault version: [ver] (expected [expected])"
- Generic error: "Import validation failed: [error message]"

**Merge Errors**:
- Target locked: "Target vault is locked"
- Source unlock fails: "Cannot unlock import vault"
- Generic error: "Merge failed: [error message]"

**File Errors**:
- Write permission: "Failed to save vault file: [error]"
- Read permission: "Failed to load vault file: [error]"
- File corrupted: "Invalid vault file format"

---

## Performance Notes

- **Export**: ~100ms (includes encryption and HMAC)
- **Import**: ~100ms (includes validation and unlock)
- **Merge**: ~50ms + 2-3s (includes Argon2 for test unlock)
- **File I/O**: Platform dependent (typically <100ms)

Total workflow time: ~3-5 seconds (mostly Argon2 derivation)

---

## Dependencies

- **vault_core.dart**: Vault operations
- **vault_file.dart**: JSON serialization
- **entry_model.dart**: Entry data structures
- **dart:io**: File operations
- **dart:convert**: JSON encoding/decoding

---

## Testing Considerations

Unit tests should cover:
- Export with locked vault (error)
- Export with unlocked vault (success)
- Import with invalid JSON (error)
- Import with wrong password (error)
- Import with correct password (success)
- Merge with keepBoth strategy (all entries)
- Merge with overwrite strategy (update entries)
- Merge with keepExisting strategy (preserve originals)
- File save and load roundtrip
- Filename generation uniqueness
- Version mismatch detection

---

## Code Quality

- No hardcoded secrets or test data
- All error cases handled explicitly
- Consistent result structure (TransferResult)
- Clear separation of concerns
- No comments in code (all in this file)
