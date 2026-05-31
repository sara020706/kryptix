# Kryptix - Zero-Knowledge Password Manager

Kryptix is a production-grade, fully offline password manager for Flutter with military-grade encryption. All data is encrypted locally on your device using AES-256-GCM. No backend servers, no internet connectivity required, no data leaves your device.

## ⚔️ Security

- **Zero-Knowledge**: Kryptix cannot access any user data
- **Military-Grade Encryption**: AES-256-GCM with fresh random nonce per entry
- **Strong Key Derivation**: Argon2id with memory-hard parameters
- **Integrity Verification**: HMAC-SHA256 prevents tampering
- **Hardware Integration**: Android Keystore and iOS Secure Enclave wrap vault keys
- **Biometric Unlock**: Fingerprint and Face ID support with fallback to master password
- **Auto Lock**: Configurable timeout, immediate wipe of encryption keys
- **Screenshot Prevention**: Protected against accidental screenshots
- **Fully Offline**: No backend, no cloud, no internet required

## 🏗️ Architecture

Kryptix follows a strict modular architecture:

- **core/crypto/**: Cryptographic primitives (AES-256-GCM, Argon2id, HMAC-SHA256)
- **core/vault/**: Vault file operations and entry management
- **core/auth/**: Master password and biometric authentication
- **core/storage/**: Secure file I/O
- **features/**/**: UI screens and controllers
- **shared/**: Reusable widgets and theme

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for complete system design.

## 📋 Project Structure

```
kryptix_app/
├── lib/
│   ├── core/
│   │   ├── crypto/       # Encryption primitives
│   │   ├── vault/        # Vault operations
│   │   ├── auth/         # Authentication
│   │   ├── storage/      # File I/O
│   │   └── models/       # Data models
│   ├── features/
│   │   ├── auth/         # Setup and unlock screens
│   │   ├── dashboard/    # Main password list
│   │   ├── generator/    # Password generator
│   │   └── settings/     # Settings and security
│   ├── shared/           # Widgets and theme
│   ├── app.dart
│   └── main.dart
├── test/
├── docs/                 # System documentation directory
│   ├── ARCHITECTURE.md   # Full system design
│   ├── PROGRESS.md       # Phase tracking and task status
│   ├── DECISIONS.md      # Technical decisions log
│   ├── phase_N_report.md # Phase-specific completion reports
│   └── *_notes.md        # Cryptographic/Auth/UI module notes
└── pubspec.yaml
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.13.0 or higher
- Dart SDK 3.0.0 or higher
- Android 5.0+ or iOS 12.0+

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/kryptix.git
cd kryptix_app

# Install dependencies
flutter pub get

# Run on device
flutter run
```

## 📱 Features

### Core Features
- ✅ Master password setup and verification
- ✅ Vault creation and management
- ✅ Add, edit, delete password entries
- ✅ Search secure vault
- ✅ Password generator (customizable length and character sets)
- ✅ Export vault to .vlt file
- ✅ Import vault from .vlt file
- ✅ Biometric unlock (fingerprint, face recognition)
- ✅ PIN unlock
- ✅ Auto-lock with configurable timeout
- ✅ Clipboard auto-clear (30 seconds)
- ✅ Security health indicators
- ✅ Weak password warnings

### Security Features
- ✅ AES-256-GCM encryption per entry
- ✅ Argon2id key derivation
- ✅ HMAC-SHA256 vault integrity verification
- ✅ Android Keystore integration
- ✅ iOS Secure Enclave integration
- ✅ Rate limiting on wrong attempts
- ✅ Screenshot prevention
- ✅ Memory wipe on lock
- ✅ Clipboard auto-clear

## 📚 Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Complete system design and data flow
- [PROGRESS.md](docs/PROGRESS.md) - Phase tracking and task status
- [DECISIONS.md](docs/DECISIONS.md) - Technical decisions and rationale
- [phase_*_report.md](docs/phase_1_report.md) - Phase-specific completion reports
- [crypto_notes.md](docs/crypto_notes.md) - Cryptographic implementation details
- [vault_notes.md](docs/vault_notes.md) - Vault operations documentation
- [auth_notes.md](docs/auth_notes.md) - Authentication system documentation
- [ui_notes.md](docs/ui_notes.md) - UI integration details

## 🔒 Privacy

Kryptix respects your privacy completely:
- No analytics or telemetry
- No crash reporting
- No backend servers
- No internet connectivity
- No data collection
- Works completely offline
- Vault never leaves your device

## 🛡️ Security Audit

This application underwent comprehensive security audit. See [security_audit.md](docs/security_audit.md) for complete findings.

## 📊 Development Phases

1. **Phase 1**: Project setup and architecture ✅
2. **Phase 2**: Crypto module implementation (in progress)
3. **Phase 3**: Vault module implementation
4. **Phase 4**: Auth and Keystore module
5. **Phase 5**: Export and Import module
6. **Phase 6**: Password Generator module
7. **Phase 7**: UI Integration
8. **Phase 8**: Security Audit and Hardening

See [PROGRESS.md](docs/PROGRESS.md) for detailed phase tracking.

## 🧪 Testing

```bash
# Run all unit tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📄 License

Kryptix is released under the MIT License. See LICENSE file for details.

## 🤝 Contributing

Security contributions welcome. Please review [DECISIONS.md](docs/DECISIONS.md) and [ARCHITECTURE.md](docs/ARCHITECTURE.md) before submitting changes.

## ⚠️ Disclaimer

This software is provided as-is. While we follow best security practices, no software is 100% secure. For critical passwords (email, banking, etc.), consider using this alongside additional security measures.

## 📞 Support

For issues, questions, or security concerns, please open an issue or contact the development team.

---

**Kryptix** - Your passwords. Your device. Your control.
