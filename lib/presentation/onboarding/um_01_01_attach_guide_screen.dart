import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/image_constant.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Um0101AttachGuideScreen extends StatefulWidget {
  const Um0101AttachGuideScreen({super.key});

  @override
  State<Um0101AttachGuideScreen> createState() => _Um0101AttachGuideScreenState();
}

class _Um0101AttachGuideScreenState extends State<Um0101AttachGuideScreen> {
  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['um0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UM_01_01 · Sensor attachment guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Before QR Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Follow the steps below to attach the sensor properly.\n'
                      '(영상/사진 안내는 추후 실제 컨텐츠로 교체)',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        ImageConstant.imgHealthcarework,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 170,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('Attachment image placeholder'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _step(1, 'Clean the skin area and dry completely.'),
            _step(2, 'Attach the sensor firmly for a few seconds.'),
            _step(3, 'Open the app and proceed to QR scan.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/sc/01/04');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Proceed to QR Scan (SC_01_04)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(int n, String text) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$n')),
        title: Text(text),
      ),
    );
  }
}

