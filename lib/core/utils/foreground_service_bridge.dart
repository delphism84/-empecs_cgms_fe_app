import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// 야간/화면OFF 중 BLE 수신이 끊기는 문제(Doze·배터리절약) 완화용.
/// Foreground Service(연결기기 타입) + 부분 WAKE_LOCK + 배터리최적화 예외로
/// 앱 프로세스를 살려 BLE 연결·재연결 타이머가 계속 돌게 한다.
class CgmsForegroundService {
  CgmsForegroundService._();

  static bool _inited = false;
  static bool get _android => !kIsWeb && Platform.isAndroid;

  static void init() {
    if (_inited || !_android) return;
    // UI ↔ 백그라운드 TaskHandler 통신 포트 초기화(방안 A 준비).
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cgms_monitoring',
        channelName: 'Glucose Monitoring',
        channelDescription: 'Keeps the CGM sensor connected in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 별도 태스크 없이 프로세스 유지만. 웨이크락 허용으로 Doze 중 타이머/콜백 유지.
        eventAction: ForegroundTaskEventAction.nothing(),
        // 자동 재시작(부팅/패키지교체)은 BT 런타임 권한 체크를 우회해
        // connectedDevice FGS를 무권한 상태로 띄우다 SecurityException 크래시를 유발한다.
        // → 반드시 false. 서비스는 권한 게이트를 거치는 start()·BLE 연결 시점에만 시작한다.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _inited = true;
  }

  /// 알림/배터리 권한 확보 후 서비스 시작. (이미 실행 중이면 무시)
  static Future<void> start({
    String title = '혈당 모니터링',
    String text = '백그라운드에서 센서 연결을 유지합니다.',
  }) async {
    if (!_android) return;
    // connectedDevice FGS는 BLUETOOTH_CONNECT 런타임 권한이 있어야 시작 가능.
    // 미허용 상태에서 시작하면 네이티브 SecurityException으로 앱이 죽으므로, 허용됐을 때만 시작.
    // (콜드 스타트 시엔 skip → 이후 BLE 연결/권한 허용 시점에 다시 호출되어 시작됨)
    try {
      final PermissionStatus bt = await Permission.bluetoothConnect.status;
      if (!bt.isGranted) return;
    } catch (_) {
      return;
    }
    try {
      init();
      final NotificationPermission np = await FlutterForegroundTask.checkNotificationPermission();
      if (np != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      // ⚠️ 순서 중요: Android 12+는 "백그라운드에서 FGS 시작"을 금지한다.
      // requestIgnoreBatteryOptimization()은 설정창을 띄워 앱을 백그라운드로 보내므로,
      // 반드시 서비스를 '먼저'(포그라운드 상태에서) 시작하고 배터리 요청은 그 뒤에 한다.
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          serviceId: 4101,
          notificationTitle: title,
          notificationText: text,
          // NOTE: 방안 A(백그라운드 isolate에서 BLE)는 v8에서 콜백 isolate가 기동되지 않아 보류.
          // 현재는 notification-only FGS로 프로세스만 유지(Phase 1, 검증됨).
        );
      }
      // 서비스가 뜬 뒤 배터리 최적화 예외 요청(삼성 등 강제종료/Doze 완화). 이미 예외면 no-op.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {
      // 서비스 시작 실패는 앱 동작에 영향 없도록 무시(로그 파일은 CrashLogger가 남김)
    }
  }

  static Future<void> stop() async {
    if (!_android) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
