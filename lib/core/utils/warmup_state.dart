import 'package:helpcare/core/utils/settings_storage.dart';

/// SC_01_06 warm-up state manager.
/// - Works in foreground/background because state is persisted.
/// - Provides a single place to read/update warm-up flags safely.
class WarmupState {
  WarmupState._();

  /// [start]가 저장소에 쓰이기 전 await 구간 — 이 사이에 혈당/링크 알림이 새지 않도록 한다.
  static bool _persistingWarmup = false;

  static const String _kStartAt = 'sc0106WarmupStartAt';
  static const String _kEndsAt = 'sc0106WarmupEndsAt';
  static const String _kActive = 'sc0106WarmupActive';
  static const String _kDoneAt = 'sc0106WarmupDoneAt';
  static const String _kEqsn = 'sc0106WarmupEqsn';

  static Future<bool> isActive() async {
    if (_persistingWarmup) return true;
    final DateTime now = DateTime.now();
    try {
      final st = await SettingsStorage.load();
      final bool active = st[_kActive] == true;
      if (!active) return false;

      final String endsRaw = (st[_kEndsAt] as String? ?? '').trim();
      final DateTime? endsAt = endsRaw.isEmpty ? null : DateTime.tryParse(endsRaw)?.toLocal();
      if (endsAt != null && now.isAfter(endsAt)) {
        st[_kActive] = false;
        st[_kDoneAt] = now.toUtc().toIso8601String();
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
}
