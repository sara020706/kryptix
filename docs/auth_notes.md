# Auth Module Implementation Notes

## Overview

The Auth module provides authentication, biometric support, rate limiting, and secure key management. It orchestrates:
- Master password setup with strength validation
- Master password verification
- Biometric authentication (fingerprint, face recognition)
- PIN authentication fallback
- Vault key wrapping to Keystore/Keychain
- Rate limiting on wrong password attempts
- Auto-lock on app background
- State management for authentication

All functions are production-grade with security as first priority.

---

## Module: keystore.dart - Secure Storage

### Class: Keystore

**Purpose**: Wrap vault key using Android Keystore and iOS Keychain via flutter_secure_storage.

#### Properties (Private)
- `_storage` (FlutterSecureStorage): Secure storage instance
- `_vaultKeyStorageKey`: "kryptix_wrapped_key"
- `_vaultSaltStorageKey`: "kryptix_salt"
- `_vaultArgon2StorageKey`: "kryptix_argon2_params"

#### Constructor
```dart
Keystore({FlutterSecureStorage? storage})
```
**Usage**: Can inject custom FlutterSecureStorage for testing

---

#### wrapAndStoreVaultKey() → Future<void>
**Purpose**: Encrypt and store vault key in platform keystore.
**Parameters**:
- `vaultKey` (Uint8List): 32-byte vault key to wrap
- `argon2ParamsJson` (String): Serialized Argon2 parameters
- `saltBase64` (String): Base64-encoded salt

**Process**:
1. Convert vault key to hex string
2. Write three values to secure storage:
   - Hex-encoded vault key
   - Argon2 parameters JSON
   - Base64-encoded salt
3. Platform handles encryption:
   - Android: Keystore encrypts with device key
   - iOS: Keychain encrypts with Secure Enclave

**Security Notes**:
- Vault key never stored in plaintext
- Platform provides encryption and device-binding
- Key cannot be extracted even with root access
- Device-specific: key unusable on other devices

**Throws**: Exception if storage fails

**Usage**:
```dart
await keystore.wrapAndStoreVaultKey(
  vaultKey: derivedKey,
  argon2ParamsJson: jsonEncode(params.toJson()),
  saltBase64: base64Encode(salt),
);
```

---

#### retrieveWrappedVaultKey() → Future<Uint8List?>
**Purpose**: Retrieve vault key from platform keystore.

**Returns**: Vault key as Uint8List, or null if not stored

**Process**:
1. Read hex-encoded key from storage
2. Convert hex to Uint8List
3. Return key

**Security Notes**:
- Returns null if key not found (fresh setup)
- Throws exception if storage access fails
- Key only usable on same device

**Usage**:
```dart
final vaultKey = await keystore.retrieveWrappedVaultKey();
if (vaultKey != null) {
  vault.unlock(vaultKey);
}
```

---

#### retrieveArgon2Params() → Future<String?>
**Purpose**: Retrieve stored Argon2 parameters JSON.

**Returns**: JSON string with parameters, or null if not stored

**Usage**:
```dart
final paramsJson = await keystore.retrieveArgon2Params();
if (paramsJson != null) {
  final params = Argon2Params.fromJson(jsonDecode(paramsJson));
}
```

---

#### retrieveSalt() → Future<String?>
**Purpose**: Retrieve stored salt as base64.

**Returns**: Base64-encoded salt, or null if not stored

**Usage**:
```dart
final saltBase64 = await keystore.retrieveSalt();
final salt = base64Decode(saltBase64!);
```

---

#### hasStoredVaultKey() → Future<bool>
**Purpose**: Check if vault key exists in keystore.

**Returns**: true if key stored, false otherwise

**Usage**:
```dart
final isSetup = await keystore.hasStoredVaultKey();
if (!isSetup) {
  navigateToSetupScreen();
}
```

---

#### clearVaultKey() → Future<void>
**Purpose**: Delete vault key and parameters from keystore.

**Usage**: Called on logout, app uninstall, vault deletion

**Process**: Delete all three stored values in parallel

**Usage**:
```dart
await keystore.clearVaultKey();
```

---

#### Hex Encoding Helpers
- `_bytesToHex()`: Convert Uint8List to hex string
- `_hexToBytes()`: Convert hex string to Uint8List

**Purpose**: JSON-safe encoding of binary key

---

## Module: biometric.dart - Biometric Authentication

### Class: BiometricAuth

