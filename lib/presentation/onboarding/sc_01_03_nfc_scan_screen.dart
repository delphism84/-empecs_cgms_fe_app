import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Sc0103NfcScanScreen extends StatefulWidget {
  const Sc0103NfcScanScreen({super.key});

  @override
  State<Sc0103NfcScanScreen> createState() => _Sc0103NfcScanScreenState();
}

class _Sc0103NfcScanScreenState extends State<Sc0103NfcScanScreen> {
  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0103ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_03 · NFC Sensor Scan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Register the sensor using NFC tag.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('How to scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                    Text('1) Turn on NFC on your phone.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 6),
                    Text('2) Place the phone near the sensor NFC tag area.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 6),
                    Text('3) Keep it steady until scan completes.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 10),
                    Text('(NFC 안내 이미지/그림은 추후 실제 리소스로 교체)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/sc/01/05'),
                    child: const Text('Scan failed · Enter SN'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/sc/01/06'),
                    child: const Text('Scan success'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

