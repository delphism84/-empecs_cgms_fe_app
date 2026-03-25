import 'dart:async';

import 'package:flutter/material.dart';
// ignore_for_file: unused_element
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/debug_badge.dart';
import 'package:helpcare/widgets/gradient_icon.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/qr_sn_parser.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/debug_toast.dart';
import 'package:helpcare/presentation/sensor_page/before_qr_scan_page.dart';
import 'package:helpcare/presentation/sensor_page/start_monitor_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/widgets/app_fields.dart';

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  @override
  void initState() {
    super.initState();
    _markViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRendered());
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0201ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _markRendered() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0201RenderedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _readUsage() async {
    final st = await SettingsStorage.load();
    final String raw = (st['sensorStartAt'] as String? ?? '').trim();
    final DateTime now = DateTime.now();
    DateTime startAt = now.subtract(const Duration(days: 3));
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) startAt = dt.toLocal();
    } catch (_) {}
    const Duration valid = Duration(days: 14);
    final Duration used = now.difference(startAt);
    final Duration remain = valid - used;
    final int remainSec = remain.inSeconds < 0 ? 0 : remain.inSeconds;
    final double pct = (used.inSeconds / valid.inSeconds).clamp(0, 1).toDouble();
    return {
      'startAt': startAt,
      'valid': valid,
      'used': used,
      'remainSec': remainSec,
      'pct': pct,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sensor (SC_02_01)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _readUsage(),
                builder: (context, snap) {
                  final data = snap.data;
                  final DateTime? startAt = data?['startAt'] as DateTime?;
                  final Duration? valid = data?['valid'] as Duration?;
                  final int remainSec = (data?['remainSec'] as int?) ?? 0;
                  final double pct = (data?['pct'] as double?) ?? 0.0;
                  final int remainDays = remainSec ~/ (24 * 3600);
                  final int remainHours = (remainSec % (24 * 3600)) ~/ 3600;
                  final bool warn = remainSec <= (72 * 3600); // 72h
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorConstant.indigo51, width: 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Usage period', style: TextStyle(fontWeight: FontWeight.w700))),
                          if (warn) Icon(Icons.warning_amber, color: Colors.amber.shade700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Remaining: ${remainDays}d ${remainHours}h  (valid ${valid?.inDays ?? 14}d)',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start: ${startAt == null ? '—' : '${startAt.year}/${startAt.month.toString().padLeft(2, '0')}/${startAt.day.toString().padLeft(2, '0')} ${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ]),
                  );
                },
              ),
              // New group like notification page
              const Text('New', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _notifItem(context, isDark, Icons.bluetooth_connected, 'Status', 'Battery, signal, warm-up', const SensorStatusPage(), 'SC_03_01'),
              _notifItem(context, isDark, Icons.bluetooth_searching, 'Scan & Connect', 'BLE scan/connect · battery/usage', const SensorBleScanPage(), 'SC_01_01'),
              _notifItem(context, isDark, Icons.confirmation_number, 'Serial Number', 'Current sensor SN', const SensorSerialPage(), 'SC_04_01'),
              _notifItem(context, isDark, Icons.schedule, 'Start Time', 'YYYY/MM/DD HH:mm', const SensorStartTimePage(), 'SC_05_01'),
              // removed old reconnect items; replaced with QR & Connect under Scan & Connect
              _notifItemRoute(context, isDark, Icons.share, 'Share Data', 'Share with caregiver', '/sc/07/01', 'SC_07_01'),
              const SizedBox(height: 16),
              _notifItem(
                context,
                isDark,
                Icons.delete_outline,
                'How to remove',
                'Sensor removal guide',
                const SensorRemovePageWrapper(),
                'SC_08_01',
              ),
            ]),
          ),
        ),
      ),
    );
  }
}


class SensorStatusPage extends StatefulWidget {
  const SensorStatusPage({super.key});
  @override
  State<SensorStatusPage> createState() => _SensorStatusPageState();
}

class _SensorStatusPageState extends State<SensorStatusPage> {
  bool enable = true;
  String deviceName = 'CGMS';
  String deviceId = '';
  int battery = 78;
  int rssi = -62;
  bool autoReconnect = true;
  int retryMin = 3;
  // usage period
  DateTime? startAt;
  Duration valid = const Duration(days: 14);