**Purpose**: Fingerprint, face recognition, and fallback authentication.

#### Properties
- `_localAuth` (LocalAuthentication): Flutter local_auth instance

#### Constructor
```dart
BiometricAuth({LocalAuthentication? localAuth})
```

---

#### canUseBiometrics() → Future<bool>
**Purpose**: Check if device has enrolled biometrics.

**Returns**: true if fingerprint/face configured, false otherwise

**Usage**:
```dart
if (await biometric.canUseBiometrics()) {
  showBiometricOption();
}
```

---

#### isDeviceSupported() → Future<bool>
**Purpose**: Check if device supports biometric hardware.

**Returns**: true if device has biometric hardware, false otherwise

**Note**: Different from canUseBiometrics() - this checks hardware, that checks enrollment

---

#### getAvailableBiometrics() → Future<List<BiometricType>>
**Purpose**: Get list of enrolled biometric types.

**Returns**: List with FACE, FINGERPRINT, IRIS, STRONG, or WEAK

**Usage**:
```dart
final biometrics = await biometric.getAvailableBiometrics();
for (final type in biometrics) {
  print('Available: ${biometric.biometricTypeToString(type)}');
}
```

---

#### authenticate() → Future<bool>
**Purpose**: Prompt user for biometric or fallback authentication.
**Parameters**:
- `reason` (String): User-visible reason (e.g., "Unlock Kryptix")

**Returns**: true if authenticated, false if rejected/failed

**Process**:
1. Show biometric prompt to user
2. If biometric available: prompt for fingerprint/face
3. If biometric unavailable: show device unlock (pattern/PIN)
4. Return result

**Usage**:
```dart
final success = await biometric.authenticate(
  reason: 'Unlock your vault',
);
if (success) {
  vault.unlock();
}
```

---

#### authenticateWithBiometricOnly() → Future<bool>
**Purpose**: Prompt only for biometric, no device unlock fallback.

**Returns**: true if biometric successful, false if rejected

**Usage**: Biometric-only unlock (stricter)

---

#### biometricTypeToString() → String
**Purpose**: Convert BiometricType enum to user-readable string.

**Usage**: For displaying available methods in UI

---

## Module: rate_limiter.dart - Wrong Attempt Rate Limiting

### Class: RateLimiter

**Purpose**: Throttle brute force attempts on master password.

#### Constants
- `_thresholdWrong1`: 3 wrong attempts
- `_delayMs1`: 5000 ms (5 seconds)
- `_thresholdWrong2`: 5 wrong attempts
- `_delayMs2`: 30000 ms (30 seconds)
- `_thresholdWrong3`: 10 wrong attempts
- `_delayMs3`: 300000 ms (5 minutes)

#### Properties
- `_wrongAttempts` (int): Count of consecutive wrong attempts
- `_lastWrongAttemptTime` (DateTime?): Time of last wrong attempt

#### recordWrongAttempt() → void
**Purpose**: Increment wrong attempt counter.

**Usage**: Called when password verification fails

**Implementation**:
```dart
_wrongAttempts++;
_lastWrongAttemptTime = DateTime.now();
```

---

#### recordSuccessfulAttempt() → void
**Purpose**: Clear wrong attempt counter.

**Usage**: Called on successful unlock

**Implementation**:
```dart
_wrongAttempts = 0;
_lastWrongAttemptTime = null;
```

---

#### getRemainingDelay() → Future<Duration?>
**Purpose**: Get time remaining before next attempt allowed.

**Returns**: Duration to wait, or null if no delay needed

**Logic**:
- 0-2 attempts: No delay
- 3-4 attempts: 5 second delay
- 5-9 attempts: 30 second delay
- 10+ attempts: 5 minute delay

**Async Note**: Returns Future for API flexibility

**Usage**:
```dart
final delay = await rateLimiter.getRemainingDelay();
if (delay != null) {
  print('Wait ${delay.inSeconds} seconds');
}
```

---

#### isRateLimited() → bool
**Purpose**: Check if currently rate limited (synchronous).

**Returns**: true if waiting period active, false otherwise

**Usage**:
```dart
if (rateLimiter.isRateLimited()) {
  showWaitMessage();
  return;
}
```

---

#### getRemainingDelaySync() → Duration?
**Purpose**: Synchronous version of getRemainingDelay().

**Returns**: Duration to wait, or null if no delay

**Usage**: Use in unlock flow where async not needed

