# Kryptix Technical Decisions Log

## Decision Format
Each decision includes:
- **Decision ID**: Unique identifier
- **Date**: When decision was made
- **Category**: Architecture, Security, Performance, UX, Tech Stack, etc.
- **Decision**: What was decided
- **Rationale**: Why this decision
- **Alternatives Considered**: Other options evaluated
- **Trade-offs**: What was given up
- **Impact**: Affected modules and systems

---

## PHASE 1 DECISIONS

### DECISION-001: Architecture - Modular Core + Features Layer
**Date**: 2026-05-30
**Category**: Architecture
**Decision**: Split code into `core/` for reusable cryptographic and vault logic, and `features/` for UI screens and feature-specific controllers.
**Rationale**: 
- Crypto and vault logic can be unit tested independently of UI
- Future desktop or CLI clients can reuse core/ without UI
- Clear separation of concerns
- Easier to audit security-critical code in core/
**Alternatives Considered**:
- Flat structure with everything in features/
- Crypto as external package
**Trade-offs**: Slightly more complex project structure, but significantly better maintainability
**Impact**: All phases depend on this architecture

---

### DECISION-002: Dependency - Flutter Secure Storage for Keystore Integration
**Date**: 2026-05-30
**Category**: Tech Stack, Security
**Decision**: Use `flutter_secure_storage` for Android Keystore and iOS Keychain integration rather than platform channels.
**Rationale**:
- Maintained by Flutter team
- Handles platform differences automatically
- Well-tested and widely used
- Avoids bugs in custom platform channel code
- Direct access to Keystore/Keychain primitives
**Alternatives Considered**:
- Custom platform channels via Kotlin and Swift
- Manual Keystore wrapping in Kotlin
**Trade-offs**: Less fine-grained control, but greatly improved reliability and security
**Impact**: Phase 4 - Auth and Keystore module

---

### DECISION-003: Dependency - PointyCastle for AES-256-GCM
**Date**: 2026-05-30
**Category**: Tech Stack, Security
**Decision**: Use `pointycastle` pure-Dart implementation for AES-256-GCM instead of FFI bindings to OpenSSL.
**Rationale**:
- Pure Dart avoids FFI security issues and binary distribution problems
- No need to bundle native libraries
- Same security guarantees as OpenSSL implementations
- Simpler build pipeline and app size
- More auditable code
**Alternatives Considered**:
- FFI bindings to OpenSSL (boringssl_flutter)
- Platform-specific crypto (Kotlin Cipher on Android, Security framework on iOS)
**Trade-offs**: Slightly slower than optimized native implementations, but acceptable for password manager (not streaming video encryption)
**Impact**: Phase 2 - Crypto module

---

### DECISION-004: Dependency - Argon2 for Key Derivation
**Date**: 2026-05-30
**Category**: Tech Stack, Security
**Decision**: Use `argon2_flutter_web` for Argon2id key derivation with fixed params: memory=262144, iterations=3, parallelism=4.
**Rationale**:
- Argon2id is winner of Password Hashing Competition
- Resistant to GPU, ASIC, and side-channel attacks
- Fixed parameters ensure consistent security across versions
- 262144 KB memory ~= 256 MB, takes ~2-3 seconds on modern device
- Parameters exceed OWASP recommendations
**Alternatives Considered**:
- PBKDF2 (older, less resistant to attacks)
- bcrypt (slower, less memory-hard)
- scrypt (good but less modern)
**Trade-offs**: Slower master password verification (~2-3 seconds), but vastly superior security
**Impact**: Phase 2 - Crypto module, Phase 3 - Vault module, Phase 4 - Auth module

---

### DECISION-005: Dependency - Local Auth for Biometric
**Date**: 2026-05-30
**Category**: Tech Stack, Security, UX
**Decision**: Use `local_auth` for biometric authentication (fingerprint, face recognition) with fallback to PIN/master password.
**Rationale**:
- Official Flutter package
- Integrates with device biometric hardware
- Supports fingerprint, face, iris depending on device
- Handles platform differences
- PIN fallback when biometric unavailable
**Alternatives Considered**:
- Custom biometric implementation via platform channels
- Master password only (lower UX)
**Trade-offs**: Depends on device biometric hardware availability
**Impact**: Phase 4 - Auth and Keystore module