  @override
  void initState() {
    super.initState();
    _markViewed();
    _loadUsage();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0301ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _loadUsage() async {
    try {
      final st = await SettingsStorage.load();
      final String raw = (st['sensorStartAt'] as String? ?? '').trim();
      final dt = raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
      if (!mounted) return;
      setState(() {
        startAt = dt;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('SC_03_01 · Connection Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group(context, title: 'Basic', children: [
            ValueListenableBuilder<BleConnPhase>(
              valueListenable: BleService().phase,
              builder: (context, ph, _) {
                final bool on = ph != BleConnPhase.off;
                return AppSwitchRow(
                  label: 'Enable connection',
                  value: on,
                  onChanged: (v) async {
                    if (v && ph == BleConnPhase.off) {
                      await BleService().tryAutoReconnect();
                    } else if (!v && ph != BleConnPhase.off) {
                      await BleService().disconnect();
                    }
                  },
                );
              },
            ),
            ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Device name'), subtitle: Text(deviceName)),
            if (deviceId.isNotEmpty) ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Device ID'), subtitle: Text(deviceId)),
            ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Battery (%)'), trailing: Text('$battery%')),
            ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Signal strength (dBm)'), trailing: Text('$rssi')),
            ValueListenableBuilder<int>(
              valueListenable: BleService().rxCount,
              builder: (context, n, _) => ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Packets'), trailing: Text('$n')),
            ),
          ]),
          _group(context, title: 'Scan & Connect', children: [
            const Text(
              'Scan & Connect is available in SC_01_01 only.\n'
              'SC_03_01 (Status screen) does not perform scan/connect.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SensorBleScanPage()));
                },
                child: const Text('Open SC_01_01 · Scan & Connect'),
              ),
            ),
          ]),
          ValueListenableBuilder<BleConnPhase>(
            valueListenable: BleService().phase,
            builder: (context, ph, _) {
              if (ph == BleConnPhase.off) return const SizedBox.shrink();
              return _group(context, title: 'Usage period', children: [
                ListTile(title: const Text('Connected device'), subtitle: Text(deviceName)),
                Builder(builder: (context) {
                  final DateTime now = DateTime.now();
                  final DateTime baseStart = startAt ?? now.subtract(const Duration(days: 3));
                  final Duration used = now.difference(baseStart);
                  final Duration remain = valid - used;
                  final double pct = (used.inSeconds / valid.inSeconds).clamp(0, 1).toDouble();
                  final bool warn = remain.inHours <= 24; // 24h 남음 경고
                  String fmtStart(DateTime t) =>
                      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  final String remainLabel = remain.inSeconds <= 0
                      ? 'Expired'
                      : 'Remaining ${remain.inDays}d ${remain.inHours % 24}h';
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(value: pct, minHeight: 8, color: primary, backgroundColor: primary.withValues(alpha: 0.15)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text(remainLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (warn) Icon(Icons.warning_amber, color: Colors.amber.shade700),
                    ]),
                    const SizedBox(height: 6),
                    Text('Start: ${fmtStart(baseStart)}', style: const TextStyle(color: Colors.grey)),
                  ]);
                }),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _mockRead, child: const Text('Read status'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect'))),
                ])
              ]);
            },
          ),
          _group(context, title: 'Reconnect', children: [
            AppSwitchRow(label: 'Auto reconnect', value: autoReconnect, onChanged: (v) => setState(() => autoReconnect = v)),
            AppCombo<int>(
              label: 'Retry interval (min)',
              value: retryMin,
              items: const [1, 3, 5, 10],
              labelFor: (e) => '$e',
              onChanged: (v) => setState(() => retryMin = v),
            ),
          ]),
          _group(context, title: 'Advanced', children: [
            ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('Log level'), trailing: DropdownButton<String>(value: 'Info', items: const ['Error', 'Warn', 'Info', 'Debug'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
            ListTile(dense: true, leading: Icon(Icons.circle, color: primary, size: 12), title: const Text('BLE MTU'), trailing: DropdownButton<int>(value: 185, items: const [23, 90, 185].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(), onChanged: (_) {})),
          ]),
          const SizedBox(height: 12),
          CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Future<void> _mockRead() async {
    setState(() {
      battery = 78;
      rssi = -60;
    });
  }

  Future<void> _disconnect() async {
    try { await BleService().disconnect(); } catch (_) {}
      if (!mounted) return;
    setState(() { deviceId = ''; });
  }
}

class SensorSerialPage extends StatefulWidget {
  const SensorSerialPage({super.key});
  @override
  State<SensorSerialPage> createState() => _SensorSerialPageState();
}

class _SensorSerialPageState extends State<SensorSerialPage> {
  final TextEditingController _snCtrl = TextEditingController();
  String _snModel = '';
  String _snYear = '';
  String _snSample = '';
  String _snSerial = '';
  String _lastScannedQrFullSn = '';
  String _lastScannedQrAt = '';
  bool _lastScannedQrRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadSn();
    _loadLastScannedQr();
    _markViewed();
  }

  Future<void> _loadLastScannedQr() async {
    try {
      final s = await SettingsStorage.load();
      if (!mounted) return;
      setState(() {
        _lastScannedQrFullSn = (s['lastScannedQrFullSn'] as String? ?? '').trim();
        _lastScannedQrAt = (s['lastScannedQrAt'] as String? ?? '').trim();
        _lastScannedQrRegistered = s['lastScannedQrRegistered'] == true;
      });
    } catch (_) {}
  }

  Future<void> _saveLastScannedQrFromRaw(String raw) async {
    try {
      final s = await SettingsStorage.load();
      final fullSn = raw.trim().toUpperCase();
      final parsed = QrSnParser.parse(raw);
      final serial = parsed?['serial'] ?? '';
      final list = (s['registeredDevices'] as List? ?? []);
      final registered = list.any((e) {
        final r = e as Map<String, dynamic>;
        return (r['fullSn'] as String? ?? '').trim().toUpperCase() == fullSn ||
            (r['sn'] as String? ?? '').trim() == serial;
      });
      s['lastScannedQrRaw'] = raw.trim();
      s['lastScannedQrFullSn'] = fullSn;
      s['lastScannedQrSerial'] = serial;
      s['lastScannedQrAt'] = DateTime.now().toUtc().toIso8601String();
      s['lastScannedQrRegistered'] = registered;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0401ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _loadSn() async {
    try {
      final s = await SettingsStorage.load();
      final String eqsn = (s['eqsn'] as String? ?? '');
      _snCtrl.text = eqsn;
      _parseSn(eqsn);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_04_01 · Serial Number')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // top QR image
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Image.asset('assets/images/qrsn.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 80, color: Colors.black38)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _snCtrl,
            decoration: const InputDecoration(labelText: 'SN (e.g. C21ZS00033)', border: OutlineInputBorder()),
            onChanged: (v) => setState(() { _parseSn(v); }),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _kv('Model', _snModel.isEmpty ? '-' : _snModel)),
            const SizedBox(width: 8),
            Expanded(child: _kv('Year', _snYear.isEmpty ? '-' : _snYear)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _kv(
                'Serial',
                _snCtrl.text.trim().isEmpty
                    ? '-'
                    : 'SN: ${_snCtrl.text.trim().toUpperCase().length >= 10 ? _snCtrl.text.trim().toUpperCase() : (_snSerial.isNotEmpty ? _snSerial : _snCtrl.text.trim().toUpperCase())}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _kv('Sample', _snSample.isEmpty ? '-' : _snSample)),
          ]),
          const SizedBox(height: 12),
          CustomButton(text: 'Save & Sync', variant: ButtonVariant.FillLoginGreen, onTap: _saveAndSync),
          const SizedBox(height: 8),
          // removed: Start Data button
          CustomButton(
            text: 'QR SCAN',
            variant: ButtonVariant.OutlinePrimaryWhite,
            fontStyle: ButtonFontStyle.GilroyMedium16Primary,
            onTap: () async {
              final String? sn = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const _SnQrScanPage()),
              );
              if (sn != null && sn.isNotEmpty) {
                if (!mounted) return;
                setState(() {
                  _snCtrl.text = sn;
                  _parseSn(sn);
                });
                _saveLastScannedQrFromRaw(sn);
              }
              _loadLastScannedQr();
            },
          ),
          if (_lastScannedQrFullSn.isNotEmpty || _lastScannedQrAt.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const Text('Last scanned QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              _lastScannedQrRegistered ? 'SN: $_lastScannedQrFullSn' : 'Unregistered QR SN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _lastScannedQrRegistered ? null : Theme.of(context).colorScheme.error,
              ),
            ),
            if (_lastScannedQrAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatLastScannedAt(_lastScannedQrAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatLastScannedAt(String iso) {
    try {
      final d = DateTime.tryParse(iso)?.toLocal();
      if (d != null) return d.toString().split('.').first;
    } catch (_) {}
    return iso;
  }

  void _parseSn(String sn) {
    final s = sn.trim().toUpperCase();
    String model = '';
    String year = '';
    String sample = '';
    String serial = '';
    if (s.length >= 7) {
      model = s.substring(0, 3);
      final y = s.substring(3, 4);
      final Map<String, String> ymap = {'Y': '2024', 'Z': '2025', 'A': '2026', 'B': '2027'};
      year = ymap[y] ?? y;
      sample = s.substring(4, 5);
      serial = s.substring(5);
    }
    _snModel = model; _snYear = year; _snSample = sample; _snSerial = serial;
  }

  Widget _kv(String k, String v) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorConstant.indigo50,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Future<void> _saveAndSync() async {
    final String newEqsn = _snCtrl.text.trim();
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String prevEqsn = (st['eqsn'] as String? ?? '').trim();
    if (newEqsn.isEmpty) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter SN first'))); return; }
    if (newEqsn == prevEqsn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved & syncing...')));
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StartMonitorPage(targetSerial: newEqsn)),
      );
      return;
    }
    st['eqsn'] = newEqsn; await SettingsStorage.save(st);
    try {
      // SN 변경 시 로컬 데이터 전부 초기화 (혼섞임 방지)
      await GlucoseLocalRepo().clear();
      await EventLocalRepo().clear();
    } catch (_) {}
    // 대시보드 등 실시간 값 표시를 대시(–)로 즉시 반영
    try { DataSyncBus().emitGlucoseBulk(count: 0); } catch (_) {}
    // 시작일은 항상 로컬 우선 저장, 온라인이며 서버에 기존 SN이 있으면 서버값을 우선 사용
    try {
      final ss = SettingsService();
      DateTime? startLocal;
      try {
        final Map<String, dynamic> eq = await ss.getEqBySerial(newEqsn);
        final String? stRemote = (eq['startAt'] as String?);
        if (stRemote != null && stRemote.trim().isNotEmpty) {
          startLocal = DateTime.tryParse(stRemote)?.toLocal();
        }
      } catch (_) {}
      startLocal ??= DateTime.now();
      // 로컬 캐시 즉시 반영
      try { final m = await SettingsStorage.load(); m['sensorStartAt'] = startLocal.toUtc().toIso8601String(); await SettingsStorage.save(m); } catch (_) {}
      // 서버에 기존값이 없었던 경우에만 업서트로 동기화
      try {
        await ss.upsertEqStart(serial: newEqsn, startAt: startLocal);
      } catch (_) {}
      // 대시보드 즉시 갱신 트리거
      try { DataSyncBus().emitGlucoseBulk(count: 1); } catch (_) {}
    } catch (_) {}
    try {
      final ds = DataService();
      final now = DateTime.now();
      await ds.fetchGlucose(from: now.subtract(const Duration(days: 30)), to: now, limit: 5000);
      final ev = await ds.fetchEvents(from: now.subtract(const Duration(days: 30)), to: now, limit: 1000, sync: true);
      try { DataSyncBus().emitEventBulk(count: ev.length); } catch (_) {}
    } catch (_) {}
    try { final int last = await GlucoseLocalRepo().maxTrid(eqsn: newEqsn); await BleService().requestRacpFromTrid((last + 1) & 0xFFFF); } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved & syncing...')));
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StartMonitorPage(targetSerial: newEqsn.isNotEmpty ? newEqsn : null)),
    );
  }

  Future<void> _startDataNow() async {
    final String sn = _snCtrl.text.trim();
    if (sn.isEmpty) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter SN first'))); return; }
    bool ok = false;
    try {
      final ss = SettingsService();
      ok = await ss.upsertEqStart(serial: sn, startAt: DateTime.now());
    } catch (_) {
      ok = false;
    }
    // always update local cache for offline/local mode
    try {
      final m = await SettingsStorage.load();
      m['sensorStartAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(m);
    } catch (_) {}
    // inform dashboard to refresh days-left (without requiring clear)
    try { DataSyncBus().emitGlucoseBulk(count: 1); } catch (_) {}
      if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Start date set to now' : 'Start date set to now (local)')));
  }
}

class _SnQrScanPage extends StatefulWidget {
  const _SnQrScanPage();
  @override
  State<_SnQrScanPage> createState() => _SnQrScanPageState();
}

class _SnQrScanPageState extends State<_SnQrScanPage> {
  final MobileScannerController _controller = MobileScannerController(torchEnabled: false, autoStart: true);
  bool _done = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    if (cap.barcodes.isEmpty) return;
    final String? raw = cap.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    // accept first; optionally trim spaces/newlines
    _done = true;
    _controller.stop();
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan SN')),
      body: Stack(children: [
        Positioned.fill(child: MobileScanner(controller: _controller, onDetect: _onDetect)),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class SensorStartTimePage extends StatefulWidget {
  const SensorStartTimePage({super.key});
  @override
  State<SensorStartTimePage> createState() => _SensorStartTimePageState();
}

class _SensorStartTimePageState extends State<SensorStartTimePage> {
  DateTime? _startAt;

  @override
  void initState() {
    super.initState();
    _load();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0501ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      final String raw = (st['sensorStartAt'] as String? ?? '').trim();
      final dt = raw.isEmpty ? null : DateTime.tryParse(raw);
      if (!mounted) return;
      setState(() {
        _startAt = dt?.toLocal();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_05_01 · Start Time')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group(context, title: 'Start', children: [
            ListTile(
              title: const Text('Start at'),
              subtitle: Text(_startAt == null
                  ? '—'
                  : '${_startAt!.year}/${_startAt!.month.toString().padLeft(2, '0')}/${_startAt!.day.toString().padLeft(2, '0')} '
                      '${_startAt!.hour.toString().padLeft(2, '0')}:${_startAt!.minute.toString().padLeft(2, '0')}'),
            ),
            const ListTile(
              title: Text('Note'),
              subtitle: Text('Start time is updated automatically when sensor becomes active.'),
            ),
          ]),
          _group(context, title: 'Help', children: const [
            ListTile(title: Text('Warm-up section is hidden per latest layout request.')),
          ]),
          const SizedBox(height: 12),
          CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class SensorReconnectNfcPage extends StatefulWidget {
  const SensorReconnectNfcPage({super.key});
  @override
  State<SensorReconnectNfcPage> createState() => _SensorReconnectNfcPageState();
}

class _SensorReconnectNfcPageState extends State<SensorReconnectNfcPage> {
  bool enable = true;
  bool playSound = true;
  bool vibrate = true;
  String guide = 'Place the sensor on the back of the phone';

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0601ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_06_01 · Reconnect (NFC)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group(context, title: 'Basic', children: [
            SwitchListTile(title: const Text('Enable NFC'), value: enable, onChanged: (v) => setState(() => enable = v)),
            SwitchListTile(title: const Text('Sound on scan'), value: playSound, onChanged: (v) => setState(() => playSound = v)),
            SwitchListTile(title: const Text('Vibrate on scan'), value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
          ]),
          _group(context, title: 'Guide', children: [
            ListTile(title: const Text('Instruction text'), subtitle: Text(guide)),
            CustomButton(text: 'OPEN GUIDE', variant: ButtonVariant.OutlinePrimaryWhite, fontStyle: ButtonFontStyle.GilroyMedium16Primary, onTap: () {}),
          ]),
          _group(context, title: 'Advanced', children: const [
            ListTile(title: Text('Auto detect NDEF type/record')),
          ]),
          const SizedBox(height: 12),
          CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class SensorReconnectQrPage extends StatefulWidget {
  const SensorReconnectQrPage({super.key});
  @override
  State<SensorReconnectQrPage> createState() => _SensorReconnectQrPageState();
}

class _SensorReconnectQrPageState extends State<SensorReconnectQrPage> {
  bool torch = false;
  String scanMode = 'Auto';
  String lastResult = '—';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_06_02 · Reconnect (QR)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group(context, title: 'Scanner', children: [
            AppSwitchRow(label: 'Torch', value: torch, onChanged: (v) => setState(() => torch = v)),
            AppCombo<String>(
              label: 'Scan mode',
              value: scanMode,
              items: const ['Auto', '1D', '2D'],
              labelFor: (s) => s,
              onChanged: (v) => setState(() => scanMode = v),
            ),
          ]),
          _group(context, title: 'Recent result', children: [
            ListTile(title: const Text('Last scan'), subtitle: Text(lastResult)),
            ElevatedButton(onPressed: () => setState(() => lastResult = 'SN-NEW-0001'), child: const Text('Insert sample')),
          ]),
          _group(context, title: 'Help', children: const [
            ListTile(title: Text('Scan QR straight at 10~15cm distance.')),
          ]),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
        ],
      ),
    );
  }
}

class SensorSharePage extends StatefulWidget {
  const SensorSharePage({super.key});
  @override
  State<SensorSharePage> createState() => _SensorSharePageState();
}

class _SensorSharePageState extends State<SensorSharePage> {
  bool enable = true;

  // 공유 기간: 1/7/30 프리셋 + 사용자 지정(날짜 범위)
  String preset = 'Custom';
  DateTimeRange? customRange;

  // 공유 항목(요구사항: Glucose data / User profile)
  bool shareGlucoseSummary = true;
  bool shareGlucoseDistribution = true;
  bool shareGlucoseGraph = true;
  bool shareUserProfile = false;

  String exportFormat = 'PDF'; // CSV / PDF

  bool revokeAnytime = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0701ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    try {
      final st = await SettingsStorage.load();
      final bool vEnable = st['sc0701Enabled'] == true;
      final String vPreset = (st['sc0701Preset'] as String? ?? 'Custom').trim();
      final String vFrom = (st['sc0701From'] as String? ?? '').trim();
      final String vTo = (st['sc0701To'] as String? ?? '').trim();

      DateTimeRange? r;
      final DateTime? from = vFrom.isEmpty ? null : DateTime.tryParse(vFrom);
      final DateTime? to = vTo.isEmpty ? null : DateTime.tryParse(vTo);
      if (from != null && to != null) {
        r = DateTimeRange(
          start: DateTime(from.year, from.month, from.day),
          end: DateTime(to.year, to.month, to.day),
        );
      } else {
        // 기본: 최근 7일(오늘 포함)
        final now = DateTime.now();
        final end = DateTime(now.year, now.month, now.day);
        final start = end.subtract(const Duration(days: 6));
        r = DateTimeRange(start: start, end: end);
      }

      if (!mounted) return;
      setState(() {
        enable = vEnable;
        preset = vPreset.isEmpty ? 'Custom' : vPreset;
        customRange = r;
        shareGlucoseSummary = st['sc0701ItemSummary'] != false;
        shareGlucoseDistribution = st['sc0701ItemDistribution'] != false;
        shareGlucoseGraph = st['sc0701ItemGraph'] != false;
        shareUserProfile = st['sc0701ItemUserProfile'] == true;
        exportFormat = ((st['sc0701Format'] as String? ?? 'PDF').trim().isEmpty) ? 'PDF' : (st['sc0701Format'] as String? ?? 'PDF').trim();
        revokeAnytime = st['sc0701Revocable'] != false;
      });
    } catch (_) {}
  }

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _rangeLabel(DateTimeRange r) {
    final int days = r.end.difference(r.start).inDays + 1;
    return '${_fmtDate(r.start)} ~ ${_fmtDate(r.end)} ($days days)';
  }

  void _applyPreset(String p) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    int days = 7;
    if (p == '1D') days = 1;
    if (p == '7D') days = 7;
    if (p == '30D') days = 30;
    final start = end.subtract(Duration(days: days - 1));
    setState(() {
      preset = p;
      customRange = DateTimeRange(start: start, end: end);
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final init = customRange ?? DateTimeRange(start: end.subtract(const Duration(days: 6)), end: end);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: init,
      helpText: 'Select sharing date range',
    );
    if (picked == null) return;
    setState(() {
      preset = 'Custom';
      customRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  Future<void> _saveOnly() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0701Enabled'] = enable;
      st['sc0701Preset'] = preset;
      if (customRange != null) {
        st['sc0701From'] = customRange!.start.toIso8601String();
        st['sc0701To'] = customRange!.end.toIso8601String();
      }
      st['sc0701ItemSummary'] = shareGlucoseSummary;
      st['sc0701ItemDistribution'] = shareGlucoseDistribution;
      st['sc0701ItemGraph'] = shareGlucoseGraph;
      st['sc0701ItemUserProfile'] = shareUserProfile;
      st['sc0701Format'] = exportFormat;
      st['sc0701Revocable'] = revokeAnytime;
      await SettingsStorage.save(st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (_) {}
  }

  Future<void> _share() async {
    if (!enable) return;
    if (customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date range.')));
      return;
    }
    if (!shareGlucoseSummary && !shareGlucoseDistribution && !shareGlucoseGraph && !shareUserProfile) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item to share.')));
      return;
    }

    final r = customRange!;
    final int days = r.end.difference(r.start).inDays + 1;
    // 요구사항 메모: 1일이면 1일치, 1~6일이면 선택한 기간만 공유
    final note = days == 1 ? 'Sharing 1 day only' : 'Sharing $days days';
    // 저장(증거화)
    try {
      final st = await SettingsStorage.load();
      st['shareConsent'] = true;
      st['shareRange'] = days.toString();
      st['shareFrom'] = r.start.toIso8601String();
      st['shareTo'] = r.end.toIso8601String();
      // SC_07_01 증거 필드
      st['sc0701Enabled'] = enable;
      st['sc0701Preset'] = preset;
      st['sc0701From'] = r.start.toIso8601String();
      st['sc0701To'] = r.end.toIso8601String();
      st['sc0701ItemSummary'] = shareGlucoseSummary;
      st['sc0701ItemDistribution'] = shareGlucoseDistribution;
      st['sc0701ItemGraph'] = shareGlucoseGraph;
      st['sc0701ItemUserProfile'] = shareUserProfile;
      st['sc0701Format'] = exportFormat;
      st['sc0701Revocable'] = revokeAnytime;
      st['sc0701LastSharedAt'] = DateTime.now().toUtc().toIso8601String();
      st['sc0701LastSharedOk'] = true;
      st['sc0701LastNote'] = note;
      await SettingsStorage.save(st);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prepared share ($exportFormat) · $note')));
  }

  static const _kMinTouchTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_07_01 · Data Share')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
          _group(context, title: 'Basic', children: [
            AppSwitchRow(label: 'Enable sharing', value: enable, onChanged: (v) => setState(() => enable = v)),
            const SizedBox(height: 6),
            const Text(
              'Sharing period: choose 1/7/30 days or Custom range.\nSharing settings: select what to share.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _PresetChip(label: '1D', selected: preset == '1D', onTap: () => _applyPreset('1D')),
              _PresetChip(label: '7D', selected: preset == '7D', onTap: () => _applyPreset('7D')),
              _PresetChip(label: '30D', selected: preset == '30D', onTap: () => _applyPreset('30D')),
              _PresetChip(label: 'Custom', selected: preset == 'Custom', onTap: _pickRange),
            ]),
            const SizedBox(height: 10),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: const Text('Sharing date range'),
              subtitle: Text(customRange == null ? '—' : _rangeLabel(customRange!)),
              trailing: TextButton(onPressed: enable ? _pickRange : null, child: const Text('Change')),
            ),
          ]),
          _group(context, title: 'Sharing items', children: [
            // Glucose data
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Glucose data · Summary'),
              value: shareGlucoseSummary,
              onChanged: enable ? (v) => setState(() => shareGlucoseSummary = v) : null,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Glucose data · Range distribution'),
              value: shareGlucoseDistribution,
              onChanged: enable ? (v) => setState(() => shareGlucoseDistribution = v) : null,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Glucose data · Glucose graph'),
              value: shareGlucoseGraph,
              onChanged: enable ? (v) => setState(() => shareGlucoseGraph = v) : null,
            ),
            const Divider(height: 16),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('User profile'),
              value: shareUserProfile,
              onChanged: enable ? (v) => setState(() => shareUserProfile = v) : null,
            ),
          ]),
          _group(context, title: 'Export format', children: [
            const SizedBox(height: 6),
            AppCombo<String>(
              label: 'Export format',
              value: exportFormat,
              items: const ['CSV', 'PDF'],
              labelFor: (s) => s,
              onChanged: (v) {
                if (!enable) return;
                setState(() => exportFormat = v);
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Share opens Android system share sheet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
          _group(context, title: 'Security', children: [
            AppSwitchRow(
              label: 'Revocable anytime',
              value: revokeAnytime,
              onChanged: (v) {
                if (!enable) return;
                setState(() => revokeAnytime = v);
              },
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: _kMinTouchTarget + 8,
            width: double.infinity,
            child: CustomButton(
              width: double.infinity,
              text: 'SAVE',
              variant: ButtonVariant.FillLoginGreenFlat,
              onTap: () async {
                await _saveOnly();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _kMinTouchTarget + 8,
            width: double.infinity,
            child: CustomButton(
              width: double.infinity,
              text: 'SHARE',
              variant: ButtonVariant.FillLoginGreen,
              onTap: enable ? _share : null,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent;
    final Color border = selected ? cs.primary : Colors.grey.shade400;
    final Color fg = selected ? cs.primary : Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
Widget _notifItemRoute(BuildContext context, bool isDark, IconData icon, String title, String subtitle, String routeName, String reqId) {
  return DebugBadge(
    reqId: reqId,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pushNamed(routeName),
        child: _notifItemChild(context, isDark, icon, title, subtitle),
      ),
    ),
  );
}

Widget _notifItem(BuildContext context, bool isDark, IconData icon, String title, String subtitle, Widget page, String reqId) {
  return DebugBadge(
    reqId: reqId,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        child: _notifItemChild(context, isDark, icon, title, subtitle),
      ),
    ),
  );
}

Widget _notifItemChild(BuildContext context, bool isDark, IconData icon, String title, String subtitle) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      GradientIcon(icon, gradient: AppIconGradients.resolve(icon)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: ColorConstant.bluegray400)),
      ])),
      const Icon(Icons.chevron_right),
    ]),
  );
}




Widget _group(BuildContext context, {required String title, required List<Widget> children, IconData? icon}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  IconData resolved = icon ?? _inferIcon(title);
  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ColorConstant.indigo51, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Icon(resolved, color: Theme.of(context).colorScheme.primary),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

IconData _inferIcon(String title) {
  final t = title.toLowerCase();
  if (t.contains('start')) return Icons.calendar_month;
  if (t.contains('warm')) return Icons.timer_outlined;
  if (t.contains('basic') || t.contains('info')) return Icons.info_outline;
  if (t.contains('scan') || t.contains('reconnect')) return Icons.bluetooth;
  if (t.contains('usage') || t.contains('connected')) return Icons.link;
  if (t.contains('lifetime')) return Icons.schedule;
  if (t.contains('replacement') || t.contains('update')) return Icons.update;
  if (t.contains('help') || t.contains('guide')) return Icons.help_outline;
  if (t.contains('scanner') || t.contains('qr')) return Icons.qr_code_scanner;
  if (t.contains('share') || t.contains('receiv')) return Icons.forward_to_inbox;
  if (t.contains('advanced')) return Icons.tune;
  return Icons.article_outlined;
}

class SensorBleScanPage extends StatefulWidget {
  const SensorBleScanPage({super.key});
  @override
  State<SensorBleScanPage> createState() => _SensorBleScanPageState();
}

class _SensorBleScanPageState extends State<SensorBleScanPage> {
  bool scanning = false;
  List<Map<String, dynamic>> devices = [];
  Map<String, dynamic>? connected;

  // last known device (from prefs)
  String _lastId = '';
  String _lastName = 'CGMS';

  bool _disconnecting = false;

  int battery = 0;
  Duration used = Duration.zero;
  Duration valid = const Duration(days: 14);

  @override
  void initState() {
    super.initState();
    _hydrateFromPrefs();
    BleService().phase.addListener(_onPhaseChanged);
  }

  @override
  void dispose() {
    try { BleService().phase.removeListener(_onPhaseChanged); } catch (_) {}
    super.dispose();
  }

  void _onPhaseChanged() {
    if (!mounted) return;
    final ph = BleService().phase.value;
    if (ph == BleConnPhase.off) {
      setState(() { connected = null; });
    } else {
      _hydrateFromPrefs();
    }
    // ensure UI scanning flag is cleared whenever BLE leaves scanning
    if (ph != BleConnPhase.scanning && mounted && scanning) {
      setState(() { scanning = false; });
    }
  }

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String id = (prefs.getString('cgms.last_mac') ?? '').trim();
      final String name = (prefs.getString('cgms.last_name') ?? '').trim();
        if (!mounted) return;
      setState(() {
        _lastId = id;
        _lastName = name.isEmpty ? 'CGMS' : name;
        // 'connected' UI state follows real BLE phase; don't force when phase is off
        if (BleService().phase.value != BleConnPhase.off && id.isNotEmpty) {
          connected = {'id': id, 'name': _lastName, 'rssi': 0};
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_01 · Scan & Connect')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DebugBadge(
            reqId: 'SC_01_01',
            child: _group(context, title: 'Scanner', children: [
              Row(children: [
                Expanded(
                  child: ValueListenableBuilder<BleConnPhase>(
                    valueListenable: BleService().phase,
                    builder: (context, ph, _) {
                      String label;
                      if (scanning) label = 'Scanning...';
                      else if (ph == BleConnPhase.connecting) label = 'Connecting...';
                      else if (ph != BleConnPhase.off) label = 'Scanning...';
                      else label = 'Ready';
                      return Text(label);
                    },
                  ),
                ),
                ValueListenableBuilder<BleConnPhase>(
                  valueListenable: BleService().phase,
                  builder: (context, ph, _) => IntrinsicWidth(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: (scanning || ph != BleConnPhase.off) ? null : () { _mockScan(); },
                        icon: const Icon(Icons.bluetooth_searching, size: 18),
                        label: const Text('BLE Scan'),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              if (devices.isEmpty && !scanning)
                const Text('No devices yet')
              else if (devices.isEmpty)
                const Text('Scanning...')
              else
                ...devices.map((d) => ListTile(
                      leading: Icon(Icons.sensors, color: primary),
                      title: Text(d['name']),
                      subtitle: Text('RSSI ${d['rssi']} dBm · ${d['id']}'),
                      trailing: ValueListenableBuilder<BleConnPhase>(
                        valueListenable: BleService().phase,
                  builder: (context, ph, _) {
                    final bool busy = (ph == BleConnPhase.connecting || ph == BleConnPhase.scanning);
                    final bool canConnect = (ph == BleConnPhase.off && !scanning);
                    return IntrinsicWidth(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: canConnect ? () => _connect(d) : () { DebugToastBus().show('BLE: already in session'); },
                          icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.link),
                          label: Text(
                            canConnect ? 'Connect' : (ph == BleConnPhase.connecting ? 'Connecting...' : 'Connected'),
                            ),
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  },
                      ),
                    )),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: (scanning || BleService().phase.value != BleConnPhase.off)
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BeforeQrScanPage()),
                        ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QR Scan'),
              ),
            ]),
          ),
          ValueListenableBuilder<BleConnPhase>(
            valueListenable: BleService().phase,
            builder: (context, phase, _) {
              final bool showConnectedCard = (phase != BleConnPhase.off);
              if (!showConnectedCard) return const SizedBox.shrink();
              return _group(context, title: 'Connected', children: [
                ListTile(title: const Text('Device'), subtitle: Text((connected != null ? (connected!['name'] as String?) : null) ?? _lastName)),
                ListTile(title: const Text('ID'), subtitle: Text((connected != null ? (connected!['id'] as String?) : null) ?? _lastId)),
              ListTile(title: const Text('Battery'), trailing: Text('$battery%')),
              ListTile(
                title: const Text('Usage'),
                subtitle: Text('Used ${used.inHours}h / ${valid.inDays}d'),
                trailing: Text('${((used.inSeconds / valid.inSeconds) * 100).clamp(0, 100).toStringAsFixed(0)}%'),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _mockRead,
                    child: const Text('Read status'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnecting ? null : () async {
                      setState(() { _disconnecting = true; });
                      await BleService().disconnect();
                      if (!mounted) return;
                      setState(() { connected = null; _disconnecting = false; });
                    },
                    icon: _disconnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_off),
                    label: Text(_disconnecting ? 'Disconnecting...' : 'Disconnect'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // RACP controls (count/all/last)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async { await BleService().requestRacpCountAll(); },
                    child: const Text('RACP: Count'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async { await BleService().requestRacpAllRecords(); },
                    child: const Text('RACP: All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async { await BleService().requestRacpLastRecord(); },
                    child: const Text('RACP: Last'),
                  ),
                ),
              ]),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _mockScan() async {
    setState(() { scanning = true; devices = []; });
    final ble = BleService();
    final seen = <String>{};
    await for (final d in ble.scanCgms()) {
      if (!mounted) break;
      if (seen.add(d.id)) {
        setState(() { devices.add({'id': d.id, 'name': d.name.isEmpty ? 'CGMS' : d.name, 'rssi': d.rssi}); });
      }
    }
    if (mounted) setState(() { scanning = false; });
  }

  Future<void> _connect(Map<String, dynamic> d) async {
    setState(() => connected = d);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cgms.last_mac', (d['id'] as String? ?? ''));
      await prefs.setString('cgms.last_name', (d['name'] as String? ?? 'CGMS'));
    } catch (_) {}
    final String deviceId = d['id'] as String? ?? '';
    await BleService().connectToDevice(deviceId);
    if (!mounted) return;
    // 연결 성공 후 Sensor Connect 화면은 건너뛰고 바로 Warm-up 진입.
    await BleService().startWarmupAndNavigate();
    await _mockRead();
  }

  Future<void> _mockRead() async {
    final now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 3));
    try {
      final st = await SettingsStorage.load();
      final String raw = (st['sensorStartAt'] as String? ?? '').trim();
      final dt = raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
      if (dt != null) start = dt;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      battery = 78;
      used = now.difference(start);
      valid = const Duration(days: 14);
    });
  }

  Future<void> _emitMockGlucose() async {
    // 모의 BLE 수신 데이터 → 큐 인입 → 서버 동기화 → 알림
    final double value = 50 + (150 * (DateTime.now().millisecond / 999));
    IngestQueueService().enqueueGlucose(DateTime.now(), value);
    if (!mounted) return;
    try {
      final s = await SettingsStorage.load();
      final bool notifOn = (s['notificationsEnabled'] ?? true) == true;
      if (notifOn) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mock glucose enqueued')));
      }
    } catch (_) {}
  }
}