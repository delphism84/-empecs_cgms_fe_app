import 'dart:async';

import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

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

  // Warm-up 중에는 알람이 발생하면 안됨(SC_01_06). 빈번한 I/O를 피하기 위해 짧은 캐시를 둔다.
  DateTime _warmupCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _warmupActiveCached = false;

  Future<bool> _isWarmupActive() async {
    final now = DateTime.now();
    if (now.difference(_warmupCheckedAt) < const Duration(seconds: 5)) return _warmupActiveCached;
    _warmupCheckedAt = now;
    try {
      final st = await SettingsStorage.load();
      final bool active = st['sc0106WarmupActive'] == true;
      if (!active) {
        _warmupActiveCached = false;
        return false;
      }
      final String endsRaw = (st['sc0106WarmupEndsAt'] as String? ?? '').trim();
      final DateTime? endsAt = endsRaw.isEmpty ? null : DateTime.tryParse(endsRaw)?.toLocal();
      if (endsAt != null && now.isAfter(endsAt)) {
        // 안전장치: 워밍업 시간이 지났는데 플래그가 남아있으면 자동 해제
        st['sc0106WarmupActive'] = false;
        st['sc0106WarmupDoneAt'] = now.toUtc().toIso8601String();
        await SettingsStorage.save(st);
        _warmupActiveCached = false;
        return false;
      }
      _warmupActiveCached = true;
      return true;
    } catch (_) {
      _warmupActiveCached = false;
      return false;
    }
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

  /// 디버그/봇 검수용: 시스템(신호 손실 등) 알람 강제 트리거
  Future<void> debugTriggerSystemAlarm({String reason = 'signal_loss'}) async {
    await _ensureAlarmsLoaded();
    // system 알람은 threshold가 없을 수 있으므로 별도 처리
    final List<Map<String, dynamic>> systems = _alarms.where((a) => (a['type'] ?? '').toString() == 'system').cast<Map<String, dynamic>>().toList();
    if (systems.isEmpty) return;

    for (final a in systems) {
      // quiet hours
      if (_inQuietHours(a['quietFrom'] as String?, a['quietTo'] as String?)) continue;
      bool sound = (a['sound'] is bool) ? (a['sound'] == true) : true;
      bool vibrate = (a['vibrate'] is bool) ? (a['vibrate'] == true) : true;
      final int repeatMin = (a['repeatMin'] as num?)?.toInt() ?? 10;
      // AR_01_01: mute all alarms (force silent)
      try {
        final st = await SettingsStorage.load();
        if (st['alarmsMuteAll'] == true) {
          sound = false;
          vibrate = false;
        }
      } catch (_) {}

      const String type = 'system';
      final last = _lastFired[type];
      if (last != null && DateTime.now().difference(last) < Duration(minutes: repeatMin.clamp(1, 120))) {
        continue;
      }
      _lastFired[type] = DateTime.now();

      final Map<String, Map<String, String>> msg = {
        'signal_loss': {'title': 'Signal loss', 'body': 'Sensor signal lost'},
        'expired': {'title': 'Sensor expired', 'body': 'Sensor expired'},
        'error': {'title': 'Sensor error', 'body': 'Sensor error detected'},
        'abnormal': {'title': 'Abnormal signal', 'body': 'Abnormal sensor signal detected'},
      };
      final String r = reason.trim().isEmpty ? 'signal_loss' : reason.trim();
      final String title = (msg[r]?['title']) ?? 'System alert';
      final String body = ((msg[r]?['body']) ?? 'System alert') + ' ($r)';
      final int nid = 1010 + (r.hashCode.abs() % 50);
      final payload = 'alarm:system:$reason';
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
          'reason': reason,
          'sound': sound,
          'vibrate': vibrate,
          'overrideDnd': false,
          'time': DateTime.now().toUtc().toIso8601String(),
        };
        await SettingsStorage.save(s);
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
      final partsF = from.split(':'); final partsT = to.split(':');
      final fh = int.parse(partsF[0]); final fm = int.parse(partsF[1]);
      final th = int.parse(partsT[0]); final tm = int.parse(partsT[1]);
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

      // AR_01_01: mute all alarms (force silent)
      try {
        final st = await SettingsStorage.load();
        if (st['alarmsMuteAll'] == true) {
          sound = false;
          vibrate = false;
          critical = false;
        }
      } catch (_) {}

      final int repeatMin = (a['repeatMin'] as num?)?.toInt() ?? 10;
      final last = _lastFired[type];
      if (last != null && DateTime.now().difference(last) < Duration(minutes: repeatMin.clamp(1, 120))) {
        continue;
      }
      _lastFired[type] = DateTime.now();

      // 노티 ID는 타입별 고정
      final int nid = type == 'very_low' ? 1002 : type == 'low' ? 1004 : 1003;
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

