import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:helpcare/core/utils/sensor_warmup_service.dart';

class DebugToastBus {
  DebugToastBus._internal();
  static final DebugToastBus _instance = DebugToastBus._internal();
  factory DebugToastBus() => _instance;

  final StreamController<String> _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void show(String message) {
    // 이 버스의 유일한 구독자는 대시보드의 디버그 SnackBar 다. 릴리스에서는 내보내지 않는다.
    // (고객 빌드에 `CGMS: ble v=91 trid=4671` 같은 내부 진단 문구가 그대로 노출됐다 —
    //  req260716 리포트 첨부 스크린샷에서 확인된 사례)
    if (kReleaseMode) return;
    unawaited(_showInternal(message));
  }

  Future<void> _showInternal(String message) async {
    final String msg = message.trim();
    if (msg.isEmpty) return;
    if (SensorWarmupService.shouldSuppressAlarmPipeline &&
        !_isAllowedDuringWarmup(msg)) {
      return;
    }
    _controller.add(msg);
  }

  bool _isAllowedDuringWarmup(String msg) {
    final String m = msg.toUpperCase();
    // 웜업 중에는 BLE 상태 변화 메시지만 허용.
    return m.startsWith('BLE: CONNECTING') ||
        m.startsWith('BLE: CONNECTED') ||
        m.startsWith('BLE: DISCONNECT') ||
        m.startsWith('BLE: SCANNING');
  }
}


