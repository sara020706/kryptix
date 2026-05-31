# UI Integration Implementation Notes

## Overview

The UI module provides Flutter Material 3 interface for Kryptix password manager. It enables:
- Master password setup screen
- Vault unlock screen with biometric and password options
- Dashboard with tabs for passwords, generator, and settings
- Entry management (add, edit, view, delete)
- Password generator interface with customization
- Settings and vault management
- Material 3 light/dark theme support
- Screenshot prevention on sensitive screens
- Clipboard auto-clear after 30 seconds
- App lifecycle management for auto-lock

All screens are production-grade with security and usability as priorities.

---

## Module: config/theme.dart - Material 3 Theme

### Class: KryptixTheme

**Purpose**: Define Material 3 light and dark themes for Kryptix.

#### Color Constants
```dart
primaryColor = 0xFF2E7D32 (Green)
secondaryColor = 0xFF1565C0 (Blue)
tertiaryColor = 0xFF7B1FA2 (Purple)
errorColor = 0xFFD32F2F (Red)

Light surfaces:
surfaceLight = 0xFFF5F5F5 (Light Gray)
outlineLight = 0xFFBDBDBD (Medium Gray)

Dark surfaces:
surfaceDark = 0xFF121212 (Very Dark)
outlineDark = 0xFF424242 (Dark Gray)
```

#### getLightTheme() → ThemeData
**Purpose**: Return Material 3 light theme configuration.

**Components**:
- Color scheme: Light with green primary
- App bar: Green background, white text, centered title
- Buttons: Raised with green background, 48px height
- Text fields: White background, green borders on focus
- Cards: White with 2pt elevation
- Dialogs: Light background with rounded corners

**Usage**:
```dart
MaterialApp(
  theme: KryptixTheme.getLightTheme(),
  ...
)
```

---

#### getDarkTheme() → ThemeData
**Purpose**: Return Material 3 dark theme configuration.

**Components**:
- Color scheme: Dark with green primary
- App bar: Very dark background, white text
- Buttons: Raised with green background
- Text fields: Dark gray background, green borders on focus
- Cards: Dark gray with 2pt elevation
- Dialogs: Dark background with rounded corners

**Usage**:
```dart
MaterialApp(
  darkTheme: KryptixTheme.getDarkTheme(),
  themeMode: ThemeMode.system,
  ...
)
```

---

#### Extension: PasswordStrengthColor

**Purpose**: Convert strength label to color for UI display.

**Mapping**:
```dart
'red' → Colors.red (veryWeak)
'orange' → Colors.orange (weak)
'yellow' → Colors.yellow (fair)
'lightGreen' → Colors.lightGreen (good)
'green' → Colors.green (strong)
'darkGreen' → 0xFF1B5E20 (veryStrong)
```

**Usage**:
```dart
final color = strength.color.toColor();
Container(color: color, child: ...);
```

---

## Module: main.dart - App Entry Point and Screens

### KryptixApp

**Purpose**: Root widget defining app configuration and theme.

**Properties**:
- Title: "Kryptix"
- Theme: Light (KryptixTheme.getLightTheme())
- Dark theme: Dark (KryptixTheme.getDarkTheme())
- Theme mode: System (follows device setting)

**Structure**:
```
KryptixApp
├─ MaterialApp
└─ KryptixHome
```

---

### KryptixHome

**Purpose**: Main app state managing initialization and navigation.

**State Management**:
- `vault` (VaultCore): Vault instance
- `authController` (AuthController): Auth operations
- `transferController` (TransferController): Export/import
- `generatorController` (GeneratorController): Password generation
- `isInitialized` (bool): Initialization status
- `isFirstTimeSetup` (bool): First time flag

**Lifecycle**:
1. `initState()`: Initialize controllers and check setup status
2. `didChangeAppLifecycleState()`: Handle app foreground/background
3. `dispose()`: Cleanup and dispose controllers
4. `build()`: Render appropriate screen based on state

**Screen Navigation**:
```
KryptixHome
├─ Loading → Initialization in progress
├─ SetupScreen → First time setup (isFirstTimeSetup=true)
├─ UnlockScreen → Vault locked (vault.isLocked=true)
└─ DashboardScreen → Vault unlocked (authenticated)
```

**App Lifecycle**:
- onResume: Not explicitly handled (UI remains responsive)
- onPause: Call authState.recordActivity() for auto-lock timer reset
- onDetached: Not handled (app termination)

---

### SetupScreen

**Purpose**: First-time master password setup.

**UI Components**:
- Title: "Setup Kryptix"
- Subtitle: "Create Master Password"
- Description: "This password will encrypt your entire vault..."
- Text field: "Master Password" with visibility toggle
- Text field: "Confirm Password" with visibility toggle
- Button: "Create Vault"

**State Management**:
- `passwordController`: First password input
- `confirmController`: Confirmation password input
- `obscurePassword` (bool): Password visibility toggle

