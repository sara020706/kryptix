import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'config/theme.dart';
import 'core/vault/vault_core.dart';
import 'core/vault/transfer.dart';
import 'core/models/entry_model.dart';
import 'core/generator/password_generator.dart';
import 'features/auth/auth_controller.dart';
import 'features/settings/transfer_controller.dart';
import 'features/generator/generator_controller.dart';
import 'package:vaultx/core/auth/keystore.dart';
import 'package:vaultx/core/auth/biometric.dart';
import 'package:vaultx/core/auth/rate_limiter.dart';
import 'package:vaultx/core/auth/auth_state.dart';
import 'package:vaultx/core/storage/file_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'core/ui/glass_card.dart';
import 'core/ui/toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(const VaultXApp());
  });
}

class VaultXApp extends StatelessWidget {
  const VaultXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kryptix',
      theme: VaultXTheme.getTheme(),
      themeMode: ThemeMode.dark,
      home: const VaultXHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VaultXHome extends StatefulWidget {
  const VaultXHome({super.key});

  @override
  State<VaultXHome> createState() => _VaultXHomeState();
}

class _VaultXHomeState extends State<VaultXHome>
    with WidgetsBindingObserver {
  late VaultCore vault;
  late AuthController authController;
  late TransferController transferController;
  late GeneratorController generatorController;

  bool isInitialized = false;
  bool isFirstTimeSetup = false;
  String loadedVaultJson = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  void _initializeApp() async {
    setState(() {
      isInitialized = false;
    });

    vault = VaultCore();
    final keystore = Keystore();
    final rateLimiter = RateLimiter();
    await rateLimiter.initialize();
    authController = AuthController(
      vault: vault,
      keystore: keystore,
      biometric: BiometricAuth(),
      rateLimiter: rateLimiter,
      authState: AuthState(vault: vault, keystore: keystore),
    );

    final autoLockMins = await keystore.retrieveAutoLockMinutes();
    authController.authState.setAutoLockMinutes(autoLockMins);
    transferController = TransferController(vault: vault);
    generatorController = GeneratorController();

    authController.authState.startAutoLockTimer(() {
      setState(() {});
    });

    final vaultExists = await FileManager.vaultFileExists();
    if (vaultExists) {
      try {
        loadedVaultJson = await FileManager.loadVaultFromFile();
      } catch (e) {
        loadedVaultJson = '';
      }
    } else {
      loadedVaultJson = '';
    }

    final firstTime = await authController.isFirstTimeSetup();

    setState(() {
      isFirstTimeSetup = firstTime;
      isInitialized = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      authController.authState.recordActivity();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive) {
      authController.lockVault();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isInitialized) {
      authController.authState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Scaffold(
        backgroundColor: VaultXColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: VaultXColors.primary,
          ),
        ),
      );
    }

    if (isFirstTimeSetup) {
      return SetupScreen(
        authController: authController,
        onSetupComplete: () {
          setState(() {
            isFirstTimeSetup = false;
          });
        },
      );
    }

    if (authController.authState.isVaultLocked) {
      return UnlockScreen(
        authController: authController,
        transferController: transferController,
        vaultJson: loadedVaultJson,
        onUnlockSuccess: () {
          setState(() {});
        },
        onVaultReset: () {
          _initializeApp();
        },
      );
    }

    return DashboardScreen(
      authController: authController,
      transferController: transferController,
      generatorController: generatorController,
      vault: vault,
      onLockVault: () {
        setState(() {});
      },
      onVaultReset: () {
        _initializeApp();
      },
    );
  }
}

class VaultXBackground extends StatelessWidget {
  final Widget child;

  const VaultXBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaultXColors.background,
      body: child,
    );
  }
}

