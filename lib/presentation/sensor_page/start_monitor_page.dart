import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Save & Sync 후 진입. BLE 스캔 → QR MAC과 동일한 주소의 기기 1대만 접속 (SN 비교 없음)
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
    return raw.replaceAll(RegExp(r'[^0-9A-F]'), '');
  }

  void _startFeedbackLoop() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted || _cancelled) {
        t.cancel();
        return;
      }
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
    final String expectedSerial = (widget.targetSerial ?? '').trim();

    if (expectedMac.isEmpty) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _allFailed = true;
      });
      _showFailureDialog(
        title: 'start_monitor_fail_title'.tr(),
        message: 'start_monitor_fail_no_mac'.tr(),
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
          name: d.name.isEmpty ? 'common_device'.tr() : d.name,
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
        title: 'start_monitor_fail_title'.tr(),
        message: 'start_monitor_fail_no_ble'.tr(),
      );
      return;
    }

    DiscoveredDevice? match;
    for (final d in devices) {
      if (_normalizeMac(d.id) == expectedMac) {
        match = d;
        break;
      }
    }

    if (match == null) {
      if (!mounted) return;
      setState(() {
        for (var j = 0; j < _statuses.length; j++) {
          _statuses[j] = _DeviceStatus(
            id: _statuses[j].id,
            name: _statuses[j].name,
            rssi: _statuses[j].rssi,
            state: _DeviceState.skipped,
          );
        }
        _allFailed = true;
      });
      _showFailureDialog(
        title: 'start_monitor_fail_title'.tr(),
        message: 'start_monitor_fail_no_match'.tr(),
      );
      return;
    }

    final DiscoveredDevice matched = match;

    await ble.ensurePermissions();
    if (!mounted || _cancelled) return;

    setState(() {
      _currentIndex = 1;
      _totalCount = devices.length;
      for (var j = 0; j < _statuses.length; j++) {
        final id = _statuses[j].id;
        if (id == matched.id) {
          _statuses[j] = _DeviceStatus(
            id: id,
            name: _statuses[j].name,
            rssi: _statuses[j].rssi,
            state: _DeviceState.connecting,
          );
        } else {
          _statuses[j] = _DeviceStatus(
            id: id,
            name: _statuses[j].name,
            rssi: _statuses[j].rssi,
            state: _DeviceState.skipped,
          );
        }
      }
      _connecting = true;
    });

    bool connected = false;
    try {
      connected = await ble.connectToDeviceAndWaitReady(matched.id);
    } catch (_) {
      connected = false;
    }

    if (!mounted) return;

    if (!connected) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cgms.last_mac');
      } catch (_) {}
      setState(() {
        for (var j = 0; j < _statuses.length; j++) {
          if (_statuses[j].id == matched.id) {
            _statuses[j] = _DeviceStatus(
              id: _statuses[j].id,
              name: _statuses[j].name,
              rssi: _statuses[j].rssi,
              state: _DeviceState.skipped,
            );
            break;
          }
        }
        _connecting = false;
        _allFailed = true;
      });
      _showFailureDialog(
        title: 'start_monitor_fail_title'.tr(),
        message: 'start_monitor_fail_connect'.tr(),
      );
      return;
    }

    unawaited(BleLogService().add('QR', 'pair ok mac=$expectedMac id=${matched.id}'));

    if (mounted) {
      setState(() {
        for (var j = 0; j < _statuses.length; j++) {
          if (_statuses[j].id == matched.id) {
            _statuses[j] = _DeviceStatus(
              id: matched.id,
              name: _statuses[j].name,
              rssi: _statuses[j].rssi,
              state: _DeviceState.matched,
              sn: expectedSerial.isNotEmpty ? expectedSerial : null,
            );
            break;
          }
        }
        _connecting = false;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cgms.last_mac', matched.id);
      await prefs.setString('cgms.last_name', matched.name.isEmpty ? 'CGMS' : matched.name);
    } catch (_) {}
    try {
      final st = await SettingsStorage.load();
      if (expectedSerial.isNotEmpty) {
        st['eqsn'] = expectedSerial;
        SettingsService.stripStaleSensorStart(st);
        await SettingsStorage.save(st);
      }
    } catch (_) {}

    _feedbackTimer?.cancel();
    _cancelled = true;

    if (!mounted) return;
    await BleService().startWarmupAndNavigate();
  }

  void _showFailureDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common_ok'.tr()),
          ),
        ],
      ),
    );
  }

  void _onCancel() {
    setState(() => _cancelled = true);
    _feedbackTimer?.cancel();
    try {
      BleService().disconnect();
    } catch (_) {}
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    try {
      BleService().disconnect();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final bottomHeight = sz.height * 0.30;

    return Scaffold(
      appBar: AppBar(title: Text('start_monitor_appbar'.tr())),
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
                          ? 'start_monitor_connecting'.tr()
                          : _allFailed
                              ? 'start_monitor_search_complete'.tr()
                              : _scanning
                                  ? 'start_monitor_searching'.tr()
                                  : 'start_monitor_devices_label'.tr(),
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
                  _scanning
                      ? 'start_monitor_searching_ble'.tr()
                      : 'start_monitor_devices_header'.tr(namedArgs: {
                          'cur': '$_currentIndex',
                          'total': '$_totalCount',
                        }),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _statuses.isEmpty && !_scanning
                      ? Center(child: Text('start_monitor_no_devices'.tr()))
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
                                      'start_monitor_device_row'.tr(namedArgs: {'id': s.id}),
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  Text(
                                    s.state == _DeviceState.matched
                                        ? (s.sn ?? 'OK')
                                        : 'start_monitor_skip'.tr(),
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
                  child: Text('common_cancel'.tr()),
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
