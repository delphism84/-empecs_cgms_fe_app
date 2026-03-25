import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/qr_sn_parser.dart';

/// QR 스캔 후 등록된 SN과 일치할 때만 연결 허용.
/// 일치하지 않으면 "등록된 SN이 아닙니다. QR을 먼저 스캔해주세요." 안내 (iOS 스타일).
class QrVerifyBeforeConnectScreen extends StatefulWidget {
  const QrVerifyBeforeConnectScreen({super.key});

  @override
  State<QrVerifyBeforeConnectScreen> createState() => _QrVerifyBeforeConnectScreenState();
}

class _QrVerifyBeforeConnectScreenState extends State<QrVerifyBeforeConnectScreen> {
  final MobileScannerController _controller = MobileScannerController(torchEnabled: false, autoStart: true);
  StreamSubscription<Object?>? _subscription;
  List<Map<String, dynamic>> _registeredDevices = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.barcodes.listen(_onBarcode);
    _loadRegistered();
  }

  Future<void> _loadRegistered() async {
    try {
      final s = await SettingsStorage.load();
      final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        _registeredDevices = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  void _onBarcode(BarcodeCapture cap) {
    if (!mounted || !_loaded) return;
    if (cap.barcodes.isEmpty) return;
    final String? v = cap.barcodes.first.rawValue;
    if (v == null || v.isEmpty) return;
    final String fullSn = QrSnParser.fullSn(v) ?? v.trim().toUpperCase();
    final Map<String, String>? parsed = QrSnParser.parse(v);
    final String serial = parsed?['serial'] ?? '';

    final bool match = _registeredDevices.any((d) {
      final String regSn = (d['sn'] as String? ?? '').trim();
      final String regFull = (d['fullSn'] as String? ?? '').trim().toUpperCase();
      return (serial.isNotEmpty && regSn == serial) ||
          (fullSn.isNotEmpty && (regFull == fullSn || regSn == fullSn));
    });

    _saveLastScannedQr(v, fullSn, serial, registered: match);

    if (match) {
      _controller.stop();
      Navigator.of(context).pop(<String, String>{'serial': serial, 'fullSn': fullSn});
      return;
    }

    _showNotRegisteredAlert();
  }

  Future<void> _saveLastScannedQr(String raw, String fullSn, String serial, {required bool registered}) async {
    try {
      final s = await SettingsStorage.load();
      s['lastScannedQrRaw'] = raw.trim();
      s['lastScannedQrFullSn'] = fullSn;
      s['lastScannedQrSerial'] = serial;
      s['lastScannedQrAt'] = DateTime.now().toUtc().toIso8601String();
      s['lastScannedQrRegistered'] = registered;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  void _showNotRegisteredAlert() {
    _controller.stop();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Unregistered QR SN'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('등록된 SN이 아닙니다.\nQR을 먼저 스캔해주세요.'),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.start();
            },
            child: const Text('다시 스캔'),
          ),
        ],
      ),
    ).then((_) => _controller.start());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_registeredDevices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR 확인')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.info_outline, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  '등록된 기기가 없습니다.\nQR을 먼저 스캔해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/sc/01/04').then((_) => Navigator.of(context).pop()),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR 스캔하러 가기'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Size sz = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR 확인 후 연결'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '등록한 센서의 QR을 스캔해주세요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
            ),
            SizedBox(
              height: sz.height * 0.5,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: (_) {},
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: sz.width * 0.7,
                          height: sz.height * 0.25,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
