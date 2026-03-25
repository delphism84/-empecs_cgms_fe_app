import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Save & Sync 후 진입. BLE 검색 → n/total 순차 접속 → MAC 확인 → 성공 시 Warm-up
class StartMonitorPage extends StatefulWidget {
  const StartMonitorPage({super.key, this.targetSerial, this.targetMac});

  final String? targetSerial;
  final String? targetMac;

  @override
  State<StartMonitorPage> createState() => _StartMonitorPageState();
}

class _StartMonitorPageState extends State<StartMonitorPage> {
  final List<_DeviceStatus> _statuses = [];
  bool _scanning = true;
  int _currentIndex = 0;
  int _totalCount = 0;
  bool _connecting = false;
  bool _allFailed = false;
  bool _cancelled = false;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _runAutoConnect();
    _startFeedbackLoop();
  }

  String _normalizeMac(String? s) {
    final raw = (s ?? '').trim().toUpperCase();
    // Compare MACs regardless of separators (':', '-', spaces)
    return raw.replaceAll(RegExp(r'[^0-9A-F]'), '');
  }

  void _startFeedbackLoop() {
    // Start monitor UX: periodic vibration + "ding-ding" system beeps.
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted || _cancelled) {
        t.cancel();
        return;
      }
      // "띵~딩": two quick taps
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _cancelled) return;
        try {
          HapticFeedback.mediumImpact();
        } catch (_) {}
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      });
    });
  }

  Future<void> _runAutoConnect() async {
    final ble = BleService();
    final String expectedMac = _normalizeMac(widget.targetMac);
    if (expectedMac.isEmpty) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _allFailed = true;
      });
      _showFailureDialog(
        title: 'BLE Connection Failed',
        message: 'QR MAC information is missing.\n\nPlease scan the QR code again.',
      );
      return;
    }

    final List<DiscoveredDevice> devices = [];

    await for (final d in ble.scanCgms(timeout: const Duration(seconds: 12))) {
      if (!mounted || _cancelled) return;
      devices.add(d);
      setState(() {
        _statuses.add(_DeviceStatus(
          id: d.id,
          name: d.name.isEmpty ? 'Device' : d.name,
          rssi: d.rssi,
          state: _DeviceState.pending,
        ));
        _totalCount = devices.length;
      });
    }

    if (!mounted) return;
    setState(() => _scanning = false);
    if (devices.isEmpty) {
      setState(() => _allFailed = true);
      _showFailureDialog(
        title: 'BLE Connection Failed',
        message: 'No BLE devices were found.\n\nPlease ensure Bluetooth is on and the sensor is nearby, then try again.',
      );
      return;
    }

    await ble.ensurePermissions();

    for (int i = 0; i < devices.length; i++) {
      if (!mounted || _cancelled) return;
      final d = devices[i];

      setState(() {
        _currentIndex = i + 1;
        _connecting = true;
        for (var j = 0; j < _statuses.length; j++) {
          if (_statuses[j].id == d.id) {
            _statuses[j] = _DeviceStatus(
              id: d.id,
              name: _statuses[j].name,
              rssi: _statuses[j].rssi,
              state: _DeviceState.connecting,
            );
            break;
          }
        }
      });

      try {
        await ble.connectToDevice(d.id);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          for (var j = 0; j < _statuses.length; j++) {
            if (_statuses[j].id == d.id) {
              _statuses[j] = _DeviceStatus(
                id: d.id,
                name: _statuses[j].name,
                rssi: _statuses[j].rssi,
                state: _DeviceState.skipped,
              );
              break;
            }
          }
          _connecting = false;
        });
        continue;
      }

      final String deviceMacNorm = _normalizeMac(d.id);
      final bool macMatches =
          expectedMac.isNotEmpty && deviceMacNorm.isNotEmpty && deviceMacNorm == expectedMac;

      if (macMatches) {
        if (mounted) {
          setState(() {
            for (var j = 0; j < _statuses.length; j++) {
              if (_statuses[j].id == d.id) {
                _statuses[j] = _DeviceStatus(
                  id: d.id,
                  name: _statuses[j].name,
                  rssi: _statuses[j].rssi,
                  state: _DeviceState.matched,
                  sn: widget.targetSerial?.trim(),
                );
                break;
              }
            }
            _connecting = false;
          });
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cgms.last_mac', d.id);
          await prefs.setString('cgms.last_name', d.name.isEmpty ? 'CGMS' : d.name);
        } catch (_) {}
        // MAC 매칭 성공 시 센서 식별자는 QR의 SN 정보를 우선 사용
        try {
          final st = await SettingsStorage.load();
          final String qrSn = (widget.targetSerial ?? '').trim();
          if (qrSn.isNotEmpty) {
            st['eqsn'] = qrSn;
            await SettingsStorage.save(st);
          }
        } catch (_) {}

        // 접속 성공 시 진동/사운드 피드백 즉시 중지
        _feedbackTimer?.cancel();
        _cancelled = true;

        if (!mounted) return;
        await BleService().startWarmupAndNavigate();
        return;
      }

      // MAC mismatch → disconnect and continue
      if (mounted) {
        setState(() {
          for (var j = 0; j < _statuses.length; j++) {
            if (_statuses[j].id == d.id) {
              _statuses[j] = _DeviceStatus(
                id: d.id,
                name: _statuses[j].name,
                rssi: _statuses[j].rssi,
                state: _DeviceState.skipped,
              );
              break;
            }
          }
          _connecting = false;
        });
      }

      try { await ble.disconnect(); } catch (_) {}
    }

    // BLE Connection Failed는 검출된 기기가 없을 때만 표시 (통신 성공 시 오탐 방지)
    if (mounted) {
      setState(() {
        _connecting = false;
        _allFailed = true;
      });
      // devices.isEmpty인 경우에만 다이얼로그 표시 (이미 위에서 처리됨)
      // MAC 불일치 등으로 모든 기기 시도 후 실패한 경우에는 다이얼로그 생략
    }
  }

  void _showFailureDialog({
    String title = 'BLE Connection Failed',
    String message =
        'No sensor matching the QR MAC was found.\n\nPlease ensure Bluetooth is on and the sensor is nearby, then try again.',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onCancel() {
    setState(() => _cancelled = true);
    _feedbackTimer?.cancel();
    // Stop any ongoing BLE connection attempt.
    try { BleService().disconnect(); } catch (_) {}
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    try { BleService().disconnect(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final bottomHeight = sz.height * 0.30;

    return Scaffold(
      appBar: AppBar(title: const Text('Start the Monitor')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconBox(icon: Icons.bluetooth),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward, color: Colors.grey[600]),
                      ),
                      _IconBox(icon: Icons.sync),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward, color: Colors.grey[600]),
                      ),
                      _IconBox(icon: Icons.phone_android),
                    ],
                  ),
                  if (_totalCount > 0 || _scanning) ...[
                    const SizedBox(height: 24),
                    Text(
                      '$_currentIndex / $_totalCount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      _connecting
                          ? 'Connecting & MAC check...'
                          : _allFailed
                              ? 'Search complete'
                              : _scanning
                                  ? 'Searching...'
                                  : 'Devices',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            height: bottomHeight,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _scanning ? 'Searching BLE devices...' : 'Devices ($_currentIndex / $_totalCount)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _statuses.isEmpty && !_scanning
                      ? const Center(child: Text('No devices found'))
                      : ListView.builder(
                          itemCount: _statuses.length,
                          itemBuilder: (_, i) {
                            final s = _statuses[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    s.state == _DeviceState.matched
                                        ? Icons.check_circle
                                        : s.state == _DeviceState.skipped
                                            ? Icons.block
                                            : s.state == _DeviceState.connecting
                                                ? Icons.bluetooth_searching
                                                : Icons.bluetooth,
                                    size: 20,
                                    color: s.state == _DeviceState.matched
                                        ? Colors.green
                                        : s.state == _DeviceState.skipped
                                            ? Colors.orange
                                            : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'DEVICE [${s.id}]',
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  Text(
                                    s.state == _DeviceState.matched
                                        ? (s.sn ?? 'SN: ${s.name}')
                                        : 'SKIP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: s.state == _DeviceState.matched ? Colors.green[700] : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }
}

enum _DeviceState { pending, connecting, matched, skipped }

class _DeviceStatus {
  _DeviceStatus({
    required this.id,
    required this.name,
    required this.rssi,
    required this.state,
    this.sn,
  });
  final String id;
  final String name;
  final int rssi;
  final _DeviceState state;
  final String? sn;
}
