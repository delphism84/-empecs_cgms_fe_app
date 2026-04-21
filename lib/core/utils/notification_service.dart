import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> _selectStream = StreamController.broadcast();
  bool _enabled = true;

  Stream<String?> get onSelectNotification => _selectStream.stream;
  bool get isEnabled => _enabled;
  void setEnabled(bool v) { _enabled = v; }

  Future<void> initialize() async {
    final AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        _selectStream.add(resp.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Android 13+ 권한 요청
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _ensureDefaultChannel();

    // load persisted on/off from local storage (fallback true)
    try {
      final s = await SettingsStorage.load();
      final dynamic v = s['notificationsEnabled'];
      if (v is bool) {
        _enabled = v;
      } else {
        _enabled = true;
      }
    } catch (_) {
      _enabled = true;
    }
  }

  Future<void> _ensureDefaultChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Android는 (O+) 채널 단위로 사운드/진동 설정이 고정되므로,
    // 요구사항(사운드만/진동만/둘다)을 충족하기 위해 채널을 분리한다.
    // 채널 ID는 한 번 생성되면 소리/오디오 속성을 바꿀 수 없다(Android O+).
    // 과거 채널이 무음·notification 스트림으로 고정된 기기에서 알람음이 나지 않는 문제를 피하려고
    // ID를 갱신하고 알람 스트림(alarm usage)으로 새로 등록한다.
    final List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'cgms_glucose_alert_both',
        'CGMS Alerts (Sound+Vibration)',
        description: 'Glucose alerts: sound + vibration',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_alert_sound',
        'CGMS Alerts (Sound Only)',
        description: 'Glucose alerts: sound only',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_alert_vibrate',
        'CGMS Alerts (Vibration Only)',
        description: 'Glucose alerts: vibration only',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_alert_silent',
        'CGMS Alerts (Silent)',
        description: 'Glucose alerts: silent',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
      // "방해 금지 모드 무시"는 사용자/OS 설정이 필요할 수 있음.
      // (현재 사용 중인 flutter_local_notifications 버전에서는 bypassDnd 플래그가 노출되지 않음)
      // 따라서 앱에서는 "critical 채널"로 라우팅만 하고, 실제 DND 예외 허용은 OS 설정에 의존한다.
      AndroidNotificationChannel(
        'cgms_glucose_critical_both',
        'CGMS Critical (Sound+Vibration)',
        description: 'Very low critical: sound + vibration (bypass DND if allowed)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_critical_sound',
        'CGMS Critical (Sound Only)',
        description: 'Very low critical: sound only (bypass DND if allowed)',
        importance: Importance.max,
        playSound: true,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_critical_vibrate',
        'CGMS Critical (Vibration Only)',
        description: 'Very low critical: vibration only (bypass DND if allowed)',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
      AndroidNotificationChannel(
        'cgms_glucose_critical_silent',
        'CGMS Critical (Silent)',
        description: 'Very low critical: silent (bypass DND if allowed)',
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
      // AR_01_08: Lock screen banner / ongoing glucose
      AndroidNotificationChannel(
        'cgms_lockscreen',
        'CGMS Lock Screen',
        description: 'Lock screen banner notification for latest glucose value',
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final c in channels) {
      await android?.createNotificationChannel(c);
    }
  }

  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool critical = false,
    bool sound = true,
    bool vibrate = true,
  }) async {
    if (!_enabled) return;
    final String p = (payload ?? '').trim();
    if (p.startsWith('alarm:') && await WarmupState.isActive()) {
      return;
    }
    if (p.startsWith('alarm:')) {
      // AR_01_01: 알람 전체 무음 — 실제 노티에도 반영(엔진과 동일 정책)
      try {
        final st = await SettingsStorage.load();
        if (st['alarmsMuteAll'] == true) {
          sound = false;
          vibrate = false;
        }
      } catch (_) {}
      // Ensure channel/method changes (sound/vibrate) apply immediately
      // instead of inheriting previous post state for the same notification id.
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    final String channelId = critical
        ? (sound && vibrate ? 'cgms_glucose_critical_both' : sound ? 'cgms_glucose_critical_sound' : vibrate ? 'cgms_glucose_critical_vibrate' : 'cgms_glucose_critical_silent')
        : (sound && vibrate ? 'cgms_glucose_alert_both' : sound ? 'cgms_glucose_alert_sound' : vibrate ? 'cgms_glucose_alert_vibrate' : 'cgms_glucose_alert_silent');
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      critical ? 'CGMS Critical' : 'CGMS Alerts',
      channelDescription: critical ? 'Very low glucose critical alerts' : 'Glucose threshold alerts and system notices',
      importance: critical ? Importance.max : Importance.high,
      priority: critical ? Priority.max : Priority.high,
      category: (critical || sound) ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      fullScreenIntent: critical,
      playSound: sound,
      enableVibration: vibrate,
      audioAttributesUsage: sound ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );
    // iOS(flutter_local_notifications): presentSound==true 이고 sound 미지정(null)이면 시스템 기본 알림음.
    // 예전에 쓰던 sound: '' 는 잘못된 커스텀 파일명으로 처리되어 무음이 될 수 있음.
    // 배너/목록은 DarwinInitializationSettings 기본값(defaultPresentBanner/List=true)에 맡김.
    final DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sound,
      sound: null,
      interruptionLevel: sound ? InterruptionLevel.active : null,
    );
    final NotificationDetails details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(id, title, body, details, payload: payload);

    // bot/debug verification: persist last alert snapshot
    try {
      final s = await SettingsStorage.load();
      s['lastAlert'] = {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'critical': critical,
        'time': DateTime.now().toUtc().toIso8601String(),
      };
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  /// AR_01_08: 잠금화면에 항상 보이는 배너/상태 알림(최신 혈당 + 추세 화살표)
  /// - 채널: cgms_lockscreen (무음/무진동, importance max)
  /// - 잠금화면 노출: public
  /// - 업데이트 목적: ongoing + onlyAlertOnce
  Future<void> showLockScreenGlucose({
    required double value,
    String trend = '',
    String unit = 'mg/dL',
    DateTime? measuredAt,
  }) async {
    if (!_enabled) return;
    if (await WarmupState.isActive()) return;
    // AR_01_08: lock screen banner per-feature toggle
    try {
      final s = await SettingsStorage.load();
      if (s['ar0108Enabled'] == false) return;
    } catch (_) {}
    final bool mmol = unit.toLowerCase().contains('mmol');
    final String v = value.isNaN ? '—' : (mmol ? value.toStringAsFixed(1) : value.toStringAsFixed(0));
    final String arrow = trend.trim().isEmpty ? '→' : trend.trim();
    final DateTime at = (measuredAt ?? DateTime.now()).toLocal();
    final String timeStr =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    // AR_01_08: 잠금화면 한 줄에 변화 방향 + 최신 혈당 (Last Reading 형태 문구 사용 안 함)
    final String title = '$arrow $v $unit';
    final String body = timeStr;
    const int id = 2001;
    const String payload = 'lockscreen:glucose';

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      'cgms_lockscreen',
      'CGMS Lock Screen',
      channelDescription: 'Lock screen banner notification for latest glucose value',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
      ongoing: true,
      onlyAlertOnce: false,
      showWhen: true,
      when: at.millisecondsSinceEpoch,
    );
    final DarwinNotificationDetails ios = const DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    final NotificationDetails details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(id, title, body, details, payload: payload);

    // bot/debug verification: persist last lockscreen snapshot
    try {
      final s = await SettingsStorage.load();
      s['lastLockScreenAt'] = DateTime.now().toUtc().toIso8601String();
      s['lastLockScreenOk'] = true;
      s['lastLockScreenValue'] = value;
      s['lastLockScreenTrend'] = trend;
      await SettingsStorage.save(s);
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // background tap handling is minimal; navigation is handled after resume
}


