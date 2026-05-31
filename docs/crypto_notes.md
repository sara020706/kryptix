# Crypto Module Implementation Notes

## Overview

The crypto module provides all cryptographic primitives required by Kryptix:
- **Argon2id**: Memory-hard key derivation from master password
- **AES-256-GCM**: Authenticated encryption for vault entries
- **HMAC-SHA256**: Vault file integrity verification
- **SecureRandom**: Cryptographically secure random generation

All functions are production-grade with no shortcuts or placeholders. Security parameters are hardcoded according to specifications in DECISIONS.md.

---

## Module: random.dart - Secure Random Generation

### Class: SecureRandom

#### generateBytes(int length) → Uint8List
**Purpose**: Generate cryptographically secure random bytes.
**Parameters**:
- `length`: Number of random bytes to generate (must be > 0)

**Returns**: Uint8List of random bytes

**Security**: Uses Dart's `Random.secure()` which is cryptographically strong on all platforms.

**Usage**:
```dart
final randomData = SecureRandom.generateBytes(32);
```

---

#### generateSalt({int length = 32}) → Uint8List
**Purpose**: Generate random salt for key derivation.
**Parameters**:
- `length`: Salt length in bytes (default 32 bytes)

**Returns**: Uint8List containing random salt

**Security Notes**:
- Default 32 bytes (256 bits) exceeds OWASP recommendations
- Longer salts prevent rainbow table attacks
- Each vault creation receives unique salt

**Usage**:
```dart
final salt = SecureRandom.generateSalt(length: 32);
```

---

#### generateNonce({int length = 12}) → Uint8List
**Purpose**: Generate random nonce for AES-GCM encryption.
**Parameters**:
- `length`: Nonce length in bytes (default 12 bytes)

**Returns**: Uint8List containing random nonce

