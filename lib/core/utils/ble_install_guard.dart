import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_auto_pair_store.dart';
import 'ble_log_service.dart';
import 'ble_service.dart';
import 'settings_storage.dart';
import 'warmup_state.dart';

/// Detects reinstall / backup-restore and clears stale BLE auto-pair caches.
///
/// Marker file lives in application support (survives temp-cache clears on some devices).
/// SharedPreferences may restore after reinstall; a missing marker with leftover
/// prefs/BLE keys is treated as stale and wiped.
class BleInstallGuard {
  BleInstallGuard._();

  static const String markerPrefKey = 'cgms.install_guard_token';
  static const String markerFileName = 'install_guard.marker';

  /// Returns true when stale BLE caches were cleared.
  static Future<bool> ensureSafeStartup() async {
    if (kIsWeb) return false;
    bool wiped = false;
    try {
      if (await _detectStaleBleCacheAfterReinstall()) {
        final bool keepWarmup = await WarmupState.isActive();
        await wipePersistentBleState(clearWarmup: !keepWarmup);
        wiped = true;
      }
      await _syncMarkers();
    } catch (_) {
      try {
        await _syncMarkers();
      } catch (_) {}
    }
    try {
      await BleService().disconnect(clearPersistentPairing: wiped);
    } catch (_) {}
    return wiped;
  }

  /// Force-clear all BLE pairing caches (safe to call from logout / SN change).
  static Future<void> wipePersistentBleState({bool clearWarmup = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cgms.last_mac');
      await prefs.remove('cgms.last_name');
      await prefs.remove(BleAutoPairStore.kLastMacPair);
      await prefs.remove(markerPrefKey);
    } catch (_) {}
    try {
      await BleAutoPairStore.clear();
    } catch (_) {}
    try {
      await BleLogService().clear();
    } catch (_) {}
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      st['registeredDevices'] = <Map<String, dynamic>>[];
      st['lastScannedQrRaw'] = '';
      st['lastScannedQrFullSn'] = '';
      st['lastScannedQrSerial'] = '';
      st['lastScannedQrAt'] = '';
      st['lastScannedQrRegistered'] = false;
      if (clearWarmup) {
        st['sc0106WarmupActive'] = false;
        st['sc0106WarmupStartAt'] = '';
        st['sc0106WarmupEndsAt'] = '';
        st['sc0106WarmupDoneAt'] = '';
        st['sensorWarmupStartBySn'] = <String, dynamic>{};
      }
      await SettingsStorage.save(st);
    } catch (_) {}
    try {
      await _deleteMarkerFile();
    } catch (_) {}
  }

  static Future<bool> _detectStaleBleCacheAfterReinstall() async {
    final String? fileToken = await _readFileToken();
    final String? prefToken = await _readPrefToken();

    if (fileToken == null || fileToken.isEmpty) {
      if (prefToken != null && prefToken.isNotEmpty) return true;
      return false;
    }

    if (prefToken == null || prefToken.isEmpty || prefToken != fileToken) {
      return true;
    }
    return false;
  }

  static Future<void> _syncMarkers() async {
    String token = (await _readFileToken()) ?? '';
    if (token.isEmpty) {
      token = _newToken();
    }
    try {
      final File file = await _markerFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(token, flush: true);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(markerPrefKey, token);
    } catch (_) {}
  }

  static String _newToken() {
    final int n = Random.secure().nextInt(0x7FFFFFFF);
    return '${DateTime.now().toUtc().millisecondsSinceEpoch}-$n';
  }

  static Future<File> _markerFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$markerFileName');
  }

  static Future<void> _deleteMarkerFile() async {
    try {
      final File file = await _markerFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<String?> _readFileToken() async {
    try {
      final File file = await _markerFile();
      if (!await file.exists()) return null;
      final String v = (await file.readAsString()).trim();
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readPrefToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String v = (prefs.getString(markerPrefKey) ?? '').trim();
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }
}
