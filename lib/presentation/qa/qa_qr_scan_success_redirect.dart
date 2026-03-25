import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/app_nav.dart';

/// QA 전용: QR 스캔 성공 상태를 저장한 뒤 BLE 스캔 화면(SC_01_01)으로 이동.
/// 웹에서 #/qa/qr-scan-success 로 진입 시 사용.
class QaQrScanSuccessRedirect extends StatefulWidget {
  const QaQrScanSuccessRedirect({super.key});

  @override
  State<QaQrScanSuccessRedirect> createState() => _QaQrScanSuccessRedirectState();
}

class _QaQrScanSuccessRedirectState extends State<QaQrScanSuccessRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAndGo());
  }

  Future<void> _applyAndGo() async {
    const String fullSn = 'C21ZS00033';
    const String serial = '00033';
    try {
      final s = await SettingsStorage.load();
      final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
      list.add({
        'id': 'QR-${DateTime.now().millisecondsSinceEpoch}',
        'sn': serial,
        'fullSn': fullSn,
        'model': 'C21',
        'year': '2025',
        'sampleFlag': 'S',
        'registeredAt': DateTime.now().toIso8601String(),
      });
      s['registeredDevices'] = list;
      s['eqsn'] = fullSn;
      await SettingsStorage.save(s);
    } catch (_) {}
    if (!mounted) return;
    await AppNav.goNamed('/sc/01/01/scan', replaceStack: true);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('QA: QR 스캔 성공 시뮬레이션 적용 중…'),
          ],
        ),
      ),
    );
  }
}
