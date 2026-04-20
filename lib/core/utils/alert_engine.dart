import 'dart:async';

import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/signal_loss_monitor_log.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

/// 간단 알람 엔진(봇 검수용 포함)
/// - DataSyncBus의 glucosePoint를 감시
/// - backend /api/settings/alarms 를 주기적으로 가져와 임계값 비교
/// - 조건 충족 시 로컬 노티 발생 + lastAlert 저장(디버그)
class AlertEngine {
  AlertEngine._internal();
  static final AlertEngine _instance = AlertEngine._internal();
  factory AlertEngine() => _instance;

  StreamSubscription<DataSyncEvent>? _sub;
  DateTime _alarmsFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  List<Map<String, dynamic>> _alarms = const [];

  // 간단 중복 방지(타입별 마지막 발화 시각)
  final Map<String, DateTime> _lastFired = {};
  // 급변동(rate) 계산용: 마지막 포인트
  DateTime? _lastPointAt;
  double? _lastPointValue;

  // Warm-up 중에는 알람이 발생하면 안됨(SC_01_06). 매 이벤트마다 저장소를 읽어 웜업 직후에도 억제가 누락되지 않게 한다.

  /// 호환용: 웜업 플래그 저장 직후 [invalidateWarmupCache] 호출 유지 권장.
  void invalidateWarmupCache() {}

  Future<bool> _isWarmupActive() async {
    return WarmupState.isActive();
  }

