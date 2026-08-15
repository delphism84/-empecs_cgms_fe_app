import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/sensor_usage.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// 센서 수명 단계. `active → expiringSoon(≤12h) → expired(0)`
enum SensorExpiryState { unknown, active, expiringSoon, expired }

@immutable
class SensorExpiryStatus {
  const SensorExpiryStatus({
    required this.state,
    required this.eqsn,
    required this.startAtLocal,
    required this.expiresAtLocal,
    required this.remaining,
  });

  final SensorExpiryState state;
  final String eqsn;
  final DateTime startAtLocal;
  final DateTime expiresAtLocal;
  final Duration remaining;

  bool get isExpired => state == SensorExpiryState.expired;
  bool get isExpiringSoon => state == SensorExpiryState.expiringSoon;

  @override
  String toString() =>
      'SensorExpiryStatus(${state.name}, eqsn=$eqsn, remain=${remaining.inMinutes}m, at=$expiresAtLocal)';
}

/// 센서 만료 예고(12시간 전)·만료 상태를 한곳에서 판정한다.
///
/// 화면은 이 서비스의 [status]만 구독하면 되고, "언제 팝업을 띄울지"의 1회성 규칙
/// (센서별 1회, 나중에 알림 스누즈)도 여기서 영속 상태로 관리한다.
/// 앱을 재시작해도 같은 센서에 대해 팝업이 중복되지 않는다.
class SensorExpiryService {
  SensorExpiryService._internal();
  static final SensorExpiryService _instance = SensorExpiryService._internal();
  factory SensorExpiryService() => _instance;

  static const String _kWarnShownForEqsn = 'expiryWarnShownForEqsn';
  static const String _kWarnSnoozed = 'expiryWarnSnoozedForEqsn';
  static const String _kExpiredShownForEqsn = 'expiredNoticeShownForEqsn';

  /// QA 전용: 만료 판정에 쓰는 유효기간을 덮어쓴다(기본 [AppConstants.sensorValidityDuration]).
  static Duration? qaValidityOverride;

  static const int _notifIdExpiringSoon = 3101;
  static const int _notifIdExpired = 3102;

  final ValueNotifier<SensorExpiryStatus?> status =
      ValueNotifier<SensorExpiryStatus?>(null);

  /// 팝업을 띄워야 하는 순간에 1회 발생. UI(게이트 위젯)가 구독한다.
  final StreamController<SensorExpiryStatus> _prompts =
      StreamController<SensorExpiryStatus>.broadcast();
  Stream<SensorExpiryStatus> get prompts => _prompts.stream;

  Timer? _timer;
  bool _evaluating = false;