---

### DECISION-006: Security - AES-256-GCM with 12-Byte Nonce
**Date**: 2026-05-30
**Category**: Security, Crypto
**Decision**: Use AES-256-GCM with 96-bit (12-byte) nonce per entry, with fresh random nonce generated for every entry encryption.
**Rationale**:
- AES-256-GCM provides confidentiality and authenticity
- 12-byte nonce is standard for GCM (recommended by NIST)
- Fresh random nonce prevents nonce reuse attacks
- Nonce stored in plaintext with ciphertext (nonce reuse detection is through analysis, not plaintext compromise)
- Total ciphertext per entry: 16 (auth tag) + plaintext_len bytes
**Alternatives Considered**:
- 8-byte nonce (weaker, birthday attacks)
- Deterministic nonce (allows nonce reuse attacks)
- Larger nonce (unnecessary, 12 bytes is standard)
**Trade-offs**: Slightly larger ciphertext size due to stored nonce
**Impact**: Phase 2 - Crypto module, Phase 3 - Vault operations

---

### DECISION-007: Security - HMAC-SHA256 for Vault Integrity
**Date**: 2026-05-30
**Category**: Security, Crypto
**Decision**: Compute HMAC-SHA256 over entire vault JSON before encryption, verify before every decryption attempt.
**Rationale**:
- Prevents tampering with vault file or entries
- HMAC-SHA256 is cryptographically strong
- Catches bit flips, partial overwrites, corruption
- Verification happens before decryption, preventing attacks
- Uses same vault key for authentication
**Alternatives Considered**:
- No integrity check (vulnerable to tampering)
- Authenticated encryption only (GCM already provides per-entry auth, but HMAC adds file-level check)
- Digital signatures (overkill for local file)
**Trade-offs**: Small performance overhead on vault open, but essential security
**Impact**: Phase 2 - Crypto module, Phase 3 - Vault operations

---

### DECISION-008: Security - Master Password Never Stored
**Date**: 2026-05-30
**Category**: Security, Architecture
**Decision**: Master password is never stored anywhere. Only the derived vault key is wrapped and stored. Vault key is verified using a verifier block.
**Rationale**:
- If master password stored, compromise of any component leaks the password
- User cannot change master password without re-encrypting entire vault
- Verifier is hash(vault_key), proves correct key without storing password
- Vault key lives in RAM only while vault unlocked
**Alternatives Considered**:
- Store hashed password (allows password verification without deriving key every time)
- Store plaintext master password (security disaster)
**Trade-offs**: Master password must be re-entered to unlock on app restart
**Impact**: Phase 3 - Vault module, Phase 4 - Auth module

---

### DECISION-009: Security - Vault Key Wrapping via Platform Keystore
**Date**: 2026-05-30
**Category**: Security, Architecture
**Decision**: Vault key is wrapped using Android Keystore and iOS Keychain before storage, only unwrappable on same device.
**Rationale**:
- Prevents theft of vault key even if encrypted vault file compromised
- Device-specific, cannot use stolen key on another device
- Leverages hardware security chips when available
- Standard approach on modern mobile platforms
**Alternatives Considered**:
- Store unwrapped vault key (vulnerable if file system accessed)
- Store master password (decided against separately)
**Trade-offs**: Vault cannot be manually moved between devices; must export/import
**Impact**: Phase 4 - Auth and Keystore module

---

### DECISION-010: Security - Rate Limiting on Wrong Master Password
**Date**: 2026-05-30
**Category**: Security, UX
**Decision**: Wrong master password attempts are rate limited: 5s after 3 attempts, 30s after 5 attempts, 5 mins after 10 attempts.
**Rationale**:
- Protects against brute force attacks
- Progressively increases penalty
- Balances security and usability
- User can still perform unlimited attempts, just with delay
**Alternatives Considered**:
- No rate limiting (vulnerable to brute force)
- Hard lockout after N attempts (poor UX, vault becomes inaccessible)
- Exponential backoff (could lock user out for days)
**Trade-offs**: Slightly slower UX on wrong password
**Impact**: Phase 4 - Auth and Keystore module

