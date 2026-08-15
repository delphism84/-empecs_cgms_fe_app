import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sensor usage: only [sensorStartAt] (UTC ISO) is stored; display and remaining time are always derived from it.
class SensorUsageSnapshot {
  const SensorUsageSnapshot({
    required this.startAtLocal,
    required this.validity,
    required this.used,
    required this.remaining,
    required this.remainDays,
    required this.remainHours,
    required this.progressUsed,
  });

  final DateTime startAtLocal;
  final Duration validity;
  final Duration used;
  final Duration remaining;
  final int remainDays;
  final int remainHours;
  /// 0..1 fraction of validity period already used (progress bar).
  final double progressUsed;
}

class SensorUsage {
  SensorUsage._();

  /// Stored UTC ISO string -> device local time for UI.
  static DateTime? parseStartLocal(String? isoUtc) {
    final String raw = isoUtc?.trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String formatStartLocal(DateTime t) {
    return '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 만료 예정 일시 표기 — `MM/dd HH:mm`
  static String formatExpiryAt(DateTime t) {
    return '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 잔여시간 표기 — `11시간 59분` / `59분` (Dexcom 하단 시트 형식).
  /// 초 단위는 내림. 0 이하이면 `0분`.
  static String formatRemainHm(Duration d) {
    final int total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    if (h <= 0) return 'sensor_expiry_fmt_m'.tr(args: <String>['$m']);
    return 'sensor_expiry_fmt_hm'.tr(args: <String>['$h', '$m']);
  }

  /// Remaining time and progress from [startLocal] only (no separate remain field).
  static SensorUsageSnapshot? snapshotFromStartLocal(
    DateTime? startLocal, {
    Duration? validity,
  }) {
    if (startLocal == null) return null;
    final Duration valid = validity ?? AppConstants.sensorValidityDuration;
    final DateTime now = DateTime.now();
    final Duration used = now.difference(startLocal);
    final Duration remain = valid - used;
    final int remainSec = remain.inSeconds < 0 ? 0 : remain.inSeconds;
    final double pct = valid.inSeconds > 0
        ? (used.inSeconds / valid.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    return SensorUsageSnapshot(
      startAtLocal: startLocal,
      validity: valid,
      used: used,
      remaining: Duration(seconds: remainSec),
      remainDays: remainSec ~/ (24 * 3600),
      remainHours: (remainSec % (24 * 3600)) ~/ 3600,
      progressUsed: pct,
    );
  }

  static Future<SensorUsageSnapshot?> loadSnapshot() async {
    final Map<String, dynamic> st = await SettingsStorage.load();
    if (SettingsService.stripStaleSensorStart(st)) {
      await SettingsStorage.save(st);
    }
    return snapshotFromStartLocal(parseStartLocal(st['sensorStartAt'] as String?));
  }

  /// After QR / eqsn is set, before server: record start time in UTC.
  static bool recordLocalStartUtc(Map<String, dynamic> st, String eqsn) {
    final String want = eqsn.trim();
    if (want.isEmpty) return false;
    SettingsService.stripStaleSensorStart(st);
    final String start = (st['sensorStartAt'] as String? ?? '').trim();
    final String owner = (st['sensorStartAtEqsn'] as String? ?? '').trim();
    if (start.isNotEmpty &&
        owner.isNotEmpty &&
        SettingsService.serialsMatchForEq(owner, want)) {
      return false;
    }
    st['sensorStartAt'] = DateTime.now().toUtc().toIso8601String();
    st['sensorStartAtEqsn'] = want;
    return true;
  }

  static bool _hasOnlineAuthToken(String token) {
    if (token.isEmpty) return false;
    if (token == 'OFFLINE_USER_TOKEN') return false;
    if (token.startsWith('LOCAL_USER') || token.startsWith('local-')) return false;
    return true;
  }

  static void _notifyStartChanged() {
    try {
      DataSyncBus().emitGlucoseBulk(count: 1);
    } catch (_) {}
    try {
      AppSettingsBus.notify();
    } catch (_) {}
  }

  /// Online: server EQ row wins (empty startAt clears local). No row: upload local for this SN.
  static Future<bool> syncStartAtWithServer({String? bleMac}) async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      if (eqsn.isEmpty) return false;

      final String token = (st['authToken'] as String? ?? '').trim();
      if (!_hasOnlineAuthToken(token)) return false;

      if (SettingsService.stripStaleSensorStart(st)) {
        await SettingsStorage.save(st);
      }

      String? mac = bleMac;
      if (mac == null || mac.trim().isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          mac = prefs.getString('cgms.last_mac');
        } catch (_) {}
      }

      await ApiClient().loadToken();
      final SensorStartSyncResult r = await SettingsService().syncEqStartAuthoritative(
        eqsn: eqsn,
        bleMac: mac,
      );
      if (r.changed || r.cleared || r.uploaded) {
        _notifyStartChanged();
      }
      return r.changed || r.cleared || r.uploaded || r.serverAuthoritative;
    } catch (_) {
      return false;
    }
  }

  /// Alias for login / offline-to-online hooks.
  static Future<bool> applyServerStartOverwrite({String? bleMac}) =>
      syncStartAtWithServer(bleMac: bleMac);
}