  Future<void> start() async {
    _sub ??= DataSyncBus().stream.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// 설정 변경 직후 즉시 반영을 위해 알람 캐시 무효화
  void invalidateAlarmsCache() {
    _alarmsFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
    _alarms = const [];
  }

  /// BLE 링크가 끊겼을 때 (재연결 시도 전·중 포함). Weak RSSI 전용 알림은 사용하지 않음(req 1-2).
  Future<void> notifyBleLinkLost() async {
    try {
      if (await _isWarmupActive()) return;
      invalidateAlarmsCache();
      await _ensureAlarmsLoaded();
      for (final raw in _alarms) {
        if ((raw['type'] ?? '').toString() != 'system') continue;
        final Map<String, dynamic> a = Map<String, dynamic>.from(raw);
        SignalLossMonitorLog.append('BLE disconnected — evaluating signal_loss alarm');
        await _fireSystemAlarmFromConfig(a, reason: 'signal_loss');
        return;
      }
    } catch (e) {
      try {
        SignalLossMonitorLog.append('notifyBleLinkLost error: $e');
      } catch (_) {}
    }
  }

  /// 디버그/봇 검수용: 시스템(신호 손실 등) 알람 강제 트리거
  Future<void> debugTriggerSystemAlarm({String reason = 'signal_loss'}) async {
    invalidateAlarmsCache();
    await _ensureAlarmsLoaded();
    final String r = reason.trim().isEmpty ? 'signal_loss' : reason.trim();
    final String useReason = r == 'weak_rssi' ? 'signal_loss' : r;
    final List<Map<String, dynamic>> systems = _alarms.where((a) => (a['type'] ?? '').toString() == 'system').cast<Map<String, dynamic>>().toList();
    if (systems.isEmpty) return;
    for (final a in systems) {
      await _fireSystemAlarmFromConfig(Map<String, dynamic>.from(a), reason: useReason);
    }
  }

  Future<void> _fireSystemAlarmFromConfig(
    Map<String, dynamic> a, {
    required String reason,
  }) async {
    try {
      if (await _isWarmupActive()) return;
      if (a['enabled'] != true) return;
      if (_inQuietHours(a['quietFrom'] as String?, a['quietTo'] as String?)) {
        SignalLossMonitorLog.append('alarm skipped (quiet hours)');
        return;
      }

      bool sound = (a['sound'] is bool) ? (a['sound'] == true) : true;
      bool vibrate = (a['vibrate'] is bool) ? (a['vibrate'] == true) : true;
      final int repeatMin = (a['repeatMin'] as num?)?.toInt() ?? 10;
      const String repeatKey = 'system:signal_loss';
      final last = _lastFired[repeatKey];
      if (last != null && DateTime.now().difference(last) < Duration(minutes: repeatMin.clamp(1, 120))) {
        SignalLossMonitorLog.append('alarm skipped (repeat every $repeatMin min · signal_loss)');
        return;
      }
      _lastFired[repeatKey] = DateTime.now();
      SignalLossMonitorLog.append('alarm raise!');

      final Map<String, Map<String, String>> msg = {
        'signal_loss': {'title': 'Signal loss', 'body': 'Sensor signal lost'},
        'expired': {'title': 'Sensor expired', 'body': 'Sensor expired'},
        'error': {'title': 'Sensor error', 'body': 'Sensor error detected'},
        'abnormal': {'title': 'Abnormal signal', 'body': 'Abnormal sensor signal detected'},
      };
      final String r = reason.trim().isEmpty ? 'signal_loss' : reason.trim();
      final String title = (msg[r]?['title']) ?? 'System alert';
      String body = (msg[r]?['body']) ?? 'System alert';
      if (r != 'signal_loss') {
        body = '$body ($r)';
      }
      final int nid = 1010 + (r.hashCode.abs() % 50);
      final String payload = 'alarm:system:signal_loss';
      await NotificationService().showAlert(
        id: nid,
        title: title,
        body: body,
        payload: payload,
        critical: false,
        sound: sound,
        vibrate: vibrate,
      );

      try {
        final s = await SettingsStorage.load();
        s['lastAlert'] = {
          'id': nid,
          'title': title,
          'body': body,
          'payload': payload,
          'critical': false,
          'alarmType': 'system',
          'reason': r,
          'sound': sound,
          'vibrate': vibrate,
          'overrideDnd': false,
          'time': DateTime.now().toUtc().toIso8601String(),
        };
        await SettingsStorage.save(s);
      } catch (_) {}
    } catch (e) {
      try {
        SignalLossMonitorLog.append('_fireSystemAlarmFromConfig error: $e');
      } catch (_) {}
    }
  }

  Future<void> _onEvent(DataSyncEvent e) async {
    if (e.kind != DataSyncKind.glucosePoint) return;
    final double v = (e.payload['value'] as num?)?.toDouble() ?? double.nan;
    if (v.isNaN) return;
    final DateTime? t = (e.payload['time'] is DateTime) ? (e.payload['time'] as DateTime) : null;
    // SC_01_06: Warm-Up 중에는 알람이 발생하면 안됨
    if (await _isWarmupActive()) return;
    await _ensureAlarmsLoaded();
    await _evaluate(v, t: t);
  }

  /// 알람 목록은 로컬만 사용. listAlarms()가 비어 있으면 기본 시드 후 반환.
  Future<void> _ensureAlarmsLoaded() async {
    final now = DateTime.now();
    if (now.difference(_alarmsFetchedAt) < const Duration(seconds: 30)) return;
    try {
      final list = await SettingsService().listAlarms();
      _alarms = list.cast<Map<String, dynamic>>().toList();
      _alarmsFetchedAt = now;
    } catch (_) {
      _alarms = [];
      _alarmsFetchedAt = now;
    }
  }

  bool _inQuietHours(String? from, String? to) {
    if (from == null || from.isEmpty || to == null || to.isEmpty) return false;
    try {
      final now = DateTime.now();
      final partsF = from.split(':');
      final partsT = to.split(':');
      final int fh = int.tryParse(partsF.isNotEmpty ? partsF[0].trim() : '') ?? -1;
      final int fm = int.tryParse(partsF.length > 1 ? partsF[1].trim() : '0') ?? 0;
      final int th = int.tryParse(partsT.isNotEmpty ? partsT[0].trim() : '') ?? -1;
      final int tm = int.tryParse(partsT.length > 1 ? partsT[1].trim() : '0') ?? 0;
      if (fh < 0 || fh > 23 || th < 0 || th > 23) return false;
      if (fm < 0 || fm > 59 || tm < 0 || tm > 59) return false;
      final n = now.hour * 60 + now.minute;
      final a = fh * 60 + fm;
      final b = th * 60 + tm;
      if (a == b) return false;
      if (a < b) return n >= a && n < b;
      // overnight (e.g., 22:00 ~ 07:00)
      return n >= a || n < b;
    } catch (_) {
      return false;
    }
  }

  Future<void> _evaluate(double value, {DateTime? t}) async {
    String unit = 'mg/dL';
    double factor = 1.0;
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl').trim();
      if (u == 'mmol') {
        unit = 'mmol/L';
        factor = 1.0 / 18.02;
      }
    } catch (_) {}
    String fmtGlucose(double v) => unit == 'mmol/L'
        ? (v * factor).toStringAsFixed(1)
        : v.round().toString();
    String fmtRate(double v) => unit == 'mmol/L'
        ? (v * factor).toStringAsFixed(1)
        : v.toStringAsFixed(2);

    for (final a in _alarms) {
      final String type = (a['type'] ?? '').toString();
      final bool enabled = a['enabled'] == true;
      final num? th = a['threshold'] as num?;
      if (!enabled || th == null) continue;

      // quiet hours
      if (_inQuietHours(a['quietFrom'] as String?, a['quietTo'] as String?)) continue;

      bool sound = (a['sound'] is bool) ? (a['sound'] == true) : true;
      bool vibrate = (a['vibrate'] is bool) ? (a['vibrate'] == true) : true;

      bool hit = false;
      bool critical = false;
      String title = 'CGMS Alert';
      String body = 'Value=${fmtGlucose(value)} $unit';
      String payload = 'alarm:$type';

      if (type == 'high') {
        hit = value >= th.toDouble();
        title = 'High glucose';
        body = 'Glucose ${fmtGlucose(value)} $unit ≥ ${fmtGlucose(th.toDouble())} $unit';
      } else if (type == 'low') {
        hit = value <= th.toDouble();
        title = 'Low glucose';
        body = 'Glucose ${fmtGlucose(value)} $unit ≤ ${fmtGlucose(th.toDouble())} $unit';
      } else if (type == 'very_low') {
        hit = value <= th.toDouble();
        // overrideDnd=true 인 경우에만 "critical 채널(bypassDnd)"로 보낸다.
        critical = a['overrideDnd'] == true;
        title = 'Very low glucose';
        body = 'Glucose ${fmtGlucose(value)} $unit ≤ ${fmtGlucose(th.toDouble())} $unit';
      } else if (type == 'rate') {
        // 급변동 알람: |Δmg/dL| / 분 >= threshold(2 또는 3)
        // 이벤트가 너무 촘촘하면(0분) 오탐이 될 수 있어 최소 15초 이상일 때만 계산
        final DateTime now = (t ?? DateTime.now());
        if (_lastPointAt != null && _lastPointValue != null) {
          final dt = now.difference(_lastPointAt!).inMilliseconds / 60000.0; // minutes
          if (dt >= (15.0 / 60.0)) {
            final dv = (value - _lastPointValue!).abs();
            final rate = dv / dt; // mg/dL/min
            hit = rate >= th.toDouble();
            title = 'Rapid change';
            body = 'Rate ${fmtRate(rate)} $unit/min ≥ ${fmtRate(th.toDouble())} $unit/min';
          }
        }
        _lastPointAt = now;
        _lastPointValue = value;
      } else {
        continue;
      }

      if (!hit) continue;

      final int repeatMin = (a['repeatMin'] as num?)?.toInt() ?? 10;
      final last = _lastFired[type];
      if (last != null && DateTime.now().difference(last) < Duration(minutes: repeatMin.clamp(1, 120))) {
        continue;
      }
      _lastFired[type] = DateTime.now();

      // 노티 ID는 타입별 고정 (high와 rate가 1003 공유하던 문제 분리)
      final int nid = type == 'very_low'
          ? 1002
          : type == 'low'
              ? 1004
              : type == 'rate'
                  ? 1005
                  : 1003;
      await NotificationService().showAlert(
        id: nid,
        title: title,
        body: body,
        payload: payload,
        critical: critical,
        sound: sound,
        vibrate: vibrate,
      );

      // bot 검증 편의: 마지막 알람 스냅샷을 "정합성 있게" 한 번에 기록
      try {
        final s = await SettingsStorage.load();
        s['lastAlert'] = {
          'id': nid,
          'title': title,
          'body': body,
          'payload': payload,
          'critical': critical,
          'alarmType': type,
          'glucose': value,
          'threshold': th,
          'sound': sound,
          'vibrate': vibrate,
          'overrideDnd': (a['overrideDnd'] == true),
          'time': DateTime.now().toUtc().toIso8601String(),
        };
        await SettingsStorage.save(s);
      } catch (_) {}
    }
  }
}

