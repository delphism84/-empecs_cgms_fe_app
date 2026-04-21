import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      appBar: AppBar(title: Text('sensor_sc0103_appbar'.tr())),
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
                  children: [
                    Text('nfc_how_to_scan'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('nfc_step1_turn_on'.tr(), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('nfc_step2_place'.tr(), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('nfc_step3_steady'.tr(), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 10),
                    Text('nfc_placeholder_note'.tr(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                    child: Text('nfc_scan_failed_enter_sn'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/sc/01/06'),
                    child: Text('nfc_scan_success'.tr()),
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