**Security Notes**:
- 12 bytes (96 bits) is NIST standard for GCM mode
- Fresh random nonce generated per entry encryption
- Nonce reuse is only attack vector with same key
- Storing nonce with ciphertext is safe (nonce doesn't need to be secret)

**Usage**:
```dart
final nonce = SecureRandom.generateNonce(length: 12);
```

---

#### generateRandomInRange(int max, int length) → List<int>
**Purpose**: Generate list of random integers within range [0, max).
**Parameters**:
- `max`: Upper bound (exclusive)
- `length`: Number of random integers

**Returns**: List<int> of random values

**Security**: Uses same secure random source as other functions.

**Usage**:
```dart
final randomChars = SecureRandom.generateRandomInRange(94, 16);
for (int codeUnit in randomChars) {
  passwordChars.add(String.fromCharCode(33 + codeUnit));
}
```

---

## Module: argon2.dart - Key Derivation

### Class: Argon2

#### Constants
- **defaultMemory = 262144**: 262 MB, exceeds OWASP recommendations
- **defaultIterations = 3**: Sufficient iterations for desktop/mobile
- **defaultParallelism = 4**: 4 parallel threads
- **defaultSaltLength = 32**: 256 bits

**Security Rationale**: These parameters make brute force attacks infeasible. On a modern device, key derivation takes 2-3 seconds, balancing security and UX.

#### deriveKey() → Future<Argon2Result>
**Purpose**: Derive encryption key from master password using Argon2id.
**Parameters**:
- `password` (String, required): Master password
- `salt` (Uint8List, required): Random salt bytes
- `memory` (int): Memory in KB (default 262144)
- `iterations` (int): Time cost (default 3)
- `parallelism` (int): Parallelism factor (default 4)
- `keyLength` (int): Output key length in bytes (default 32 for AES-256)

**Returns**: Argon2Result containing derived key and hash

**Throws**: Exception if derivation fails

**Security Notes**:
- Async function to prevent UI blocking
- Memory-hard algorithm prevents GPU/ASIC attacks
- Uses Argon2id variant (resistant to side channels)
- Salt must be unique per vault

**Usage**:
```dart
final salt = SecureRandom.generateSalt();
final result = await Argon2.deriveKey(
  password: 'MyMasterPassword',
  salt: salt,
  keyLength: 32,
);
final vaultKey = result.rawBytes;
```

---

#### deriveKeyWithRandomSalt() → Future<Argon2Result>
**Purpose**: Derive key with automatic random salt generation.
**Parameters**: Same as deriveKey() except no salt parameter
- `password` (String, required): Master password
- `memory`, `iterations`, `parallelism`, `keyLength`, `saltLength`: See deriveKey()

**Returns**: Argon2Result with derived key

**Usage**:
```dart
final result = await Argon2.deriveKeyWithRandomSalt(
  password: 'MyMasterPassword',
);
final vaultKey = result.rawBytes;
final salt = result.salt;
```

---

#### generateNewSalt() → Uint8List
**Purpose**: Generate new random salt for vault creation.
**Parameters**:
- `length` (int): Salt length (default 32 bytes)

**Returns**: Uint8List with random salt

**Usage**:
```dart
final salt = Argon2.generateNewSalt();
```

---

### Class: Argon2Params

**Purpose**: Encapsulate Argon2 parameters for storage and transmission.

#### Properties
- `salt` (Uint8List): Random salt used in derivation
- `memory` (int): Memory parameter
- `iterations` (int): Iterations parameter
- `parallelism` (int): Parallelism parameter

#### Constructor
```dart
Argon2Params({
  required Uint8List salt,
  required int memory,
  required int iterations,
  required int parallelism,
})
```

#### withDefaults() factory
**Purpose**: Create Argon2Params with default security parameters.
**Usage**:
```dart
final params = Argon2Params.withDefaults(salt: salt);
```

#### toJson() → Map<String, dynamic>
**Purpose**: Serialize parameters to JSON for vault storage.
**Returns**: Map with salt (base64), memory, iterations, parallelism

**Usage**:
```dart
final paramsJson = params.toJson();
vaultJson['argon2'] = paramsJson;
```

---

#### fromJson() factory
**Purpose**: Deserialize parameters from vault JSON.
**Parameters**: `json` (Map<String, dynamic>)

**Returns**: Argon2Params instance

**Usage**:
```dart
final params = Argon2Params.fromJson(vaultJson['argon2']);
final result = await Argon2.deriveKey(
  password: masterPassword,
  salt: params.salt,
  memory: params.memory,
  iterations: params.iterations,
  parallelism: params.parallelism,
);
```

---

#### Base64 Encoding Functions
- **base64Encode(Uint8List data)**: Encode bytes to base64 string
- **base64Decode(String encoded)**: Decode base64 string to bytes

**Purpose**: Convert binary data (salt, nonce) to JSON-safe strings for vault storage.

---

## Module: aes_gcm.dart - Authenticated Encryption

### Class: AesGcm

#### Constants
- **keyLength = 32**: 256-bit key for AES-256
- **nonceLength = 12**: 96-bit nonce (NIST standard for GCM)
- **tagLength = 16**: 128-bit authentication tag

**Security Rationale**: AES-256-GCM provides both confidentiality and authenticity. 12-byte nonce is standard. Authentication tag prevents tampering.

#### encrypt() → Uint8List
**Purpose**: Encrypt plaintext with AES-256-GCM.
**Parameters**:
- `plaintext` (Uint8List): Data to encrypt
- `key` (Uint8List): 32-byte encryption key
- `nonce` (Uint8List): 12-byte nonce

**Returns**: Uint8List containing ciphertext + authentication tag

**Throws**: Exception if key/nonce length invalid

**Security Notes**:
- Nonce MUST be unique for each encryption with same key
- Nonce reuse is fatal vulnerability
- 16 bytes of auth tag appended to ciphertext
- No associated authenticated data (AAD) used

**Usage**:
```dart
final ciphertext = AesGcm.encrypt(
  plaintext: Uint8List.fromList('password'.codeUnits),
  key: vaultKey,
  nonce: nonce,
);
```

---

#### encryptWithRandomNonce() → Uint8List
**Purpose**: Encrypt plaintext with automatic random nonce generation.
**Parameters**:
- `plaintext` (Uint8List): Data to encrypt
- `key` (Uint8List): 32-byte encryption key

**Returns**: Uint8List containing [nonce (12 bytes) + ciphertext + tag (16 bytes)]

**Usage**:
```dart
final encryptedEntry = AesGcm.encryptWithRandomNonce(
  plaintext: entryJson.encode(),
  key: vaultKey,
);
```

---

#### decrypt() → Uint8List
**Purpose**: Decrypt AES-256-GCM ciphertext and verify authentication tag.
**Parameters**:
- `ciphertext` (Uint8List): Encrypted data + auth tag
- `key` (Uint8List): 32-byte decryption key
- `nonce` (Uint8List): 12-byte nonce used during encryption

**Returns**: Uint8List with decrypted plaintext

**Throws**: Exception with message "authentication tag invalid" if verification fails

**Security Notes**:
- Authentication tag is verified before returning plaintext
- Any tampering with ciphertext causes decryption failure
- Tag verification is constant-time operation
- Prevents padding oracle attacks (GCM doesn't use padding)

**Usage**:
```dart
try {
  final plaintext = AesGcm.decrypt(
    ciphertext: ciphertext,
    key: vaultKey,
    nonce: nonce,
  );
} catch (e) {
  print('Decryption failed: vault may be corrupted');
}
```

---

#### decryptWithEmbeddedNonce() → Uint8List
**Purpose**: Decrypt data that has nonce prepended.
**Parameters**:
- `encryptedData` (Uint8List): [nonce (12 bytes) + ciphertext + tag (16 bytes)]
- `key` (Uint8List): 32-byte decryption key

**Returns**: Uint8List with decrypted plaintext

**Throws**: Exception if data too short or tag invalid

**Usage**:
```dart
final plaintext = AesGcm.decryptWithEmbeddedNonce(
  encryptedData: storedEntry.ciphertext,
  key: vaultKey,
);
```

---

#### encryptToBase64() → String
**Purpose**: Encrypt plaintext and encode to base64 (JSON-safe).
**Parameters**:
- `plaintext` (String): Text to encrypt
- `key` (Uint8List): 32-byte encryption key

**Returns**: Base64-encoded [nonce + ciphertext + tag]

**Usage**:
```dart
final base64Encrypted = AesGcm.encryptToBase64(
  plaintext: 'MySecretPassword',
  key: vaultKey,
);
```

---

#### decryptFromBase64() → String
**Purpose**: Decode base64 and decrypt to plaintext.
**Parameters**:
- `encrypted` (String): Base64-encoded ciphertext
- `key` (Uint8List): 32-byte decryption key

**Returns**: Decrypted string

**Usage**:
```dart
final plaintext = AesGcm.decryptFromBase64(
  encrypted: vaultEntry.ciphertext,
  key: vaultKey,
);
```

---

#### Base64 Helper Functions
- **_toBase64(Uint8List bytes)**: Convert bytes to base64 string
- **_fromBase64(String encoded)**: Convert base64 string to bytes

**Purpose**: JSON serialization of binary data.

---

## Module: hmac.dart - Integrity Verification

### Class: HmacSha256

#### Constants
- **keyLength = 32**: 256-bit key for SHA256-based HMAC

#### computeSignature() → Uint8List
**Purpose**: Compute HMAC-SHA256 signature for vault integrity.
**Parameters**:
- `key` (Uint8List): 32-byte HMAC key (derived vault key)
- `data` (Uint8List): Data to sign (entire vault JSON)

**Returns**: Uint8List containing 32-byte HMAC signature

**Throws**: Exception if key is not 32 bytes

**Security Notes**:
- HMAC prevents tampering with vault file
- Computed over entire serialized vault JSON
- Signature stored in vault metadata
- Verified before every vault unlock

**Usage**:
```dart
final vaultJson = jsonEncode({
  'version': '2.4.0',
  'argon2': argon2Params.toJson(),
  'entries': entries,
});
final signature = HmacSha256.computeSignature(
  key: vaultKey,
  data: Uint8List.fromList(vaultJson.codeUnits),
);
```

---

#### verifySignature() → bool
**Purpose**: Verify HMAC signature matches expected value.
**Parameters**:
- `key` (Uint8List): 32-byte HMAC key
- `data` (Uint8List): Data that was signed
- `expectedSignature` (Uint8List): Previously computed signature

**Returns**: true if signature valid, false otherwise

**Security Notes**:
- Uses constant-time comparison to prevent timing attacks
- Timing should not leak information about signature correctness
- Returns bool (no exception) for cleaner error handling

**Usage**:
```dart
if (!HmacSha256.verifySignature(
  key: vaultKey,
  data: vaultJsonBytes,
  expectedSignature: storedSignature,
)) {
  throw Exception('Vault integrity check failed');
}
```

---

#### encodeSignature(Uint8List signature) → String
**Purpose**: Encode HMAC signature to hex string for JSON storage.
**Parameters**: `signature` (Uint8List)

**Returns**: Hex string (64 characters for SHA256)

**Usage**:
```dart
final signatureHex = HmacSha256.encodeSignature(signature);
vaultJson['hmac'] = signatureHex;
```

---

#### decodeSignature(String encoded) → Uint8List
**Purpose**: Decode hex signature from JSON storage.
**Parameters**: `encoded` (String): Hex-encoded signature

**Returns**: Uint8List with binary signature

**Usage**:
```dart
final signature = HmacSha256.decodeSignature(vaultJson['hmac']);
```

---

#### _constantTimeEquals() → bool
**Purpose**: Compare two byte arrays in constant time.
**Security**: Prevents timing attacks where signature comparison time leaks information about correctness.

---

#### Hex Encoding Functions
- **_toHex(Uint8List bytes)**: Convert bytes to hex string
- **_fromHex(String hex)**: Convert hex string to bytes

**Purpose**: JSON-safe encoding of binary signatures.

---

## Integration Flow

### Vault Creation (First Time Setup)
```
1. User enters master password
2. salt = SecureRandom.generateSalt()
3. vaultKey = await Argon2.deriveKey(password, salt)
4. verifier = hash(vaultKey)  // Stored to verify password later
5. nonce = SecureRandom.generateNonce()
6. entry = {site, username, password, notes}
7. ciphertext = AesGcm.encryptWithRandomNonce(entry, vaultKey)
8. vaultJson = {argon2_params, entries: [ciphertext]}
9. signature = HmacSha256.computeSignature(vaultKey, vaultJson)
10. Write vault file with signature and encrypted entries
```

### Vault Unlock (Subsequent Opens)
```
1. User enters master password
2. Load vault file from disk
3. Extract argon2 params (salt, memory, iterations, parallelism)
4. vaultKey = await Argon2.deriveKey(password, salt, params)
5. signature = HmacSha256.computeSignature(vaultKey, vaultJson)
6. Verify: stored_signature == computed_signature
   - If mismatch: Password wrong or file corrupted
   - If match: Continue
7. For each entry: decrypt = AesGcm.decryptWithEmbeddedNonce(ciphertext, vaultKey)
8. Vault unlocked, entries available in RAM
```

### Entry Operations (Add/Edit)
```
1. Vault must be unlocked (have vaultKey in RAM)
2. Create entry JSON: {site, username, password, notes}
3. nonce = SecureRandom.generateNonce()
4. ciphertext = AesGcm.encryptWithRandomNonce(entry, vaultKey)
5. Store entry: {id: uuid, nonce (embedded), ciphertext}
6. Recompute vault HMAC: signature = HmacSha256.computeSignature(vaultKey, updatedVaultJson)
7. Write updated vault file with new signature
```

### Key Security Properties Maintained

✅ **No plaintext master password ever stored**
✅ **Vault key derives uniquely from password each time**
✅ **Fresh random nonce per entry (no reuse)**
✅ **HMAC verifies before decryption (integrity first)**
✅ **Encryption uses standard AES-256-GCM (peer-reviewed)**
✅ **Key derivation uses Argon2id (memory-hard, resistant to attacks)**
✅ **All random uses cryptographically secure PRNG**

---

## Dependencies

- **pointycastle**: AES-256-GCM and SHA256/HMAC implementation
- **argon2_flutter_web**: Argon2id key derivation
- **dart:typed_data**: Uint8List for binary data
- **dart:math**: Random.secure() for CSPRNG

---

## Testing Considerations

Each function should be unit tested:
- **SecureRandom**: Verify distribution, uniqueness
- **Argon2**: Verify parameters, determinism with same input
- **AesGcm**: Verify encryption/decryption roundtrip, tag verification failure
- **HmacSha256**: Verify signature validity, constant-time comparison

---

## Performance Notes

- **Argon2**: 2-3 seconds (by design - security over speed)
- **AES-GCM**: ~milliseconds for typical entry size
- **HMAC-SHA256**: ~milliseconds for vault JSON
- **Random generation**: Negligible overhead

Performance is acceptable for a password manager where operations are infrequent.

---

## Threat Model

### Attacks Mitigated
✅ Brute force master password (Argon2 memory-hard)
✅ Rainbow tables (unique salt per vault)
✅ Tampering with vault file (HMAC verification)
✅ Known-plaintext attacks on entries (fresh nonce per entry)
✅ Timing attacks on HMAC verification (constant-time comparison)
✅ GPU/ASIC attacks (Argon2id memory-hard variant)

### Attacks Not Mitigated (Out of Scope)
- Physical device extraction of vault key (mitigated by Keystore/Keychain wrapping in Phase 4)
- Compromised device OS (fundamental limitation)
- Weak master password chosen by user (UX responsibility)

---

## Code Quality

- No hardcoded secrets or test vectors in code
- All security parameters come from DECISIONS.md
- All functions are pure (deterministic given same inputs)
- All functions handle errors explicitly
- No TODO or placeholder code
- Zero comments in code (documentation in this file)
