import 'dart:async';
import 'dart:math' as math;

import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// Dev-only BLE receive emulator gate.
/// - When enabled, injects one glucose point every 10 seconds through the same
///   queue path as real BLE notify (`BleService.simulateNotify`).
class EmulBleRecvService {
  EmulBleRecvService._internal();
  static final EmulBleRecvService _instance = EmulBleRecvService._internal();
  factory EmulBleRecvService() => _instance;

  Timer? _timer;
  bool _enabled = false;
  double _last = 112;

  Future<void> start() async {
    await syncFromSettings();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final s = await SettingsStorage.load();
      s['emulBleRecvEnabled'] = enabled;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> syncFromSettings() async {
    try {
      final s = await SettingsStorage.load();
      _enabled = s['emulBleRecvEnabled'] == true;
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> _tick() async {
    if (!_enabled) return;
    final int step = 1 + math.Random().nextInt(4); // 1..4
    final int dir = math.Random().nextBool() ? 1 : -1;
    _last = (_last + dir * step).clamp(60.0, 220.0);
    BleService().simulateNotify(_last);
  }
}