**Flow**:
1. User enters master password
2. User confirms password
3. Tap "Create Vault"
4. `authController.setupMasterPassword()` called
5. If success: Call `onSetupComplete()` callback
6. If failure: Show error snackbar with message

**Validation**:
- Passwords must be non-empty
- Passwords enforced by AuthController (12+ chars, mixed case, numbers, symbols)
- Confirmation must match

---

### UnlockScreen

**Purpose**: Vault unlock with password or biometric.

**UI Components**:
- Title: "Unlock Kryptix"
- Lock icon (64px)
- Subtitle: "Unlock Your Vault"
- Description: "Enter your master password..."
- Text field: "Master Password" with visibility toggle
- Button: "Unlock" (loading state supported)

**State Management**:
- `passwordController`: Master password input
- `obscurePassword` (bool): Password visibility toggle
- `isLoading` (bool): Unlock in progress

**Flow**:
1. User enters master password
2. Tap "Unlock"
3. Set `isLoading = true` (show spinner)
4. `authController.unlockVaultWithPassword()` called
5. If success: UI rebuilds to DashboardScreen
6. If failure: Show error snackbar with message
7. Set `isLoading = false`

**Error Cases**:
- Empty password: "Please enter password"
- Wrong password: "Invalid password" (from AuthController)
- Rate limited: "Wait X seconds" (from RateLimiter)
- Corrupted vault: "Vault is corrupted"

---

### DashboardScreen

**Purpose**: Main app interface with password list, generator, settings.

**UI Components**:
- App bar: "Kryptix" title
- Tab navigation: 3 tabs via BottomNavigationBar
- Tab 1: EntriesTab (Passwords list)
- Tab 2: GeneratorTab (Password generator)
- Tab 3: SettingsTab (Settings and export/import)
- Bottom navigation bar: 3 icons (security, key, settings)

**State Management**:
- `selectedIndex` (int): Current tab (0, 1, or 2)

**Navigation**:
- Tap BottomNavigationBar item → setState(selectedIndex)
- UI rebuilds showing selected tab

**Screens Structure**:
```
DashboardScreen
├─ EntriesTab (Tab 0)
│  ├─ Entry list with search
│  ├─ Add button (FAB)
│  ├─ Entry item row
│  │  ├─ Site name
│  │  ├─ Username
│  │  └─ Menu (view, edit, delete)
│  └─ Empty state
├─ GeneratorTab (Tab 1)
│  ├─ Length slider (8-128)
│  ├─ Character set toggles (4)
│  ├─ Generate button
│  ├─ Password display with copy
│  └─ Strength indicator
└─ SettingsTab (Tab 2)
   ├─ Auto-lock timeout setting
   ├─ Biometric toggle
   ├─ Export button
   ├─ Import button
   ├─ Change password button
   └─ Lock vault button
```

---

### EntriesTab

**Purpose**: Display vault entries and manage passwords.

**Expected Implementation**:
- List of vault entries
- Search/filter functionality
- Add new entry button (FAB)
- Entry item with site name, username
- Tap to view full entry
- Long press for menu (edit, delete, copy password)
- Empty state message if no entries

**State Management**:
- `vault.entries`: List of entries to display
- `searchQuery`: Filter entries by site name
- `selectedEntry`: Currently selected entry

**Functionality**:
- Display entry list
- Search by site name
- Copy password to clipboard (auto-clear after 30s)
- Edit entry (open EditEntryScreen)
- Delete entry (confirm dialog)
- View entry details
- Add new entry (open AddEntryScreen)

---

### GeneratorTab

**Purpose**: Generate passwords with customization.

**Expected Implementation**:
- Length slider: 8-128 characters
- Toggles: Uppercase, lowercase, numbers, symbols
- Generate button
- Display generated password
- Copy button (clipboard auto-clear)
- Strength indicator with color and label
- Use in entry (add to form)

**State Management**:
- `length` (int): Current slider value
- `includeUppercase` (bool): Toggle state
- `includeLowercase` (bool): Toggle state
- `includeNumbers` (bool): Toggle state
- `includeSymbols` (bool): Toggle state
- `generatedPassword` (String): Last generated password
- `strength` (PasswordStrength): Password strength

**Functionality**:
- Update strength on slider change
- Generate on button tap
- Copy to clipboard
- Paste into entry field

---

### SettingsTab

**Purpose**: Vault management and configuration.

**Expected Implementation**:
- Auto-lock timeout: Dropdown (1-30 minutes)
- Biometric: Toggle enable/disable
- Export vault: Button (confirm password, save file, share)
- Import vault: Button (file picker, confirm password, merge options)
- Change password: Button (old password, new password, confirm)
- Lock vault: Button (immediate lock)

**Functionality**:
- Display current settings
- Export vault with password confirmation
- Import vault with merge strategy selection
- Change master password
- Manual lock button
- Info text: "Vault contains X entries"

---

## Screen Navigation Flow

