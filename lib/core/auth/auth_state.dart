import 'dart:typed_data';
import 'dart:async';
import '../vault/vault_core.dart';
import '../models/entry_model.dart';
import 'keystore.dart';

class AuthState {
  final VaultCore vault;
  final Keystore? keystore;
  bool _isAuthenticated = false;
  Timer? _autoLockTimer;
  int autoLockMinutes = 5;
  void Function()? _onAutoLock;

  AuthState({
    required this.vault,
    this.keystore,
    this.autoLockMinutes = 5,
  });

  bool get isAuthenticated => _isAuthenticated;
  bool get isVaultLocked => vault.isLocked;
  List<VaultEntry> get entries => vault.entries;
  Uint8List? get vaultKey => vault.vaultKey;

  void markAuthenticated() {
    _isAuthenticated = true;
    if (_onAutoLock != null) {
      _startAutoLockTimer();
    }
  }

  void markUnauthenticated() {
    _isAuthenticated = false;
    _cancelAutoLockTimer();
    vault.lockVault();
  }

  void recordActivity() {
    if (_isAuthenticated) {
      _resetAutoLockTimer();
    }
  }

  void startAutoLockTimer(void Function() onLock) {
    _onAutoLock = onLock;
  }

  void stopAutoLockTimer() {
    _cancelAutoLockTimer();
    _onAutoLock = null;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    autoLockMinutes = minutes;
    await keystore?.storeAutoLockMinutes(minutes);
    if (_autoLockTimer != null) {
      _resetAutoLockTimer();
    }
  }

  void _startAutoLockTimer() {
    _cancelAutoLockTimer();
    _autoLockTimer = Timer(Duration(minutes: autoLockMinutes), () {
      _autoLock();
    });
  }

  void _resetAutoLockTimer() {
    _startAutoLockTimer();
  }

  void _cancelAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }

  void _autoLock() {
    markUnauthenticated();
    _onAutoLock?.call();
  }

  void dispose() {
    _cancelAutoLockTimer();
  }
}

