import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class BiometricService {
  BiometricService._internal();
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    try {
      final st = await SettingsStorage.load();
      return st['biometricEnabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _debugBypass() async {
    if (!kDebugMode) return false;
    try {
      final st = await SettingsStorage.load();
      return st['biometricDebugBypass'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheck() async {
    try {
      if (await _debugBypass()) return true;
      final bool supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final bool can = await _auth.canCheckBiometrics;
      return can;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to continue'}) async {
    // bot/debug bypass
    if (await _debugBypass()) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