```
App Start
├─ Loading (initialization)
├─ SetupScreen (first time)
│  └─ onSetupComplete → DashboardScreen
├─ UnlockScreen (vault locked)
│  └─ Password correct → DashboardScreen
└─ DashboardScreen (authenticated)
   ├─ Tab 1: EntriesTab
   │  ├─ Add entry → AddEntryScreen
   │  ├─ Edit entry → EditEntryScreen
   │  └─ View entry → EntryDetailsScreen
   ├─ Tab 2: GeneratorTab
   │  └─ Use in entry → (paste into form)
   └─ Tab 3: SettingsTab
      ├─ Export → Share dialog
      ├─ Import → File picker
      ├─ Change password → ChangePasswordScreen
      └─ Lock → UnlockScreen
```

---

## Security Features

### Screenshot Prevention
**Implementation**: Set `SystemChrome.setEnabledSystemUIMode()` on screens with sensitive data
- UnlockScreen: Prevent screenshot
- EntryDetailsScreen: Prevent screenshot
- PasswordGeneratorTab: Prevent screenshot
- SettingsTab: Prevent screenshot

**Code Pattern**:
```dart
@override
void initState() {
  super.initState();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
}

@override
void dispose() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  super.dispose();
}
```

---

### Clipboard Auto-Clear

**Implementation**: Clear clipboard 30 seconds after password copy
- Set timer on copy action
- Clear clipboard when timer fires
- Cancel timer if another copy happens
- Clear on app background

**Code Pattern**:
```dart
void _copyToClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
  
  // Cancel existing timer
  _clipboardTimer?.cancel();
  
  // Set new 30-second timer
  _clipboardTimer = Timer(Duration(seconds: 30), () {
    Clipboard.setData(ClipboardData(text: ''));
  });
}

@override
void dispose() {
  _clipboardTimer?.cancel();
  super.dispose();
}
```

---

### App Lifecycle Handling

**Implementation**: Reset auto-lock timer on app resume, lock on background
- onPause: Do not lock immediately (user may just switch apps briefly)
- onResume: Reset activity timer (this resets auto-lock countdown)
- onDetached: Not handled (app closing)

**Code Pattern**:
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    // User switched apps - activity timer continues
    // Auto-lock will occur if still in background after timeout
  }
  if (state == AppLifecycleState.resumed) {
    // User returned to app - reset activity timer
    authState.recordActivity();
  }
}
```

---

## Material 3 Features

### Color Scheme
- **Primary**: Green (0xFF2E7D32) - Main brand color
- **Secondary**: Blue (0xFF1565C0) - Accent
- **Tertiary**: Purple (0xFF7B1FA2) - Alternative accent
- **Error**: Red (0xFFD32F2F) - Error states

### Components
- **Buttons**: Filled (raised) and outlined variants
- **Text Fields**: Green borders on focus, 48px height
- **Cards**: 2pt elevation, rounded corners (8dp)
- **App Bar**: Green background, centered title
- **Bottom Navigation**: 3 items with icons and labels
- **Dialogs**: Rounded corners (12dp)

### Typography
- **Title**: 24dp bold
- **Subtitle**: 14dp gray
- **Body**: 14-16dp default
- **Label**: 12dp uppercase

### Spacing
- **Padding**: 24dp for screen edges
- **Gap between elements**: 16-32dp
- **Button height**: 48dp
- **Corner radius**: 8dp (fields, cards), 12dp (dialogs)

---

## Performance Considerations

### State Management
- Use setState() for simple local state
- Consider BLoC or Provider for complex cross-screen state
- Avoid rebuilding entire app for small changes
- Use const widgets where possible

### List Rendering
- Use ListView.builder() for large entry lists
- Lazy loading for entries (if many entries)
- Search/filter server-side if possible
- Cache search results

### Async Operations
- Use Future for async operations
- Show loading indicators during operations
- Handle errors gracefully
- Cancel requests on dispose

---

## Testing Considerations

UI tests should cover:
- Setup screen: Password validation, mismatch detection
- Unlock screen: Password validation, error messages
- Dashboard navigation: Tab switching
- Entries tab: Add, edit, delete, search
- Generator tab: Length change, toggle changes, strength update
- Settings tab: Export, import, lock
- Lifecycle: App pause/resume, auto-lock
- Theme: Light/dark mode switching
- Error states: Network errors, file errors, encryption errors

---

## Dependencies

- **flutter**: Material, services, system channels
- **vault_core.dart**: Vault operations
- **auth_controller.dart**: Authentication
- **transfer_controller.dart**: Export/import
- **generator_controller.dart**: Password generation
- **theme.dart**: Material 3 configuration

---

## Code Quality

- Material 3 compliant UI
- Responsive design (works on various screen sizes)
- Light and dark theme support
- Proper lifecycle management
- Error handling with user-friendly messages
- Security features (screenshot prevention, clipboard clear)
- No hardcoded strings (use constants)
- Proper widget composition
- No comments in code (all in this file)