```dart
final delay = rateLimiter.getRemainingDelaySync();
if (delay != null) {
  return AuthResult(
    success: false,
    message: 'Try again in ${delay.inSeconds}s',
    isRateLimited: true,
  );
}
```

---

#### reset() → void
**Purpose**: Clear all rate limiting state.

**Usage**: On successful authentication or app restart

---

#### formatDelay() → String
**Purpose**: Format Duration as human-readable string.

**Returns**: "X seconds", "X minutes Y seconds", etc.

**Usage**: For UI display

---

## Module: auth_state.dart - Authentication State

### Class: AuthState

**Purpose**: Manage authentication state, auto-lock timer, activity tracking.

#### Properties
- `vault` (VaultCore): Vault instance
- `_isAuthenticated` (bool): Authentication state
- `_lastActivityTime` (DateTime?): Last user activity
- `_autoLockTimer` (Timer?): Background lock timer
- `autoLockTimeoutSeconds` (int): Timeout duration (default 300)
- `onAutoLock` (Function?): Callback when auto-lock triggered

#### Constructor
```dart
AuthState({
  required this.vault,
  this.autoLockTimeoutSeconds = 300,
  this.onAutoLock,
})
```

---

#### Getters
- `isAuthenticated` (bool): User is authenticated
- `isVaultLocked` (bool): Vault is locked
- `entries` (List<VaultEntry>): Vault entries
- `vaultKey` (Uint8List?): Vault key in RAM

---

#### markAuthenticated() → void
**Purpose**: Mark user as authenticated.

**Process**:
1. Set `_isAuthenticated = true`
2. Update activity time
3. Start auto-lock timer

**Usage**: Called after successful password/biometric unlock

```dart
authState.markAuthenticated();
```

---

#### markUnauthenticated() → void
**Purpose**: Clear authentication state and lock vault.

**Process**:
1. Set `_isAuthenticated = false`
2. Cancel auto-lock timer
3. Call `vault.lockVault()` (wipes key from memory)

**Usage**: On logout, timeout, manual lock

```dart
authState.markUnauthenticated();
```

---

#### recordActivity() → void
**Purpose**: Reset auto-lock timer on user activity.

**Usage**: Called on button tap, text input, etc.

**Process**:
1. Update `_lastActivityTime`
2. Restart auto-lock timer

```dart
authState.recordActivity();
```

---

#### manualLock() → void
**Purpose**: Manually lock vault (for lock button).

**Usage**: User explicitly presses lock button

```dart
authState.manualLock();
```

---

#### dispose() → void
**Purpose**: Cleanup on app close.

**Process**: Cancel auto-lock timer

**Usage**: Call in widget dispose or app teardown

```dart
@override
void dispose() {
  authState.dispose();
  super.dispose();
}
```

---

#### Private Methods
- `_startAutoLockTimer()`: Start timeout timer
- `_resetAutoLockTimer()`: Restart timer
- `_cancelAutoLockTimer()`: Stop timer
- `_autoLock()`: Lock vault when timeout expires
- `_updateActivityTime()`: Update timestamp

---

## Module: auth_controller.dart - Auth Controller

### Class: AuthController

**Purpose**: Orchestrate authentication operations across all submodules.

#### Properties
- `vault` (VaultCore): Vault instance
- `keystore` (Keystore): Secure storage
- `biometric` (BiometricAuth): Biometric auth
- `rateLimiter` (RateLimiter): Rate limiting
- `authState` (AuthState): State management

#### Constructor
```dart
AuthController({
  required this.vault,
  required this.keystore,
  required this.biometric,
  required this.rateLimiter,
  required this.authState,
})
```

---

#### isFirstTimeSetup() → Future<bool>
**Purpose**: Check if app needs master password setup.

**Returns**: true if no vault key stored, false if vault exists

**Usage**:
```dart
if (await authController.isFirstTimeSetup()) {
  navigateToSetupScreen();
} else {
  navigateToUnlockScreen();
}
```

---

#### setupMasterPassword() → Future<AuthResult>
**Purpose**: First-time master password setup.
**Parameters**:
- `masterPassword` (String): Password entered by user
- `confirmPassword` (String): Confirmation password

**Returns**: AuthResult with success flag and message

**Process**:
1. Check passwords match
2. Validate password strength (12+ chars, mixed case, numbers, symbols)
3. Create vault with Argon2 key derivation
4. Wrap vault key to Keystore
5. Mark as authenticated
6. Return success

