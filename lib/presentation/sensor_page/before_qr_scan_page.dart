import 'package:flutter/material.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/sensor_page/sensor_qr_connect_page.dart';

/// QR 스캔 전 안내 페이지. sensorguide.png + 1,2,3 스텝 + "Process to QR scan" 버튼
class BeforeQrScanPage extends StatelessWidget {
  const BeforeQrScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Before QR Scan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/sensorguide.png',
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Text('sensorguide.png'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '1. Scan the QR code on your sensor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '2. Confirm the sensor information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '3. Save & Sync to register your device',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              CustomButton(
                width: double.infinity,
                text: 'Scan QR Code',
                variant: ButtonVariant.FillLoginGreen,
                onTap: () async {
                  // SensorQrConnectPage에서 `pushReplacement`로 다음 페이지(StartMonitorPage)로 교체되는
                  // 케이스가 있어, 여기서 pop(true)를 수행하면 UX가 뒤로 튕기는 문제가 생길 수 있다.
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SensorQrConnectPage(
                        title: 'QR Sensor Scan',
                        reqId: 'SC_01_04',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
