import 'dart:async';

import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

/// 설정 > 개발자: BLE 없이 [IngestQueueService] → 로컬 DB + [DataSyncBus]로
/// 임계 알람(very_low / low / high / rate / signal_loss) 재현.
class AlarmQaEmulator {
  AlarmQaEmulator._();

  static Future<void> _armTestSession() async {
    await WarmupState.completeNow();
    final AlertEngine eng = AlertEngine();
    eng.invalidateAlarmsCache();
    eng.debugResetAlarmEvaluationState();
    await eng.debugReloadAlarmsNow();
  }

  static double? _thresholdMgDl(List<Map<String, dynamic>> list, String type) {
    for (final Map<String, dynamic> a in list) {
      if ((a['type'] ?? '').toString() != type) continue;
      if (!SettingsService.parseAlarmBool(a['enabled'], defaultValue: true)) return null;
      return (a['threshold'] as num?)?.toDouble();
    }
    return null;
  }

  /// Very low: 임계보다 충분히 낮은 값 1포인트.
  static Future<String?> emitVeryLow() async {
    await _armTestSession();
    final List<Map<String, dynamic>> list = await SettingsService().listAlarms();
    final double? th = _thresholdMgDl(list, 'very_low');
    if (th == null) return 'alarm_qa_skip_very_low_disabled';
    final double v = (th - 8).clamp(25, th - 1).toDouble();
    IngestQueueService().enqueueGlucose(DateTime.now(), v);
    return null;
  }

  /// Low: very_low 초과 ~ low 이하.
  static Future<String?> emitLow() async {
    await _armTestSession();
    final List<Map<String, dynamic>> list = await SettingsService().listAlarms();
    final double? lo = _thresholdMgDl(list, 'low');
    if (lo == null) return 'alarm_qa_skip_low_disabled';
    final double vl = _thresholdMgDl(list, 'very_low') ?? 55;
    final double floor = vl + 1;
    if (lo <= floor) return 'alarm_qa_skip_low_range';
    final double v = ((lo + floor) / 2).clamp(floor, lo).toDouble();
    IngestQueueService().enqueueGlucose(DateTime.now(), v);
    return null;
  }

  /// High: 임계보다 충분히 높은 값.
  static Future<String?> emitHigh() async {
    await _armTestSession();
    final List<Map<String, dynamic>> list = await SettingsService().listAlarms();
    final double? hi = _thresholdMgDl(list, 'high');
    if (hi == null) return 'alarm_qa_skip_high_disabled';
    final double v = (hi + 20).clamp(hi + 1, 500).toDouble();
    IngestQueueService().enqueueGlucose(DateTime.now(), v);
    return null;
  }

  /// Rapid change: 30초 간격 두 포인트로 mg/dL/min ≥ 임계.
  static Future<String?> emitRapidChange() async {
    await _armTestSession();
    final List<Map<String, dynamic>> list = await SettingsService().listAlarms();
    final double? th = _thresholdMgDl(list, 'rate');
    if (th == null) return 'alarm_qa_skip_rate_disabled';
    final DateTime t0 = DateTime.now().subtract(const Duration(seconds: 30));
    final DateTime t1 = DateTime.now();
    const double base = 110;
    final double dtMin = t1.difference(t0).inMilliseconds / 60000.0;
    final double dv = (th * dtMin + 5).clamp(8, 200).toDouble();
    IngestQueueService().enqueueGlucose(t0, base);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    IngestQueueService().enqueueGlucose(t1, base + dv);
    return null;
  }

  /// Signal loss: 시스템 알람 경로(노티만, 혈당 포인트 없음).
  static Future<String?> emitSignalLoss() async {
    await _armTestSession();
    await AlertEngine().debugTriggerSystemAlarm(reason: 'signal_loss');
    return null;
  }
}