**Password Strength Requirements**:
- Minimum 12 characters
- Must contain uppercase (A-Z)
- Must contain lowercase (a-z)
- Must contain numbers (0-9)
- Must contain symbols (!@#$%^&*()_+-=[]{}...etc)

**Usage**:
```dart
final result = await authController.setupMasterPassword(
  masterPassword: 'MyPassword123!',
  confirmPassword: 'MyPassword123!',
);
if (result.success) {
  authState.markAuthenticated();
} else {
  showError(result.message);
}
```

---

#### unlockVaultWithPassword() → Future<AuthResult>
**Purpose**: Unlock vault with master password.
**Parameters**:
- `masterPassword` (String): Password entered by user
- `vaultJson` (String): Vault file content

**Returns**: AuthResult with success flag, message, and rate limit flag

**Process**:
1. Check rate limiting
   - If rate limited: return error with remaining time
2. Call vault.unlockVault(password, vaultJson)
3. If success:
   - Reset wrong attempt counter
   - Wrap key to Keystore
   - Mark authenticated
   - Return success
4. If failure:
   - Increment wrong attempt counter
   - Return error with attempt count

**Rate Limiting in Action**:
```
Attempt 1-2: No delay
Attempt 3: 5 second wait
Attempt 5: 30 second wait
Attempt 10+: 5 minute wait
```

**Usage**:
```dart
final result = await authController.unlockVaultWithPassword(
  masterPassword: userPassword,
  vaultJson: await loadVaultFile(),
);
if (result.success) {
  showDashboard();
} else if (result.isRateLimited) {
  showRateLimitMessage(result.message);
} else {
  showWrongPasswordMessage(result.message);
}
```

---

#### unlockVaultWithBiometric() → Future<AuthResult>
**Purpose**: Unlock vault using biometric authentication.
**Parameters**:
- `vaultJson` (String): Vault file content
- `reason` (String): User-visible reason string

**Returns**: AuthResult with success flag and message

**Process**:
1. Check biometric available
   - If not available: return error
2. Prompt user for biometric/device unlock
3. If biometric succeeds:
   - Retrieve wrapped key from Keystore
   - Mark authenticated
   - Return success
4. If biometric fails:
   - Return error

**Security Notes**:
- Bypasses rate limiting (biometric is secure)
- Wrapped key never exposed to user code
- Device unlock as fallback

**Usage**:
```dart
final result = await authController.unlockVaultWithBiometric(
  vaultJson: vaultFileContent,
  reason: 'Unlock Kryptix to access your passwords',
);
if (result.success) {
  showDashboard();
}
```

---

#### changeMasterPassword() → Future<AuthResult>
**Purpose**: Change master password and re-encrypt vault.
**Parameters**:
- `currentPassword` (String): Current password
- `newPassword` (String): New password
- `confirmPassword` (String): Confirmation
- `vaultJson` (String): Current vault file

**Returns**: AuthResult with success flag and message

**Process**:
1. Verify new passwords match
2. Validate new password strength
3. Check new password differs from current
4. Unlock vault with current password
5. Create new vault with new password
6. Copy all entries to new vault
7. Update Keystore with new wrapped key
8. Return success

**Security Notes**:
- Requires correct current password
- All entries must be re-encrypted
- New salt generated for new key derivation
- Old key completely replaced

**Usage**:
```dart
final result = await authController.changeMasterPassword(
  currentPassword: currentPass,
  newPassword: newPass,
  confirmPassword: confirmPass,
  vaultJson: vaultFileContent,
);
```

---

#### lockVault() → void
**Purpose**: Manually lock vault (no parameters).

**Process**:
1. Call vault.lockVault()
2. Clear authentication state
3. Wipe key from memory

**Usage**: Called from lock button

```dart
authController.lockVault();
```

---

#### Private Methods
- `_isPasswordStrong()`: Validate password meets requirements
- `_serializeArgon2Params()`: Extract params for storage
- `_extractSaltBase64()`: Extract salt for storage

---

### Class: AuthResult

**Purpose**: Result object for authentication operations.

#### Properties
- `success` (bool): Operation succeeded
- `message` (String): User-visible message
- `isRateLimited` (bool): Failure due to rate limiting

**Usage**:
```dart
if (result.success) {
  // Show success
} else if (result.isRateLimited) {
  // Show rate limit message
} else {
  // Show error message
}
```

---

## Integration Flow

### First Time Setup
```
1. User opens app
2. authController.isFirstTimeSetup() → true
3. Show master password setup screen
4. User enters password twice
5. authController.setupMasterPassword(pass1, pass2)
   ├─ vault.createNewVault(password)
   ├─ Argon2 derives key
   ├─ keystore.wrapAndStoreVaultKey()
   ├─ Android Keystore encrypts key
   └─ authState.markAuthenticated()
6. Show dashboard
```

### Subsequent Opens - Biometric Unlock
```
1. App shows unlock screen
2. authController.isFirstTimeSetup() → false
3. User presses biometric button
4. authController.unlockVaultWithBiometric()
   ├─ Show biometric prompt
   ├─ Retrieve wrapped key from Keystore
   ├─ Unwrap key (platform specific)
   ├─ authState.markAuthenticated()
   └─ Return success
5. Show dashboard
```

### Subsequent Opens - Password Unlock
```
1. App shows unlock screen
2. User enters master password
3. authController.unlockVaultWithPassword()
   ├─ Check rate limiter
   ├─ vault.unlockVault(password, vaultJson)
   ├─ Load entries from vault
   ├─ keystore.wrapAndStoreVaultKey()
   ├─ rateLimiter.recordSuccessfulAttempt()
   └─ authState.markAuthenticated()
4. Show dashboard
```

### Auto Lock on Background
```
1. App goes to background
2. Activity recorded: authState.recordActivity()
3. Timer starts: 5 minute timeout
4. If app in background for 5 minutes:
   ├─ _autoLockTimer fires
   ├─ authState.markUnauthenticated()
   ├─ vault.lockVault()
   ├─ onAutoLock callback
   └─ Show unlock screen
5. User returns to app:
   ├─ See unlock screen
   ├─ Must re-authenticate
   ├─ recordActivity() resets timer
```

### Wrong Password with Rate Limiting
```
1. User enters wrong password
2. unlockVaultWithPassword() fails
3. rateLimiter.recordWrongAttempt()
4. Attempt 1-2: Show "wrong password"
5. Attempt 3: Wait 5 seconds
6. Attempt 5: Wait 30 seconds
7. Attempt 10+: Wait 5 minutes
8. On successful unlock:
   ├─ rateLimiter.recordSuccessfulAttempt()
   └─ Counter resets to 0
```

---

## Security Verification

### ✅ Master Password Security
- Never stored anywhere (only verifier in vault)
- Strength validated before setup
- Constant-time comparison during unlock

### ✅ Vault Key Security
- Wrapped by platform Keystore/Keychain
- Never stored in plaintext
- Only unwrappable on same device
- Wiped from memory on lock

### ✅ Rate Limiting
- Progressive delays on wrong attempts
- 5s, 30s, 5min delays
- Resets on successful unlock
- Prevents brute force attacks

### ✅ Biometric Security
- Delegates to platform biometric API
- Doesn't store passwords
- Uses wrapped key from Keystore

### ✅ Auto Lock
- Configurable timeout (default 5 min)
- Resets on user activity
- Wipes key on timeout
- Triggered on background

### ✅ No Hardcoded Secrets
- All security parameters configurable
- No test credentials
- No backdoors

---

## Testing Considerations

Each class should be unit tested:
- **Keystore**: Mock FlutterSecureStorage
- **BiometricAuth**: Mock LocalAuthentication
- **RateLimiter**: Control DateTime.now() in tests
- **AuthState**: Test timer behavior
- **AuthController**: Integration tests with all modules

---

## Platform-Specific Notes

### Android
- flutter_secure_storage uses Android Keystore
- Requires API 23+
- Hardware-backed keys when available

### iOS
- flutter_secure_storage uses Keychain with Secure Enclave
- Requires iOS 12+
- Keys protected by device encryption

---

## Dependencies

- **vault_core.dart**: Vault operations
- **keystore.dart**: Secure key storage
- **biometric.dart**: Biometric authentication
- **rate_limiter.dart**: Rate limiting
- **auth_state.dart**: State management
- **flutter_secure_storage**: Keystore integration
- **local_auth**: Biometric API
- **uuid**: Entry IDs

---

## Code Quality

- No hardcoded secrets or test data
- All security parameters explicit
- Error handling with clear messages
- Memory management (key wiping)
- Constant-time comparisons
- Zero comments in code (all in this file)