class SetupScreen extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onSetupComplete;

  const SetupScreen({
    required this.authController,
    required this.onSetupComplete,
    super.key,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late TextEditingController passwordController;
  late TextEditingController confirmController;
  bool obscurePassword = true;
  bool isLoading = false;
  bool acceptSeriousness = false;
  PasswordStrength currentStrength = PasswordStrength.veryWeak;

  @override
  void initState() {
    super.initState();
    passwordController = TextEditingController();
    confirmController = TextEditingController();
    passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      currentStrength = _checkStrength(passwordController.text);
    });
  }

  PasswordStrength _checkStrength(String pass) {
    if (pass.isEmpty) return PasswordStrength.veryWeak;
    if (pass.length < 8) return PasswordStrength.veryWeak;
    int score = 0;
    if (pass.length >= 12) score++;
    if (pass.contains(RegExp(r'[A-Z]'))) score++;
    if (pass.contains(RegExp(r'[a-z]'))) score++;
    if (pass.contains(RegExp(r'[0-9]'))) score++;
    if (pass.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'))) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.fair;
    if (score == 3) return PasswordStrength.good;
    if (score == 4) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  Future<void> _setupMasterPassword() async {
    if (passwordController.text.isEmpty || confirmController.text.isEmpty) {
      VaultXToast.show(
        context,
        message: 'Please enter and confirm your password',
        type: VaultXToastType.warning,
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await widget.authController.setupMasterPassword(
      masterPassword: passwordController.text,
      confirmPassword: confirmController.text,
    );

    if (mounted) {
      setState(() => isLoading = false);
      if (result.success) {
        VaultXToast.show(
          context,
          message: 'Vault setup complete!',
          type: VaultXToastType.success,
        );
        widget.onSetupComplete();
      } else {
        VaultXToast.show(
          context,
          message: result.message,
          type: VaultXToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VaultXBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/logo.jpg', width: 44, height: 44, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Text('Kryptix', style: Theme.of(context).textTheme.displayLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'High-level encryption active',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VaultXColors.onSurfaceVariant.withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Master Password',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This password will encrypt your entire vault. Choose a strong password.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VaultXColors.onSurfaceVariant.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'MASTER PASSWORD',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VaultXColors.primary,
                            letterSpacing: 1.2,
                          ),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isLoading,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CONFIRM PASSWORD',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VaultXColors.primary,
                            letterSpacing: 1.2,
                          ),
                    ),
                    TextField(
                      controller: confirmController,
                      obscureText: obscurePassword,
                      enabled: !isLoading,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(
                        hintText: '••••••••••••',
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStrengthSegments(currentStrength),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VaultXColors.errorContainer.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: VaultXColors.error.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: VaultXColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ZERO-KNOWLEDGE DISCLOSURE',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: VaultXColors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 1.0,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kryptix encrypts your entire database locally. We do not store or transmit your master password. If lost, your credentials can NEVER be recovered by anyone.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 11,
                                        color: VaultXColors.onSurfaceVariant.withOpacity(0.8),
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: acceptSeriousness,
                            activeColor: VaultXColors.primary,
                            checkColor: VaultXColors.onPrimary,
                            onChanged: (val) {
                              setState(() {
                                acceptSeriousness = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                acceptSeriousness = !acceptSeriousness;
                              });
                            },
                            child: Text(
                              'I accept that my master password is my sole responsibility, and losing it will result in permanent data loss.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: acceptSeriousness
                                        ? VaultXColors.onSurface
                                        : VaultXColors.onSurfaceVariant.withOpacity(0.6),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: (isLoading || !acceptSeriousness) ? null : _setupMasterPassword,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Create Vault', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: VaultXColors.onPrimary)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20, color: VaultXColors.onPrimary),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthSegments(PasswordStrength strength) {
    int activeSegments = 0;
    Color segmentColor = Colors.red;
    String label = 'Weak';

    switch (strength) {
      case PasswordStrength.veryWeak:
        activeSegments = 1;
        segmentColor = const Color(0xFFffb4ab);
        label = 'Very Weak';
        break;
      case PasswordStrength.weak:
        activeSegments = 1;
        segmentColor = const Color(0xFFffb4ab);
        label = 'Weak';
        break;
      case PasswordStrength.fair:
        activeSegments = 2;
        segmentColor = const Color(0xFFFFB74D);
        label = 'Fair';
        break;
      case PasswordStrength.good:
        activeSegments = 3;
        segmentColor = const Color(0xFFFFEE58);
        label = 'Good';
        break;
      case PasswordStrength.strong:
        activeSegments = 4;
        segmentColor = const Color(0xFFadc7ff);
        label = 'Strong';
        break;
      case PasswordStrength.veryStrong:
        activeSegments = 4;
        segmentColor = const Color(0xFFadc7ff);
        label = 'Very Strong';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Strength', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant)),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: segmentColor)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final isActive = index < activeSegments;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? segmentColor : const Color(0xFF1c1b1b),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: segmentColor.withOpacity(0.6),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class UnlockScreen extends StatefulWidget {
  final AuthController authController;
  final TransferController transferController;
  final String vaultJson;
  final VoidCallback? onUnlockSuccess;
  final VoidCallback? onVaultReset;

  const UnlockScreen({
    required this.authController,
    required this.transferController,
    required this.vaultJson,
    this.onUnlockSuccess,
    this.onVaultReset,
    super.key,
  });

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  late TextEditingController passwordController;
  bool obscurePassword = true;
  bool isLoading = false;
  bool _biometricAvailable = false;
  late BiometricAuth _biometricAuth;

  @override
  void initState() {
    super.initState();
    passwordController = TextEditingController();
    _biometricAuth = BiometricAuth();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canUse = await _biometricAuth.canUseBiometrics();
      final isSupported = await _biometricAuth.isDeviceSupported();
      setState(() {
        _biometricAvailable = canUse && isSupported;
      });
    } catch (e) {
      setState(() {
        _biometricAvailable = false;
      });
    }
  }

  Future<void> _handleResetVaultRequest() async {
    final canUse = await _biometricAuth.canUseBiometrics();
    final isSupported = await _biometricAuth.isDeviceSupported();
    final hasKey = await widget.authController.keystore.retrieveWrappedVaultKey() != null;
    
    if (canUse && isSupported && hasKey) {
      final success = await _biometricAuth.authenticate(
        reason: 'Verify identity to recover or delete your vault',
      );
      
      if (success) {
        if (mounted) {
          _showRecoverySelectionDialog();
        }
      } else {
        if (mounted) {
          VaultXToast.show(
            context,
            message: 'Biometric authentication failed or cancelled',
            type: VaultXToastType.error,
          );
        }
      }
    } else {
      if (mounted) {
        _showDestructiveResetDialog(
          reason: 'Biometric recovery is not configured. To regain access, the vault must be completely reset, deleting all stored credentials.',
        );
      }
    }
  }

  void _showRecoverySelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: VaultXColors.primary),
            SizedBox(width: 8),
            Text('Identity Verified'),
          ],
        ),
        content: const Text(
          'Biometric verification successful!\n\nWould you like to unlock and reuse your existing vault, or permanently wipe and delete it to start fresh?',
          style: TextStyle(fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDestructiveResetDialog(
                      reason: 'You chose to delete and reset the vault. This cannot be undone.',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VaultXColors.error,
                    side: const BorderSide(color: VaultXColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('DELETE FRESH'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reuseVaultWithBiometrics();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VaultXColors.primary,
                    foregroundColor: VaultXColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('REUSE VAULT'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _reuseVaultWithBiometrics() async {
    setState(() => isLoading = true);
    try {
      final freshVaultJson = await FileManager.loadVaultFromFile();
      final result = await widget.authController.unlockVaultWithBiometric(
        vaultJson: freshVaultJson,
        reason: 'Verify identity to reuse vault',
      );
      if (mounted) {
        setState(() => isLoading = false);
        if (result.success) {
          final existingEntries = List<VaultEntry>.from(widget.authController.vault.entries);
          widget.authController.lockVault(); // lock immediate state until password is set
          _showNewPasswordPromptForReusedVault(existingEntries);
        } else {
          VaultXToast.show(
            context,
            message: 'Failed to authenticate: ${result.message}',
            type: VaultXToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        VaultXToast.show(
          context,
          message: 'Error unlocking: $e',
          type: VaultXToastType.error,
        );
      }
    }
  }

  void _showNewPasswordPromptForReusedVault(List<VaultEntry> existingEntries) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool isSaving = false;
    bool acceptSeriousness = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: VaultXColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text('Set New Master Password'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biometric authentication verified! To complete recovery and reuse your existing credentials, please establish a new Master Password.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Text(
                  'NEW MASTER PASSWORD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VaultXColors.primary,
                        letterSpacing: 1.2,
                      ),
                ),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscurePassword,
                  enabled: !isSaving,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'CONFIRM MASTER PASSWORD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VaultXColors.primary,
                        letterSpacing: 1.2,
                      ),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscurePassword,
                  enabled: !isSaving,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: const InputDecoration(
                    hintText: '••••••••••••',
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VaultXColors.errorContainer.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VaultXColors.error.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: VaultXColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZERO-KNOWLEDGE DISCLOSURE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: VaultXColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kryptix encrypts your entire database locally. We do not store or transmit your master password. If lost, your credentials can NEVER be recovered by anyone.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 11,
                                    color: VaultXColors.onSurfaceVariant.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: acceptSeriousness,
                        activeColor: VaultXColors.primary,
                        checkColor: VaultXColors.onPrimary,
                        onChanged: (val) {
                          setDialogState(() {
                            acceptSeriousness = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            acceptSeriousness = !acceptSeriousness;
                          });
                        },
                        child: Text(
                          'I accept that my master password is my sole responsibility, and losing it will result in permanent data loss.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: acceptSeriousness
                                    ? VaultXColors.onSurface
                                    : VaultXColors.onSurfaceVariant.withOpacity(0.6),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () {
                      widget.authController.lockVault();
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaultXColors.primary,
                      side: const BorderSide(color: VaultXColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (isSaving || !acceptSeriousness) ? null : () async {
                      if (newPasswordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
                        VaultXToast.show(
                          context,
                          message: 'Please complete both fields',
                          type: VaultXToastType.warning,
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      final result = await widget.authController.rekeyVaultWithNewPassword(
                        existingEntries: existingEntries,
                        newPassword: newPasswordController.text,
                        confirmPassword: confirmPasswordController.text,
                      );

                      if (mounted) {
                        setDialogState(() => isSaving = false);
                        if (result.success) {
                          Navigator.pop(ctx);
                          VaultXToast.show(
                            context,
                            message: 'Vault recovered and password updated!',
                            type: VaultXToastType.success,
                          );
                          widget.onUnlockSuccess?.call();
                        } else {
                          VaultXToast.show(
                            context,
                            message: result.message,
                            type: VaultXToastType.error,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VaultXColors.primary,
                      foregroundColor: VaultXColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SAVE & UNLOCK'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDestructiveResetDialog({required String reason}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: VaultXColors.error),
            SizedBox(width: 8),
            Text('Reset Entire Vault?'),
          ],
        ),
        content: Text(
          '$reason\n\nAll saved passwords will be permanently deleted and cannot be recovered.\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              try {
                await FileManager.deleteVaultFile();
                await widget.authController.keystore.clearVaultKey();
                widget.authController.lockVault();
                
                if (mounted) {
                  VaultXToast.show(
                    context,
                    message: 'Vault successfully reset.',
                    type: VaultXToastType.success,
                  );
                  widget.onVaultReset?.call();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => isLoading = false);
                  VaultXToast.show(
                    context,
                    message: 'Failed to reset vault: $e',
                    type: VaultXToastType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VaultXColors.error,
              foregroundColor: VaultXColors.onError,
            ),
            child: const Text('RESET EVERYTHING'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockVault() async {
    if (passwordController.text.isEmpty) {
      VaultXToast.show(
        context,
        message: 'Please enter your master password',
        type: VaultXToastType.warning,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final freshVaultJson = await FileManager.loadVaultFromFile();
      final result = await widget.authController.unlockVaultWithPassword(
        masterPassword: passwordController.text,
        vaultJson: freshVaultJson,
      );

      if (mounted) {
        setState(() => isLoading = false);

        if (result.success) {
          VaultXToast.show(
            context,
            message: 'Vault unlocked!',
            type: VaultXToastType.success,
          );
          widget.onUnlockSuccess?.call();
        } else {
          VaultXToast.show(
            context,
            message: result.message,
            type: VaultXToastType.error,
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        VaultXToast.show(
          context,
          message: 'Error during unlock: $e',
          type: VaultXToastType.error,
        );
      }
    }
  }

  Future<void> _unlockVaultWithBiometric() async {
    setState(() => isLoading = true);

    try {
      final freshVaultJson = await FileManager.loadVaultFromFile();
      final biometricResult = await widget.authController.unlockVaultWithBiometric(
        vaultJson: freshVaultJson,
        reason: 'Unlock your Kryptix',
      );

      if (mounted) {
        setState(() => isLoading = false);

        if (biometricResult.success) {
          VaultXToast.show(
            context,
            message: 'Vault unlocked with biometric!',
            type: VaultXToastType.success,
          );
          widget.onUnlockSuccess?.call();
        } else {
          VaultXToast.show(
            context,
            message: biometricResult.message,
            type: VaultXToastType.error,
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        VaultXToast.show(
          context,
          message: 'Biometric auth error: $e',
          type: VaultXToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VaultXBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/logo.jpg', width: 44, height: 44, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Text('Kryptix', style: Theme.of(context).textTheme.displayLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'High-level encryption active',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VaultXColors.onSurfaceVariant.withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VaultXColors.primary.withOpacity(0.1),
                            border: Border.all(color: VaultXColors.primary.withOpacity(0.2)),
                          ),
                        ),
                        const Icon(Icons.lock_outline, size: 36, color: VaultXColors.primary),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Unlock Vault', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your master password to continue',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VaultXColors.onSurfaceVariant.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MASTER PASSWORD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VaultXColors.primary,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isLoading,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isLoading ? null : _unlockVault,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Unlock Vault', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: VaultXColors.onPrimary)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20, color: VaultXColors.onPrimary),
                              ],
                            ),
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: isLoading ? null : _unlockVaultWithBiometric,
                        icon: const Icon(Icons.fingerprint_outlined, size: 20),
                        label: const Text('UNLOCK WITH BIOMETRICS'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: isLoading ? null : _handleResetVaultRequest,
                      icon: const Icon(Icons.delete_forever_outlined, color: VaultXColors.error, size: 16),
                      label: const Text(
                        'RESET VAULT',
                        style: TextStyle(color: VaultXColors.error, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('AES-256', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.onSurfaceVariant.withOpacity(0.5))),
                  const SizedBox(width: 20),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Zero-Knowledge', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.onSurfaceVariant.withOpacity(0.5))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final AuthController authController;
  final TransferController transferController;
  final GeneratorController generatorController;
  final VaultCore vault;
  final VoidCallback? onLockVault;
  final VoidCallback? onVaultReset;

  const DashboardScreen({
    required this.authController,
    required this.transferController,
    required this.generatorController,
    required this.vault,
    this.onLockVault,
    this.onVaultReset,
    Key? key,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      EntriesTab(
        vault: widget.vault,
        onStateChange: () => setState(() {}),
      ),
      GeneratorTab(generatorController: widget.generatorController),
      SettingsTab(
        authController: widget.authController,
        transferController: widget.transferController,
        vault: widget.vault,
        onStateChange: () => setState(() {}),
        onVaultReset: widget.onVaultReset,
      ),
    ];
    return Scaffold(
      backgroundColor: VaultXColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: screens[selectedIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
      floatingActionButton: selectedIndex == 0
          ? Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: FloatingActionButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131313), // Premium solid dark background
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: _AddEntryDialog(
                        onSave: (siteName, url, username, password, notes) async {
                          widget.vault.addEntry(
                            siteName: siteName,
                            username: username,
                            password: password,
                            notes: notes,
                          );
                          try {
                            final vaultJson = widget.vault.serializeVault();
                            await FileManager.saveVaultToFile(vaultJson);
                            setState(() {});
                            if (context.mounted) {
                              Navigator.pop(context);
                              VaultXToast.show(context, message: 'Password saved successfully', type: VaultXToastType.success);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              VaultXToast.show(context, message: 'Failed to save vault: $e', type: VaultXToastType.error);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
                backgroundColor: VaultXColors.primary,
                foregroundColor: VaultXColors.onPrimary,
                shape: const CircleBorder(),
                elevation: 0,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: VaultXColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 28),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Kryptix',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: VaultXColors.surfaceContainerLowest, // Premium solid lowest dark background
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.lock_outline, Icons.lock, 'Passwords'),
          _buildNavItem(1, Icons.password_outlined, Icons.password, 'Generator'),
          _buildNavItem(2, Icons.settings_outlined, Icons.settings, 'Settings'),
          _buildNavItem(3, Icons.logout_outlined, Icons.logout, 'Lock'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isActive = selectedIndex == index;
    final color = isActive ? VaultXColors.primary : VaultXColors.onSurfaceVariant;
    
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          widget.authController.lockVault();
          widget.onLockVault?.call();
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? VaultXColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? filledIcon : outlineIcon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecurityGaugePainter extends CustomPainter {
  final double score;

  SecurityGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    final basePaint = Paint()
      ..color = const Color(0xFF1c1b1b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final activePaint = Paint()
      ..color = VaultXColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);

    final sweepAngle = (score / 100) * 360 * (3.141592653589793 / 180);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.141592653589793 / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SecurityGaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}

class EntriesTab extends StatefulWidget {
  final VaultCore vault;
  final VoidCallback onStateChange;

  const EntriesTab({required this.vault, required this.onStateChange, Key? key}) : super(key: key);

  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<EntriesTab> {
  late TextEditingController searchController;
  List<VaultEntry> filteredEntries = [];
  Timer? clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredEntries = widget.vault.entries;
    searchController.addListener(_filterEntries);
  }

  @override
  void dispose() {
    searchController.dispose();
    clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _filterEntries() {
    setState(() {
      final query = searchController.text.toLowerCase();
      filteredEntries = widget.vault.entries
          .where((entry) =>
              entry.siteName.toLowerCase().contains(query) ||
              entry.username.toLowerCase().contains(query))
          .toList();
    });
  }

  bool _isPasswordWeak(String password) {
    if (password.length < 10) return true;
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'));
    int score = 0;
    if (hasUpper) score++;
    if (hasLower) score++;
    if (hasDigit) score++;
    if (hasSpecial) score++;
    return score < 3;
  }

  int get totalEntries => widget.vault.entries.length;

  int get weakPasswordsCount {
    int count = 0;
    for (final entry in widget.vault.entries) {
      if (_isPasswordWeak(entry.password)) {
        count++;
      }
    }
    return count;
  }

  int get securityHealthScore {
    if (totalEntries == 0) return 100;
    final weakCount = weakPasswordsCount;
    final score = 100 - ((weakCount / totalEntries) * 50).round();
    return score.clamp(0, 100);
  }

  void _copyToClipboard(String password) {
    Clipboard.setData(ClipboardData(text: password));
    clipboardClearTimer?.cancel();
    clipboardClearTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
    
    VaultXToast.show(
      context,
      message: 'Password copied to clipboard. Auto-clears in 30 seconds.',
      type: VaultXToastType.success,
    );
  }

  void _showAddEntryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131313), // Premium solid dark background
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: _AddEntryDialog(
          onSave: (siteName, url, username, password, notes) async {
            widget.vault.addEntry(
              siteName: siteName,
              username: username,
              password: password,
              notes: notes,
            );
            try {
              final vaultJson = widget.vault.serializeVault();
              await FileManager.saveVaultToFile(vaultJson);
              _filterEntries();
              widget.onStateChange();
              if (context.mounted) {
                Navigator.pop(context);
                VaultXToast.show(context, message: 'Password saved successfully', type: VaultXToastType.success);
              }
            } catch (e) {
              if (context.mounted) {
                VaultXToast.show(context, message: 'Failed to save vault: $e', type: VaultXToastType.error);
              }
            }
          },
        ),
      ),
    );
  }

  void _showEditEntryDialog(VaultEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131313), // Premium solid dark background
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: _EditEntryDialog(
          entry: entry,
          onSave: (siteName, url, username, password, notes) async {
            widget.vault.editEntry(
              entryId: entry.id,
              siteName: siteName,
              username: username,
              password: password,
              notes: notes,
            );
            try {
              final vaultJson = widget.vault.serializeVault();
              await FileManager.saveVaultToFile(vaultJson);
              _filterEntries();
              widget.onStateChange();
              if (context.mounted) {
                Navigator.pop(context);
                VaultXToast.show(context, message: 'Password updated successfully', type: VaultXToastType.success);
              }
            } catch (e) {
              if (context.mounted) {
                VaultXToast.show(context, message: 'Failed to save vault: $e', type: VaultXToastType.error);
              }
            }
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(VaultEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: VaultXColors.error),
            SizedBox(width: 8),
            Text('Delete Entry'),
          ],
        ),
        content: Text('Are you sure you want to delete "${entry.siteName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              widget.vault.deleteEntry(entry.id);
              try {
                final vaultJson = widget.vault.serializeVault();
                await FileManager.saveVaultToFile(vaultJson);
                _filterEntries();
                widget.onStateChange();
                if (context.mounted) {
                  Navigator.pop(context);
                  VaultXToast.show(context, message: 'Entry deleted', type: VaultXToastType.info);
                }
              } catch (e) {
                if (context.mounted) {
                  VaultXToast.show(context, message: 'Failed to delete entry: $e', type: VaultXToastType.error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VaultXColors.error,
              foregroundColor: VaultXColors.onError,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _saveVault() async {
    try {
      final vaultJson = widget.vault.serializeVault();
      await FileManager.saveVaultToFile(vaultJson);
    } catch (e) {
      VaultXToast.show(context, message: 'Failed to save vault: $e', type: VaultXToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = securityHealthScore;
    final weakCount = weakPasswordsCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: BorderRadius.circular(12),
            borderColor: Colors.white.withOpacity(0.08),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search secure vault...',
                prefixIcon: const Icon(Icons.search, color: VaultXColors.outline, size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SECURITY HEALTH',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.5,
                                  color: VaultXColors.outline,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$health',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: VaultXColors.primary,
                                      height: 1,
                                    ),
                              ),
                              Text(
                                '/100',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: VaultXColors.onSurfaceVariant.withOpacity(0.5),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            health >= 80 ? 'Strong protection active' : 'Action recommended',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: VaultXColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: SecurityGaugePainter(score: health.toDouble()),
                        child: Center(
                          child: Icon(
                            health >= 80 ? Icons.verified_user : Icons.warning_amber_rounded,
                            color: VaultXColors.primary,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.storage_outlined, color: VaultXColors.primary, size: 24),
                          const SizedBox(height: 16),
                          Text(
                            '$totalEntries',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stored Entries',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      borderColor: weakCount > 0 ? VaultXColors.error.withOpacity(0.2) : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: weakCount > 0 ? VaultXColors.error : VaultXColors.outline,
                            size: 24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$weakCount',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: weakCount > 0 ? VaultXColors.error : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Weak Warnings',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT PASSWORDS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          color: VaultXColors.outline,
                        ),
                  ),
                  if (filteredEntries.isNotEmpty)
                    Text(
                      '${filteredEntries.length} Items',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.outline),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              filteredEntries.isEmpty
                  ? Column(
                      children: [
                        const SizedBox(height: 48),
                        Icon(Icons.lock_open_outlined, size: 48, color: VaultXColors.outline.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No credentials found',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaultXColors.outline),
                        ),
                        const SizedBox(height: 16),
                        if (widget.vault.entries.isEmpty)
                          OutlinedButton.icon(
                            onPressed: _showAddEntryDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ADD PASSWORD'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VaultXColors.primary,
                              side: const BorderSide(color: VaultXColors.primary),
                            ),
                          ),
                      ],
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final isWeak = _isPasswordWeak(entry.password);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: BorderRadius.circular(12),
                            borderColor: isWeak ? VaultXColors.error.withOpacity(0.15) : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: VaultXColors.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      entry.siteName.isNotEmpty ? entry.siteName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: VaultXColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.siteName,
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isWeak)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: VaultXColors.error.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: VaultXColors.error.withOpacity(0.25), width: 0.5),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, color: VaultXColors.error, size: 10),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'WEAK',
                                                    style: TextStyle(
                                                      color: VaultXColors.error,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        entry.username,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: VaultXColors.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '••••••••',
                                      style: TextStyle(
                                        color: isWeak ? VaultXColors.error.withOpacity(0.5) : VaultXColors.primary.withOpacity(0.5),
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 14,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.content_copy_outlined, size: 18),
                                          onPressed: () => _copyToClipboard(entry.password),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => _showEditEntryDialog(entry),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: VaultXColors.error),
                                          onPressed: () => _showDeleteConfirmation(entry),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class GeneratorTab extends StatefulWidget {
  final GeneratorController generatorController;

  const GeneratorTab({required this.generatorController, Key? key}) : super(key: key);

  @override
  State<GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<GeneratorTab> {
  int passwordLength = 16;
  bool includeUppercase = true;
  bool includeLowercase = true;
  bool includeNumbers = true;
  bool includeSymbols = true;
  String generatedPassword = '';
  Timer? clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() async {
    try {
      final password = await widget.generatorController.generatePassword(
        length: passwordLength,
        includeUppercase: includeUppercase,
        includeLowercase: includeLowercase,
        includeNumbers: includeNumbers,
        includeSymbols: includeSymbols,
      );
      setState(() {
        generatedPassword = password;
      });
    } catch (e) {
      VaultXToast.show(context, message: 'Error generating password: $e', type: VaultXToastType.error);
    }
  }

  void _copyToClipboard() {
    if (generatedPassword.isEmpty) {
      VaultXToast.show(context, message: 'Generate a password first', type: VaultXToastType.warning);
      return;
    }
    Clipboard.setData(ClipboardData(text: generatedPassword));
    clipboardClearTimer?.cancel();
    clipboardClearTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
    
    VaultXToast.show(
      context,
      message: 'Password copied to clipboard. Auto-clears in 30 seconds.',
      type: VaultXToastType.success,
    );
  }

  @override
  void dispose() {
    clipboardClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = widget.generatorController.evaluatePasswordStrength(
      password: generatedPassword,
      mustHaveUppercase: includeUppercase,
      mustHaveLowercase: includeLowercase,
      mustHaveNumbers: includeNumbers,
      mustHaveSymbols: includeSymbols,
    );

    int activeSegments = 0;
    Color strengthColor = Colors.red;
    String label = 'Weak';

    switch (strength) {
      case PasswordStrength.veryWeak:
        activeSegments = 1;
        strengthColor = const Color(0xFFffb4ab);
        label = 'Very Weak';
        break;
      case PasswordStrength.weak:
        activeSegments = 1;
        strengthColor = const Color(0xFFffb4ab);
        label = 'Weak';
        break;
      case PasswordStrength.fair:
        activeSegments = 2;
        strengthColor = const Color(0xFFFFB74D);
        label = 'Fair';
        break;
      case PasswordStrength.good:
        activeSegments = 3;
        strengthColor = const Color(0xFFFFEE58);
        label = 'Good';
        break;
      case PasswordStrength.strong:
        activeSegments = 4;
        strengthColor = const Color(0xFFadc7ff);
        label = 'Strong';
        break;
      case PasswordStrength.veryStrong:
        activeSegments = 4;
        strengthColor = const Color(0xFFadc7ff);
        label = 'Very Strong';
        break;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 16),
        Text('Generator', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text(
          'Create unbreakable security keys.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VaultXColors.onSurfaceVariant.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SECURE OUTPUT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: VaultXColors.primary),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_outlined, size: 20),
                        onPressed: _generatePassword,
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy_outlined, size: 20),
                        onPressed: _copyToClipboard,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SelectableText(
                  generatedPassword.isNotEmpty ? generatedPassword : 'Generating...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Strength', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant)),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: strengthColor)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(4, (index) {
                  final isActive = index < activeSegments;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? strengthColor : const Color(0xFF1c1b1b),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: strengthColor.withOpacity(0.6),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LENGTH', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: VaultXColors.outline)),
            Text(
              '$passwordLength',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: VaultXColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        Slider(
          value: passwordLength.toDouble(),
          min: 8,
          max: 64,
          divisions: 56,
          onChanged: (val) {
            setState(() {
              passwordLength = val.toInt();
            });
            _generatePassword();
          },
        ),
        const SizedBox(height: 16),
        _buildToggleRow(Icons.text_fields_outlined, 'Uppercase (A-Z)', includeUppercase, (val) {
          setState(() => includeUppercase = val);
          _generatePassword();
        }),
        const SizedBox(height: 8),
        _buildToggleRow(Icons.format_size_outlined, 'Lowercase (a-z)', includeLowercase, (val) {
          setState(() => includeLowercase = val);
          _generatePassword();
        }),
        const SizedBox(height: 8),
        _buildToggleRow(Icons.pin_outlined, 'Numbers (0-9)', includeNumbers, (val) {
          setState(() => includeNumbers = val);
          _generatePassword();
        }),
        const SizedBox(height: 8),
        _buildToggleRow(Icons.alternate_email_outlined, 'Symbols (!@#\$)', includeSymbols, (val) {
          setState(() => includeSymbols = val);
          _generatePassword();
        }),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _copyToClipboard,
          icon: const Icon(Icons.content_copy_outlined, size: 20, color: VaultXColors.onPrimary),
          label: Text('Copy Password', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: VaultXColors.onPrimary)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildToggleRow(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: VaultXColors.onSurfaceVariant, size: 20),
              const SizedBox(width: 12),
              Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  final AuthController authController;
  final TransferController transferController;
  final VaultCore vault;
  final VoidCallback onStateChange;
  final VoidCallback? onVaultReset;

  const SettingsTab({
    required this.authController,
    required this.transferController,
    required this.vault,
    required this.onStateChange,
    this.onVaultReset,
    Key? key,
  }) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late int selectedAutoLockMinutes;
  bool isClearClipboardEnabled = true;

  @override
  void initState() {
    super.initState();
    selectedAutoLockMinutes = widget.authController.authState.autoLockMinutes;
  }

  void _showAutoLockSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLockOption(1, '1 minute'),
            _buildLockOption(2, '2 minutes'),
            _buildLockOption(5, '5 minutes'),
            _buildLockOption(10, '10 minutes'),
            _buildLockOption(30, '30 minutes'),
          ],
        ),
      ),
    );
  }

  Widget _buildLockOption(int minutes, String label) {
    return RadioListTile<int>(
      title: Text(label),
      value: minutes,
      groupValue: selectedAutoLockMinutes,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            selectedAutoLockMinutes = val;
          });
          widget.authController.authState.setAutoLockMinutes(val);
          Navigator.pop(context);
          VaultXToast.show(context, message: 'Auto-lock updated to $label', type: VaultXToastType.success);
        }
      },
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Vault'),
        content: const Text('This will decrypt and package your vault records. Please confirm your master password to complete.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordConfirmationDialog('export');
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Vault'),
        content: const Text('Select a VaultX export file (.vlt) to import and merge records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImportFile();
            },
            child: const Text('SELECT FILE'),
          ),
        ],
      ),
    );
  }

  void _showPasswordConfirmationDialog(String action) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'export' ? 'Confirm Export' : 'Confirm Import'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: 'Master Password',
            hintText: 'Enter your master password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (action == 'export') {
                _performExport(passwordController.text);
              }
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  void _performExport(String masterPassword) async {
    try {
      final result = await widget.transferController.exportVault(
        masterPassword: masterPassword,
      );
      if (!mounted) return;

      if (!result.success) {
        VaultXToast.show(context, message: result.message, type: VaultXToastType.error);
        return;
      }

      final filename = widget.transferController.generateExportFilename();
      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      final tempFile = '${directory.path}/$filename';
      
      final saveResult = await widget.transferController.saveVaultToFile(
        vaultJson: result.data ?? '',
        filePath: tempFile,
      );
      if (!mounted) return;

      if (!saveResult.success) {
        VaultXToast.show(context, message: saveResult.message, type: VaultXToastType.error);
        return;
      }

      await Share.shareXFiles(
        [XFile(tempFile)],
        subject: 'VaultX Backup',
      );
      if (!mounted) return;

      VaultXToast.show(context, message: 'Vault exported successfully', type: VaultXToastType.success);
    } catch (e) {
      if (mounted) {
        VaultXToast.show(context, message: 'Export failed: $e', type: VaultXToastType.error);
      }
    }
  }

  void _pickImportFile() async {
    try {
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (!mounted) return;
      if (fileResult != null && fileResult.files.isNotEmpty && fileResult.files.first.path != null) {
        final filePath = fileResult.files.first.path!;
        _showMergeStrategyDialog(filePath);
      }
    } catch (e) {
      if (mounted) {
        VaultXToast.show(context, message: 'Failed to pick file: $e', type: VaultXToastType.error);
      }
    }
  }

  void _showMergeStrategyDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Settings'),
        content: const Text('Select a conflict resolution merge strategy for conflicting site names:'),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImportPasswordDialog(filePath, MergeStrategy.keepExisting);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VaultXColors.surfaceContainerHigh,
                  foregroundColor: Colors.white,
                ),
                child: const Text('KEEP EXISTING'),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImportPasswordDialog(filePath, MergeStrategy.keepBoth);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VaultXColors.surfaceContainerHigh,
                  foregroundColor: Colors.white,
                ),
                child: const Text('KEEP BOTH'),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImportPasswordDialog(filePath, MergeStrategy.overwrite);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VaultXColors.errorContainer,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OVERWRITE CONFLICTS'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImportPasswordDialog(String filePath, MergeStrategy strategy) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Master Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: 'Import File Key',
            hintText: 'Enter password for import file',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performImport(filePath, passwordController.text, strategy);
            },
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
  }

  void _performImport(String filePath, String masterPassword, MergeStrategy strategy) async {
    try {
      final loadResult = await widget.transferController.loadVaultFromFile(filePath: filePath);
      if (!mounted) return;

      if (!loadResult.success) {
        VaultXToast.show(context, message: loadResult.message, type: VaultXToastType.error);
        return;
      }

      final mergeResult = await widget.transferController.mergeVaults(
        importVaultJson: loadResult.data ?? '',
        importMasterPassword: masterPassword,
        strategy: strategy,
      );
      if (!mounted) return;

      if (!mergeResult.success) {
        VaultXToast.show(context, message: mergeResult.message, type: VaultXToastType.error);
        return;
      }

      await FileManager.saveVaultToFile(mergeResult.data ?? '');
      if (!mounted) return;
      widget.onStateChange();

      VaultXToast.show(
        context,
        message: 'Imported successfully: ${mergeResult.mergeStats?.mergedCount ?? 0} records merged.',
        type: VaultXToastType.success,
      );
    } catch (e) {
      if (mounted) {
        VaultXToast.show(context, message: 'Import failed: $e', type: VaultXToastType.error);
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Master Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscurePassword,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscurePassword,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscurePassword,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performChangePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                  confirmPasswordController.text,
                );
              },
              child: const Text('CHANGE'),
            ),
          ],
        ),
      ),
    );
  }

  void _performChangePassword(String currentPassword, String newPassword, String confirmPassword) async {
    try {
      final vaultJson = widget.vault.serializeVault();
      final result = await widget.authController.changeMasterPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
        vaultJson: vaultJson,
      );

      if (mounted) {
        if (result.success) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Password Updated'),
                ],
              ),
              content: const Text(
                'Your master password has been successfully updated!\n\nFor security reasons, biometric unlock has been deactivated. Please log in with your new password once to re-activate biometric authentication.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    widget.authController.lockVault();
                    widget.onStateChange();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VaultXColors.primary,
                    foregroundColor: VaultXColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('OK, LOCK & ACTIVATE'),
                ),
              ],
            ),
          );
        } else {
          VaultXToast.show(context, message: result.message, type: VaultXToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        VaultXToast.show(context, message: 'Failed to change password: $e', type: VaultXToastType.error);
      }
    }
  }

  void _showDestructiveDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: VaultXColors.error),
            SizedBox(width: 8),
            Text('Delete Vault?'),
          ],
        ),
        content: const Text(
          'This will permanently delete your existing vault and ALL stored credentials.\n\nTHIS ACTION IS COMPLETELY IRREVERSIBLE. YOU WILL LOSE ALL DATA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FileManager.deleteVaultFile();
                await widget.authController.keystore.clearVaultKey();
                if (!mounted) return;
                widget.authController.lockVault();
                widget.onStateChange();
                widget.onVaultReset?.call();
                
                VaultXToast.show(context, message: 'Vault deleted completely.', type: VaultXToastType.info);
              } catch (e) {
                if (mounted) {
                  VaultXToast.show(context, message: 'Failed to delete vault: $e', type: VaultXToastType.error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VaultXColors.error,
              foregroundColor: VaultXColors.onError,
            ),
            child: const Text('DELETE VAULT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 16),
        Text('Settings', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text(
          'Manage app performance and security policies.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VaultXColors.onSurfaceVariant.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: 24),
        Text(
          'SECURITY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: VaultXColors.outline),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Auto-lock timer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Vault locks after inactivity ($selectedAutoLockMinutes mins)', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showAutoLockSelectionDialog,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Clear Clipboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Auto-purge sensitive strings after 30s', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                value: isClearClipboardEnabled,
                onChanged: (val) {
                  setState(() {
                    isClearClipboardEnabled = val;
                  });
                  VaultXToast.show(context, message: val ? 'Clipboard auto-clear enabled' : 'Clipboard auto-clear disabled', type: VaultXToastType.info);
                },
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Change Master Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Update secure master validation key', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showChangePasswordDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'DATA MANAGEMENT',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: VaultXColors.outline),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.file_download_outlined, color: VaultXColors.primary),
                title: const Text('Export Vault (.vlt)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Package secure backup copy', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                trailing: const Icon(Icons.download, size: 20),
                onTap: _showExportDialog,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.file_upload_outlined, color: VaultXColors.primary),
                title: const Text('Import Vault (.vlt)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Import secure backup copy', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                trailing: const Icon(Icons.upload, size: 20),
                onTap: _showImportDialog,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.delete_forever_outlined, color: VaultXColors.error),
                title: const Text('Delete Vault', style: TextStyle(color: VaultXColors.error, fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Completely wipe credentials file', style: TextStyle(fontSize: 12, color: VaultXColors.onSurfaceVariant.withOpacity(0.7))),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: VaultXColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VaultXColors.error.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'IRREVERSIBLE',
                    style: TextStyle(color: VaultXColors.error, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: _showDestructiveDeleteConfirmation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Text(
                'KRYPTIX VERSION 2.4.0-STABLE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: VaultXColors.onSurfaceVariant.withOpacity(0.4)),
              ),
              const SizedBox(height: 4),
              Text(
                'END-TO-END ENCRYPTION ACTIVE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8, color: VaultXColors.onSurfaceVariant.withOpacity(0.3)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _AddEntryDialog extends StatefulWidget {
  final void Function(String siteName, String url, String username,
      String password, String notes) onSave;

  const _AddEntryDialog({required this.onSave, Key? key}) : super(key: key);

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  late TextEditingController siteNameController;
  late TextEditingController urlController;
  late TextEditingController usernameController;
  late TextEditingController passwordController;
  late TextEditingController notesController;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    siteNameController = TextEditingController();
    urlController = TextEditingController();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
    notesController = TextEditingController();
  }

  @override
  void dispose() {
    siteNameController.dispose();
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add New Password',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: siteNameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
                hintText: 'e.g., Gmail',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL (optional)',
                hintText: 'e.g., https://gmail.com',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username or Email',
                hintText: 'Your account username',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: '••••••••',
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Extra info or details',
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (siteNameController.text.isEmpty ||
                          usernameController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        VaultXToast.show(
                          context,
                          message: 'Please complete all required fields.',
                          type: VaultXToastType.warning,
                        );
                        return;
                      }
                      widget.onSave(
                        siteNameController.text,
                        urlController.text,
                        usernameController.text,
                        passwordController.text,
                        notesController.text,
                      );
                    },
                    child: const Text('SAVE RECORD'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  final VaultEntry entry;
  final void Function(String siteName, String url, String username,
      String password, String notes) onSave;

  const _EditEntryDialog({
    required this.entry,
    required this.onSave,
    Key? key,
  }) : super(key: key);

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late TextEditingController siteNameController;
  late TextEditingController urlController;
  late TextEditingController usernameController;
  late TextEditingController passwordController;
  late TextEditingController notesController;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    siteNameController = TextEditingController(text: widget.entry.siteName);
    urlController = TextEditingController();
    usernameController = TextEditingController(text: widget.entry.username);
    passwordController = TextEditingController(text: widget.entry.password);
    notesController = TextEditingController(text: widget.entry.notes);
  }

  @override
  void dispose() {
    siteNameController.dispose();
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Password Record',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: siteNameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL (optional)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username or Email',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (siteNameController.text.isEmpty ||
                          usernameController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        VaultXToast.show(
                          context,
                          message: 'Please complete all required fields.',
                          type: VaultXToastType.warning,
                        );
                        return;
                      }
                      widget.onSave(
                        siteNameController.text,
                        urlController.text,
                        usernameController.text,
                        passwordController.text,
                        notesController.text,
                      );
                    },
                    child: const Text('SAVE CHANGES'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