---

### DECISION-011: Security - Auto Lock on Background
**Date**: 2026-05-30
**Category**: Security, UX
**Decision**: Vault automatically locks when app goes to background, with configurable timeout (default 5 minutes).
**Rationale**:
- Prevents unauthorized access if device lost or stolen during inactivity
- Wipes vault key from memory
- Clears clipboard
- User can still manually lock anytime
**Alternatives Considered**:
- Never auto lock (poor security)
- Immediate lock on background (poor UX for brief switches)
**Trade-offs**: User must unlock again after timeout; minor UX friction
**Impact**: Phase 4 - Auth and Keystore module, Phase 7 - UI Integration

---

### DECISION-012: Security - Screenshot Prevention
**Date**: 2026-05-30
**Category**: Security, UX
**Decision**: Screenshot prevention enabled on all screens via platform-specific flags.
**Rationale**:
- Prevents accidental screenshots in taskbar/app switcher
- Protects against apps with screenshot permissions
- Standard practice for password managers
- Minimal performance impact
**Alternatives Considered**:
- Allow screenshots (security risk)
**Trade-offs**: Users cannot take screenshots (intentional security feature)
**Impact**: Phase 4 - Auth and Keystore module, Phase 7 - UI Integration

---

### DECISION-013: Dependency - UUID for Entry IDs
**Date**: 2026-05-30
**Category**: Tech Stack, Architecture
**Decision**: Use UUID version 4 (random) for unique entry identifiers instead of sequential numbers or timestamps.
**Rationale**:
- Globally unique, no collision risk
- No ordering information leaked
- Standard practice for distributed systems
- Flutter uuid package is mature and well-tested
**Alternatives Considered**:
- Sequential IDs (risks, information leakage)
- Timestamp-based IDs (potential collisions)
**Trade-offs**: Longer ID strings in vault file, negligible size/perf impact
**Impact**: Phase 3 - Vault module, Phase 7 - UI Integration

---

### DECISION-014: File Format - JSON for .vlt Files
**Date**: 2026-05-30
**Category**: Architecture, Usability
**Decision**: Use JSON for .vlt vault export format instead of binary.
**Rationale**:
- Human-readable for debugging
- Easier to manually inspect or migrate
- Universal support across platforms
- Standard format for data interchange
- Easier to version and migrate schema
**Alternatives Considered**:
- Binary format (smaller, but less inspectable)
- Protobuf (over-engineered for this use case)
**Trade-offs**: Slightly larger file size (encryption provides adequate size obfuscation)
**Impact**: Phase 5 - Export/Import module, Phase 3 - Vault file format

---

### DECISION-015: Folder Structure - No Comments in Code
**Date**: 2026-05-30
**Category**: Code Quality, Documentation
**Decision**: Zero comments in .dart files. All documentation goes into dedicated .md files named after modules (crypto_notes.md, vault_notes.md, etc.).
**Rationale**:
- Code comments get stale and misleading
- Dedicated .md files are more maintainable
- .md files enable rich formatting, examples, diagrams
- Easier to search documentation in one place
- Security decisions documented separately from implementation
**Alternatives Considered**:
- Comments in code (leads to stale documentation)
**Trade-offs**: Slightly more files to maintain, but better information architecture
**Impact**: All phases - applies to all code files

---

### DECISION-016: Validation - Phone home (NO)
**Date**: 2026-05-30
**Category**: Privacy, Philosophy
**Decision**: Application does NOT phone home, call any backend, or check any internet service.
**Rationale**:
- Core promise: fully offline, zero-knowledge
- Any internet call is tracked and breaks privacy promise
- App works in airplane mode
- No telemetry, crash reporting, or usage analytics
**Alternatives Considered**: None, this is non-negotiable
**Trade-offs**: Cannot provide cloud backup, sync, or recovery services
**Impact**: All phases

---

## PHASE 2+ DECISIONS
*To be added as each phase progresses*

---

## Decision Review Process

Before implementing each phase:
1. Review all previous decisions
2. Identify if any conflict with new requirements
3. Update this document with new decisions
4. Ensure all code follows decision guidelines
