import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-reconnect MAC only. Separate from [cgms.last_mac] and QR MAC.
class BleAutoPairStore {
  BleAutoPairStore._();

  static const String kLastMacPair = 'cgms.last_mac_pair';

  static String _normalizeKey(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String v = (prefs.getString(kLastMacPair) ?? '').trim();
      if (v.isEmpty || _normalizeKey(v).isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasPair() async {
    final String? v = await read();
    return v != null && v.isNotEmpty;
  }

  /// Call after user-initiated successful connect (QR or manual Connect).
  static Future<void> save(String deviceId) async {
    final String t = deviceId.trim();
    if (t.isEmpty || _normalizeKey(t).isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastMacPair, t);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kLastMacPair);
    } catch (_) {}
  }

  /// Top floating snackbar when auto-reconnect runs.
  static void showAutoPairingToast() {
    final messenger = AppNav.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final BuildContext? ctx = AppNav.navigatorKey.currentContext;
    final double top = ctx != null
        ? MediaQuery.paddingOf(ctx).top + 8
        : 48;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'AUTO PAIRING',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, top, 16, 0),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
