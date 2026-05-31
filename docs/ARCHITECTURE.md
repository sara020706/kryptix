# Kryptix Architecture

## System Overview

Kryptix is a zero-knowledge, fully offline password manager for Flutter. All data is encrypted locally on the device using military-grade AES-256-GCM encryption. No backend servers, no internet connectivity required.

### Core Philosophy
- **Zero-Knowledge**: Kryptix cannot access any user data; all encryption happens on device
- **Fully Offline**: No network calls, no cloud sync, complete local autonomy
- **Military-Grade Security**: AES-256-GCM, Argon2id key derivation, HMAC integrity verification
- **Platform Integration**: Android Keystore and iOS Secure Enclave for key wrapping

## Project Structure

```
kryptix_app/
├── lib/
│   ├── core/
│   │   ├── crypto/              # Cryptographic primitives
│   │   │   ├── aes_gcm.dart     # AES-256-GCM encrypt/decrypt
│   │   │   ├── argon2.dart      # Argon2id key derivation
│   │   │   ├── hmac.dart        # HMAC-SHA256 verification
│   │   │   └── random.dart      # Secure random generation
│   │   ├── vault/               # Vault operations
│   │   │   ├── vault_file.dart  # .vlt file read/write
│   │   │   ├── vault_core.dart  # Lock/unlock/verifier logic
│   │   │   └── entry.dart       # Vault entry model
│   │   ├── auth/                # Authentication
│   │   │   ├── keystore.dart    # Platform keystore integration
│   │   │   ├── biometric.dart   # Biometric unlock
│   │   │   └── auth_state.dart  # Auth state management
│   │   ├── storage/             # File I/O
│   │   │   └── file_manager.dart
│   │   └── models/              # Data models
│   │       ├── vault_model.dart
│   │       └── entry_model.dart
│   ├── features/
│   │   ├── auth/                # Master password and biometric screens
│   │   │   ├── screens/
│   │   │   └── controllers/
│   │   ├── dashboard/           # Main password list screen
│   │   │   ├── screens/
│   │   │   └── controllers/
│   │   ├── generator/           # Password generator screen
│   │   │   ├── screens/
│   │   │   └── controllers/
│   │   └── settings/            # Settings and security options
│   │       ├── screens/
│   │       └── controllers/
│   ├── shared/
│   │   ├── widgets/             # Reusable UI components
│   │   ├── theme/               # Material 3 theme from DESIGN.md
│   │   └── constants/           # App-wide constants
│   ├── app.dart                 # Main app widget
│   └── main.dart                # Entry point
├── test/
├── android/
├── ios/
├── assets/
│   └── fonts/
├── ARCHITECTURE.md              # This file
├── PROGRESS.md                  # What's done, in progress, pending
├── DECISIONS.md                 # Technical decisions and rationale
├── phase_1_report.md            # Phase 1 completion report
├── phase_2_report.md            # Phase 2 completion report (when done)
├── crypto_notes.md              # Crypto implementation details (when done)
├── vault_notes.md               # Vault implementation details (when done)
├── auth_notes.md                # Auth implementation details (when done)
├── transfer_notes.md            # Export/import details (when done)
├── generator_notes.md           # Generator details (when done)
├── ui_notes.md                  # UI integration details (when done)
├── security_audit.md            # Security findings (when done)
└── README.md
```

## Data Flow Architecture

### Initialization Flow
1. App launches → Check for existing vault
2. If no vault: Show master password setup screen
3. If vault exists: Show unlock screen
4. On successful unlock: Load encrypted vault from storage → Decrypt → Load dashboard

### Master Password Flow
1. User enters master password
2. Derive vault key using Argon2id(password, salt)
3. Generate verifier block hash and compare with stored verifier
4. On match: Wrap vault key using Keystore → Store wrapped key → Mark as unlocked
5. On mismatch: Rate limit and show error

### Vault Unlock Flow
1. Biometric/PIN attempt → Retrieve wrapped vault key from Keystore
2. Unwrap vault key → Check HMAC signature of vault file
3. On valid HMAC: Decrypt entries using AES-256-GCM
4. Load entries into memory → Dashboard ready

### Vault Lock Flow
1. User navigates to background / manual lock
2. Wipe vault key from memory
3. Clear clipboard
4. Mark as locked
5. Show unlock screen on return

### Add/Edit Entry Flow
1. User provides site name, username, password, notes
2. Generate random nonce
3. Encrypt all data using AES-256-GCM with vault key
4. Store entry with: {id, nonce, ciphertext}
5. Recalculate vault file HMAC signature
6. Write updated vault to disk
7. Update dashboard

### Export Flow
1. User navigates to settings → Export Vault
2. Ask for master password confirmation
3. Serialize vault to .vlt JSON format
4. Trigger Android share sheet / iOS file sharing
5. User selects destination

### Import Flow
1. User opens .vlt file
2. Ask for master password to verify
3. Derive key using stored Argon2 params
4. Verify HMAC
5. Decrypt entries
6. Merge with existing vault or replace
7. Update vault file on disk

## Encryption Model

