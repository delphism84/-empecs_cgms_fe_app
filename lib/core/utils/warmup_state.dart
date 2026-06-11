import 'package:helpcare/core/utils/settings_storage.dart';

/// SC_01_06 warm-up state manager.
/// - Works in foreground/background because state is persisted.
/// - Provides a single place to read/update warm-up flags safely.
class WarmupState {
  WarmupState._();

  /// [start]가 저장소에 쓰이기 전 await 구간 — 이 사이에 혈당/링크 알림이 새지 않도록 한다.
  static bool _persistingWarmup = false;

  /// SC_01_06(및 동일 웜업 전면 UI)이 떠 있는 동안 true. SN 기반 게이트와 별도로 알람·notify를 확실히 막는다.
  static bool _warmupUiVisible = false;

  /// 웜업 전면 UI 표시 중이거나, 웜업 시작을 저장소에 반영하는 짧은 구간.
  static bool get isWarmupNow => _warmupUiVisible || _persistingWarmup;

  static void setWarmupUiVisible(bool visible) {
    _warmupUiVisible = visible;
  }

  static const String _kStartAt = 'sc0106WarmupStartAt';
  static const String _kEndsAt = 'sc0106WarmupEndsAt';
  static const String _kActive = 'sc0106WarmupActive';
  static const String _kDoneAt = 'sc0106WarmupDoneAt';
  static const String _kEqsn = 'sc0106WarmupEqsn';

  static Future<bool> isActive() async {
    if (_persistingWarmup) return true;
    // 종료 시각 비교는 UTC 단일 기준(로컬/파싱 혼선·DST 경계로 웜업이 일찍 끝나 알람이 새는 문제 방지).
    final DateTime nowUtc = DateTime.now().toUtc();
    try {
      final st = await SettingsStorage.load();
      final bool active = st[_kActive] == true;
      if (!active) return false;

      final String endsRaw = (st[_kEndsAt] as String? ?? '').trim();
      if (endsRaw.isEmpty) {
        // active인데 ends 없음: 억제 유지(보수), 로그만 남기고 싶으면 추후 추가
        return true;
      }
      final DateTime? parsed = DateTime.tryParse(endsRaw);
      if (parsed == null) return true;
      final DateTime endsUtc = parsed.isUtc ? parsed : parsed.toUtc();
      if (nowUtc.isAfter(endsUtc)) {
        st[_kActive] = false;
        st[_kDoneAt] = nowUtc.toIso8601String();
        await SettingsStorage.save(st);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> start({
    required int seconds,
    String eqsn = '',
  }) async {
    _persistingWarmup = true;
    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime ends = now.add(Duration(seconds: seconds));
      final st = await SettingsStorage.load();
      st[_kEqsn] = eqsn.trim();
      st[_kStartAt] = now.toIso8601String();
      st[_kEndsAt] = ends.toIso8601String();
      st[_kActive] = true;
      st[_kDoneAt] = '';
      await SettingsStorage.save(st);
    } finally {
      _persistingWarmup = false;
    }
  }

  static Future<void> completeNow() async {
    final st = await SettingsStorage.load();
    st[_kActive] = false;
    st[_kDoneAt] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
  }

  /// QA: UI 웜업 시작 시각을 과거로 당기고 종료 시각을 재계산한다.
  static Future<({DateTime startUtc, DateTime endsUtc})> shiftStartBack({
    Duration back = const Duration(minutes: 29),
    int totalSec = 30 * 60,
  }) async {
    final st = await SettingsStorage.load();
    final String s0 = (st[_kStartAt] as String? ?? '').trim();
    DateTime startUtc;
    if (s0.isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(s0);
      startUtc = parsed == null
          ? DateTime.now().toUtc().subtract(back)
          : (parsed.isUtc ? parsed : parsed.toUtc()).subtract(back);
    } else {
      startUtc = DateTime.now().toUtc().subtract(back);
    }
    final DateTime endsUtc = startUtc.add(Duration(seconds: totalSec));
    st[_kStartAt] = startUtc.toIso8601String();
    st[_kEndsAt] = endsUtc.toIso8601String();
    st[_kActive] = true;
    st[_kDoneAt] = '';
    await SettingsStorage.save(st);
    return (startUtc: startUtc, endsUtc: endsUtc);
  }
}