  void start({Duration interval = const Duration(seconds: 20)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(evaluate()));
    unawaited(evaluate());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Duration get _validity =>
      qaValidityOverride ?? AppConstants.sensorValidityDuration;

  /// 현재 상태를 다시 계산하고, 필요하면 팝업/로컬 알림을 발생시킨다.
  Future<SensorExpiryStatus?> evaluate({bool silent = false}) async {
    if (_evaluating) return status.value;
    _evaluating = true;
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      final DateTime? start =
          SensorUsage.parseStartLocal(st['sensorStartAt'] as String?);
      if (start == null) {
        status.value = null;
        return null;
      }

      final DateTime expiresAt = start.add(_validity);
      final Duration remain = expiresAt.difference(DateTime.now());
      final SensorExpiryState state = remain <= Duration.zero
          ? SensorExpiryState.expired
          : (remain <= AppConstants.sensorExpiryWarnBefore
              ? SensorExpiryState.expiringSoon
              : SensorExpiryState.active);

      final SensorExpiryStatus next = SensorExpiryStatus(
        state: state,
        eqsn: eqsn,
        startAtLocal: start,
        expiresAtLocal: expiresAt,
        remaining: remain.isNegative ? Duration.zero : remain,
      );
      status.value = next;
      if (silent) return next;

      if (state == SensorExpiryState.expired) {
        await _maybePromptExpired(st, next);
      } else if (state == SensorExpiryState.expiringSoon) {
        await _maybePromptExpiringSoon(st, next);
      }
      return next;
    } catch (e) {
      unawaited(BleLogService().add('EXPIRY', 'evaluate failed: $e'));
      return status.value;
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _maybePromptExpiringSoon(
      Map<String, dynamic> st, SensorExpiryStatus s) async {
    final String key = _sessionKey(s);
    if ((st[_kWarnSnoozed] as String? ?? '') == key) return; // "나중에 알림"
    if ((st[_kWarnShownForEqsn] as String? ?? '') == key) return; // 이미 표시함

    await SettingsStorage.save(<String, dynamic>{_kWarnShownForEqsn: key});
    unawaited(BleLogService()
        .add('EXPIRY', 'expiring-soon prompt (remain=${s.remaining.inMinutes}m eqsn=${s.eqsn})'));
    _prompts.add(s);
    // 백그라운드 대비 로컬 알림 1건
    await NotificationService().showAlert(
      id: _notifIdExpiringSoon,
      title: 'sensor_expiry_title'.tr(),
      body: 'sensor_expiry_notif_body'.tr(
        args: <String>[SensorUsage.formatRemainHm(s.remaining)],
      ),
      payload: 'sensor:expiring',
      sound: true,
      vibrate: true,
    );
  }

  Future<void> _maybePromptExpired(
      Map<String, dynamic> st, SensorExpiryStatus s) async {
    final String key = _sessionKey(s);
    if ((st[_kExpiredShownForEqsn] as String? ?? '') == key) return;

    await SettingsStorage.save(<String, dynamic>{_kExpiredShownForEqsn: key});
    unawaited(BleLogService().add('EXPIRY', 'expired prompt (eqsn=${s.eqsn})'));
    _prompts.add(s);
    await NotificationService().showAlert(
      id: _notifIdExpired,
      title: 'sensor_expired_title'.tr(),
      body: 'sensor_expired_desc'.tr(),
      payload: 'sensor:expired',
      sound: true,
      vibrate: true,
    );
  }

  /// "나중에 알림" — 만료 시점에 다시 알린다(예고 팝업만 억제).
  Future<void> snoozeWarning() async {
    final SensorExpiryStatus? s = status.value;
    if (s == null) return;
    await SettingsStorage.save(<String, dynamic>{_kWarnSnoozed: _sessionKey(s)});
    unawaited(BleLogService().add('EXPIRY', 'warning snoozed until expiry'));
  }

  /// 새 센서 등록 등으로 세션이 바뀌면 표시 이력을 비운다.
  Future<void> resetPromptHistory() async {
    await SettingsStorage.save(<String, dynamic>{
      _kWarnShownForEqsn: '',
      _kWarnSnoozed: '',
      _kExpiredShownForEqsn: '',
    });
    await NotificationService().cancel(_notifIdExpiringSoon);
    await NotificationService().cancel(_notifIdExpired);
  }

  /// 센서 교체 없이 같은 eqsn 을 재등록하면 시작시각이 바뀌므로 시작시각까지 키에 포함한다.
  String _sessionKey(SensorExpiryStatus s) =>
      '${s.eqsn}@${s.startAtLocal.toUtc().toIso8601String()}';

  /// 현재 상태를 QA dump 용 맵으로.
  Map<String, dynamic> debugSnapshot() {
    final SensorExpiryStatus? s = status.value;
    return <String, dynamic>{
      'state': s?.state.name ?? 'none',
      'eqsn': s?.eqsn ?? '',
      'startAt': s?.startAtLocal.toIso8601String(),
      'expiresAt': s?.expiresAtLocal.toIso8601String(),
      'remainMin': s?.remaining.inMinutes,
      'validityDays': _validity.inDays,
      'validityHours': _validity.inHours,
    };
  }
}