### .vlt File Format (JSON)
```json
{
  "version": "2.4.0",
  "app_name": "Kryptix",
  "exported_at": "2026-05-30T10:30:00Z",
  "argon2": {
    "salt": "base64_encoded_salt",
    "memory": 262144,
    "iterations": 3,
    "parallelism": 4
  },
  "verifier": "base64_encoded_verifier_hash",
  "hmac": "base64_encoded_hmac_signature",
  "entries": [
    {
      "id": "uuid",
      "nonce": "base64_encoded_12_bytes",
      "ciphertext": "base64_encoded_encrypted_data"
    }
  ]
}
```

### Entry Plaintext Structure (Before Encryption)
```json
{
  "site_name": "Gmail",
  "username": "user@gmail.com",
  "password": "secure_password_123",
  "notes": "Recovery email: backup@example.com"
}
```

### Encryption Parameters
- **Algorithm**: AES-256-GCM
- **Key Size**: 256 bits (32 bytes) derived from master password
- **Nonce Size**: 96 bits (12 bytes), unique per entry, never reused
- **Auth Tag Size**: 128 bits (16 bytes)
- **Key Derivation**: Argon2id(password, salt, memory=262144, iterations=3, parallelism=4)
- **Vault Integrity**: HMAC-SHA256(vault_key, vault_json)

## Security Model

### Master Password
- Never stored anywhere in plain text
- Never transmitted to any backend
- Used only to derive vault key via Argon2id
- Verified using verifier block (hash of vault key)

### Vault Key
- Lives in RAM only while vault is unlocked
- Derived from master password using Argon2id
- Wrapped by Android Keystore / iOS Secure Enclave
- Wiped from memory on app background
- Wiped from memory on manual lock

### Nonce Management
- Fresh random 12-byte nonce generated per entry
- Never reused for same vault key
- Stored with entry in plaintext (nonce reuse is attack vector, not plaintext compromise)

### Integrity Verification
- HMAC-SHA256 signature computed on entire vault JSON
- Verified before every decryption attempt
- Prevents tampering with vault file

### Key Wrapping
- Android: Keystore wraps vault key with device hardware key
- iOS: Secure Enclave wraps vault key via flutter_secure_storage
- Wrapped key stored on disk, only unwrappable by same device

### Rate Limiting
- Wrong master password attempts rate limited
- After 3 failed attempts: 5 second delay
- After 5 failed attempts: 30 second delay
- After 10 failed attempts: 5 minute delay

### Auto Lock
- Configurable timeout: default 5 minutes
- Triggered on app background
- Triggered on manual lock
- Preserves encrypted vault file on disk

### Screenshot Prevention
- Enabled on all screens to prevent sensitive data leaks
- Prevents taskbar/app switcher screenshots

## Module Responsibilities

### Core.Crypto
- Argon2id key derivation
- AES-256-GCM encryption and decryption
- HMAC-SHA256 verification
- Cryptographically secure random generation

### Core.Vault
- Vault file I/O (.vlt format)
- Vault creation with verifier block
- Entry operations (add, edit, delete)
- Vault lock and unlock operations

### Core.Auth
- Master password setup and verification
- Vault key wrapping via Keystore/Keychain
- Biometric and PIN unlock via local_auth
- Fallback to master password
- Wrong attempt rate limiting
- Auto lock on background

### Features.*
- UI screens and user interactions
- Input validation
- Error handling and user feedback
- State management

## Dependencies and Rationale

| Package | Purpose | Security Notes |
|---------|---------|-----------------|
| flutter_secure_storage | Secure key storage | Uses Android Keystore and iOS Keychain |
| local_auth | Biometric unlock | Integrates with device biometric hardware |
| uuid | Unique entry IDs | For vault entry identification |
| path_provider | File paths | Locates app documents directory |
| pointycastle | AES-256-GCM | Pure Dart implementation, no FFI needed |
| argon2_flutter_web | Argon2id | Performs CPU-intensive key derivation |

## Phase Breakdown

- **Phase 1**: Project setup and architecture (current)
- **Phase 2**: Crypto module implementation
- **Phase 3**: Vault module implementation
- **Phase 4**: Auth and Keystore module
- **Phase 5**: Export and Import module
- **Phase 6**: Password Generator module
- **Phase 7**: UI Integration
- **Phase 8**: Security Audit and Hardening

## Technology Stack

- **Language**: Dart
- **Framework**: Flutter
- **Minimum SDK**: Flutter 3.13.0, Dart 3.0.0
- **Target**: iOS 12.0+, Android 5.0+
- **Encryption**: AES-256-GCM, Argon2id, HMAC-SHA256
- **Platform Integration**: Android Keystore, iOS Secure Enclave

## Design References

Refer to `frontend reference/kryptix/DESIGN.md` for complete Material 3 theme and UI specifications including colors, typography, spacing, and rounded corners.

## No Backend

This application is fundamentally offline:
- No account creation
- No cloud sync
- No backup servers
- No internet connectivity required
- Vault is a local file on device
- Export/import is manual via file sharing

Each device has its own completely independent vault. Data does not leave the device except during manual export.
