import 'dart:async';
import 'dart:convert';

import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

/// SN별 로컬 시작 시각으로 웜업 구간을 두고, 그동안 알람·노티 최종 호출을 막는다.
/// [isWarmupFinished]는 메모리에 두고 10초마다 저장소 기준으로 갱신한다(동기 게이트).
class SensorWarmupService {
  SensorWarmupService._();

  static const String _kStartBySn = 'sensorWarmupStartBySn';
  static const String _kDurationSec = 'sensorWarmupDurationSec';

  static Timer? _timer;
  static bool _isWarmupFinished = true;

  /// 알람·노티 게이트: false면 임계값 계산·notify 호출 금지.
  static bool get isWarmupFinished => _isWarmupFinished;

  /// SN 웜업 미종료이거나, SC_01_06 등 웜업 전면 UI가 떠 있는 동안 — 임계 계산·notify 이중 억제.
  static bool get shouldSuppressAlarmPipeline =>
      WarmupState.isWarmupNow || !_isWarmupFinished;

  static Future<void> init() async {
    await refreshFromStorage();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(refreshFromStorage());
    });
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  static Map<String, String> _parseStartMap(dynamic v) {
    if (v == null) return <String, String>{};
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString().trim().toUpperCase(), val.toString().trim()));
    }
    if (v is String && v.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString().trim().toUpperCase(), val.toString().trim()));
        }
      } catch (_) {}
    }
    return <String, String>{};
  }

  static int _readDurationSec(Map<String, dynamic> st) {
    final dynamic d = st[_kDurationSec];
    if (d is int) return d.clamp(60, 24 * 3600);
    if (d is num) return d.toInt().clamp(60, 24 * 3600);
    return 30 * 60;
  }

  /// 저장소 기준으로 웜업 종료 여부를 다시 계산한다.
  static Future<void> refreshFromStorage() async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String eq = (st['eqsn'] as String? ?? '').trim().toUpperCase();
      if (eq.isEmpty) {
        _isWarmupFinished = true;
        return;
      }
      final Map<String, String> map = _parseStartMap(st[_kStartBySn]);
      final String? startIso = map[eq];
      if (startIso == null || startIso.isEmpty) {
        // SN은 있는데 시작 기록 없음: 보수적으로 웜업 중으로 둔다(등록 직후 beginWarmup 전 레이스).
        _isWarmupFinished = false;
        return;
      }
      final DateTime? start = DateTime.tryParse(startIso)?.toUtc();
      if (start == null) {
        _isWarmupFinished = false;
        return;
      }
      final int dur = _readDurationSec(st);
      _isWarmupFinished = DateTime.now().toUtc().difference(start) >= Duration(seconds: dur);
    } catch (_) {
      _isWarmupFinished = true;
    }
  }

  /// 해당 SN에 웜업 창을 연다. 이미 기록이 있으면 시작 시각은 유지(같은 세션 재연결).
  static Future<void> beginWarmup(String eqsn, {int durationSec = 30 * 60}) async {
    final String k = eqsn.trim().toUpperCase();
    if (k.isEmpty) {
      _isWarmupFinished = true;
      return;
    }
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final Map<String, String> map = _parseStartMap(st[_kStartBySn]);
      if (!map.containsKey(k)) {
        map[k] = DateTime.now().toUtc().toIso8601String();
      }
      st[_kStartBySn] = map;
      st[_kDurationSec] = durationSec.clamp(60, 24 * 3600);
      await SettingsStorage.save(st);
    } catch (_) {}
    await refreshFromStorage();
  }

  /// UI에서 웜업 스킵(롱프레스 등): 해당 SN은 즉시 웜업 종료로 간주.
  static Future<void> applyUiWarmupSkipped(String eqsn) async {
    final String k = eqsn.trim().toUpperCase();
    if (k.isEmpty) return;
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final int dur = _readDurationSec(st);
      final Map<String, String> map = _parseStartMap(st[_kStartBySn]);
      map[k] = DateTime.now().toUtc().subtract(Duration(seconds: dur + 60)).toIso8601String();
      st[_kStartBySn] = map;
      await SettingsStorage.save(st);
    } catch (_) {}
    await refreshFromStorage();
  }

  /// 로그아웃 등: 웜업 기록 제거 후 알람 허용.
  static Future<void> resetAll() async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      st[_kStartBySn] = <String, String>{};
      st[_kDurationSec] = 30 * 60;
      await SettingsStorage.save(st);
    } catch (_) {}
    _isWarmupFinished = true;
    WarmupState.setWarmupUiVisible(false);
  }

  /// BLE만 붙고 웜업 화면을 거치지 않은 경우: SN에 시작 기록이 없으면 지금부터 웜업 창을 연다.
  static Future<void> ensureWarmupWindowForCurrentSnIfMissing() async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String k = (st['eqsn'] as String? ?? '').trim().toUpperCase();
      if (k.isEmpty) return;
      final Map<String, String> map = _parseStartMap(st[_kStartBySn]);
      if (map.containsKey(k)) return;
      await beginWarmup(k, durationSec: _readDurationSec(st));
    } catch (_) {}
  }
}
