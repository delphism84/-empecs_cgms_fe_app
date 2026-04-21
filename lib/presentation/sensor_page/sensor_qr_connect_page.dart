import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/qr_sn_parser.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/sensor_page/start_monitor_page.dart';

class SensorQrConnectPage extends StatefulWidget {
  const SensorQrConnectPage({super.key, this.title, this.reqId});
  final String? title;
  final String? reqId;
  @override
  State<SensorQrConnectPage> createState() => _SensorQrConnectPageState();
}

class _SensorQrConnectPageState extends State<SensorQrConnectPage> {
  final MobileScannerController _controller = MobileScannerController(torchEnabled: false, autoStart: true);
  StreamSubscription<Object?>? _subscription;
  String _raw = '';
  Map<String, String>? _parsed; // model, year, sampleFlag, serial
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.barcodes.listen(_onBarcode);
    _markViewed();
  }

  Future<void> _markViewed() async {
    if ((widget.reqId ?? '').trim() != 'SC_01_04') return;
    try {
      final st = await SettingsStorage.load();
      st['sc0104ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  void _onBarcode(BarcodeCapture cap) {
    if (!mounted) return;
    if (cap.barcodes.isEmpty) return;
    final String? v = cap.barcodes.first.rawValue;
    if (v == null || v.isEmpty) return;
    // accept first valid, then pause camera
    final Map<String, String>? p = QrSnParser.parse(v);
    if (p == null) {
      setState(() {
        _raw = v;
        _parsed = null;
      });
      return;
    }
    _controller.stop();
    setState(() {
      _raw = v;
      _parsed = p;
    });
    _saveLastScannedQr(v, p, registered: false);
  }

  /// 스캔된 QR을 로컬에 저장 (Serial Number 페이지 등에서 마지막 스캔 정보 표시용)
  Future<void> _saveLastScannedQr(String raw, Map<String, String>? parsed, {bool registered = false}) async {
    if (parsed == null) return;
    try {
      final fullSn = QrSnParser.fullSn(raw) ?? raw.trim().toUpperCase();
      final s = await SettingsStorage.load();
      s['lastScannedQrRaw'] = raw.trim();
      s['lastScannedQrFullSn'] = fullSn;
      s['lastScannedQrSerial'] = parsed['serial'] ?? '';
      s['lastScannedQrAt'] = DateTime.now().toUtc().toIso8601String();
      s['lastScannedQrRegistered'] = registered;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  /// 등록 시 fullSn(예: C21ZS00033) 저장 및 현재 센서(eqsn)로 설정
  Future<void> _saveDevice() async {
    if (_parsed == null || _saving) return;
    setState(() => _saving = true);
    try {
      final s = await SettingsStorage.load();
      final String prevEqsn = (s['eqsn'] as String? ?? '').trim();
      final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
      final String serial = _parsed!['serial'] ?? '';
      final String fullSn = QrSnParser.fullSn(_raw) ?? _raw.trim().toUpperCase();
      final String? mac = (_parsed!['mac'] ?? '').trim().isNotEmpty ? _parsed!['mac'] : null;
      final String existingStart = (s['sensorStartAt'] as String? ?? '').trim();
      // 다른 시리얼로 QR 재스캔 시 이전 sensorStartAt·웜업이 남지 않도록 정리 (검수 1-7)
      // 로그아웃 등으로 eqsn만 비워진 경우(prevEqsn 빈 값)에도 이전 시작일이 남는 문제 방지
      final bool snChanged = prevEqsn.isNotEmpty && fullSn.toUpperCase() != prevEqsn.toUpperCase();
      final bool orphanStart = prevEqsn.isEmpty && existingStart.isNotEmpty;
      if (snChanged || orphanStart) {
        s['sensorStartAt'] = '';
        s['sensorStartAtEqsn'] = '';
        s['sc0106WarmupDoneAt'] = '';
        s['sc0106WarmupActive'] = false;
        s['sc0106WarmupEqsn'] = '';
        if (snChanged && prevEqsn.isNotEmpty) {
          try {
            await GlucoseLocalRepo().clearForEqsn(prevEqsn);
          } catch (_) {}
        }
        try {
          DataSyncBus().emitGlucoseBulk(count: 0);
        } catch (_) {}
      }
      list.add({
        'id': 'QR-${DateTime.now().millisecondsSinceEpoch}',
        'sn': serial,
        'fullSn': fullSn,
        'mac': mac,
        'advName': _parsed!['advName'],
        'idMac': _parsed!['idMac'],
        'model': _parsed!['model'],
        'year': _parsed!['year'],
        'sampleFlag': _parsed!['sampleFlag'],
        'registeredAt': DateTime.now().toIso8601String(),
      });
      s['registeredDevices'] = list;
      s['eqsn'] = fullSn;
      SettingsService.stripStaleSensorStart(s);
      s['lastScannedQrRegistered'] = true;
      s['lastScannedQrFullSn'] = fullSn;
      s['lastScannedQrSerial'] = serial;
      if (mac != null) s['lastScannedQrMac'] = mac;
      s['lastScannedQrRaw'] = _raw.trim();
      s['lastScannedQrAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('qr_saved_synced'.tr())));
      // stack 정리를 위해 기존 QR 화면을 교체(pushReplacement)한다.
      // (pushAndRemoveUntil은 조건에 따라 이전 화면이 남아 "Sensor로 복귀"처럼 보일 수 있음)
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StartMonitorPage(
            targetSerial: fullSn.isNotEmpty ? fullSn : serial,
            targetMac: mac,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size sz = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'sensor_qr_sensor_scan_title'.tr())),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final camH = c.maxHeight;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (c) {},
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pushNamed('/sc/01/05'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.25),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.9)),
                        ),
                        child: Text('qr_field_sn'.tr()),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: sz.width * 0.7,
                            height: camH * 0.55,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(top: BorderSide(color: ColorConstant.indigo51, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('qr_detected_result'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    _raw.isEmpty ? '—' : _raw,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    softWrap: true,
                  ),
                  if (_raw.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data: _raw,
                          version: QrVersions.auto,
                          size: 100,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if ((_parsed?['advName'] ?? '').isNotEmpty) _InfoCard(title: 'qr_field_adv'.tr(), value: _parsed!['advName'], icon: Icons.bluetooth),
                    if ((_parsed?['mac'] ?? '').isNotEmpty) _InfoCard(title: 'qr_field_mac'.tr(), value: _parsed!['mac'], icon: Icons.router),
                    _InfoCard(title: 'qr_field_model'.tr(), value: _parsed?['model'], icon: Icons.precision_manufacturing),
                    _InfoCard(title: 'sensor_detail_serial'.tr(), value: _parsed != null ? (_parsed!['serial'] ?? '') : (_raw.isNotEmpty ? '—' : null), icon: Icons.confirmation_number_outlined),
                  ]),
                  const SizedBox(height: 12),
                  CustomButton(
                    width: double.infinity,
                    text: _saving ? 'qr_saving'.tr() : 'qr_save_sync'.tr(),
                    variant: ButtonVariant.FillLoginGreen,
                    onTap: (_parsed == null || _saving) ? null : _saveDevice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.icon});
  final String title;
  final String? value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 8) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConstant.green500, width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text((value == null || value!.isEmpty) ? '' : value!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}


