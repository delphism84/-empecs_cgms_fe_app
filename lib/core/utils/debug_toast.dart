import 'dart:async';
import 'package:helpcare/core/utils/warmup_state.dart';

class DebugToastBus {
  DebugToastBus._internal();
  static final DebugToastBus _instance = DebugToastBus._internal();
  factory DebugToastBus() => _instance;

  final StreamController<String> _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void show(String message) {
    unawaited(_showInternal(message));
  }

  Future<void> _showInternal(String message) async {
    final String msg = message.trim();
    if (msg.isEmpty) return;
    if (await WarmupState.isActive() && !_isAllowedDuringWarmup(msg)) {
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


