import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SensorScanNfcPage extends StatelessWidget {
  const SensorScanNfcPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sensor_sc0103_flow_title'.tr())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('sensor_flow_nfc_hint'.tr()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: Text('sensor_flow_scan_ok'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SensorSerialInputPage())),
              child: Text('nfc_scan_failed_enter_sn'.tr()),
            )
          ],
        ),
      ),
    );
  }
}

class SensorScanQrPage extends StatelessWidget {
  const SensorScanQrPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sensor_sc0104_flow_title'.tr())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('sensor_flow_qr_align'.tr()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: Text('sensor_flow_scan_ok'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SensorSerialInputPage())),
              child: Text('nfc_scan_failed_enter_sn'.tr()),
            )
          ],
        ),
      ),
    );
  }
}

class SensorSerialInputPage extends StatefulWidget {
  const SensorSerialInputPage({super.key});
  @override
  State<SensorSerialInputPage> createState() => _SensorSerialInputPageState();
}

class _SensorSerialInputPageState extends State<SensorSerialInputPage> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sensor_sc0105_flow_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'sensor_flow_serial_label'.tr()),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: Text('sensor_flow_register'.tr()),
            )
          ],
        ),
      ),
    );
  }
}

class SensorWarmupPage extends StatefulWidget {
  const SensorWarmupPage({super.key});
  @override
  State<SensorWarmupPage> createState() => _SensorWarmupPageState();
}

class _SensorWarmupPageState extends State<SensorWarmupPage> {
  static const int totalSeconds = 30 * 60; // 30분
  late Timer timer;
  int remaining = totalSeconds;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        remaining--;
        if (remaining <= 0) {
          t.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: Text('sensor_sc0106_flow_title'.tr())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('sensor_flow_warmup_title_line'.tr()),
            const SizedBox(height: 12),
            Text('$minutes:$seconds', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('sensor_flow_warmup_done_hint'.tr()),
          ],
        ),
      ),
    );
  }
}


