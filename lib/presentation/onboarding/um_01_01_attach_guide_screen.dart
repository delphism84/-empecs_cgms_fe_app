import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      appBar: AppBar(title: Text('um0101_appbar'.tr())),
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
                    Text('um0101_before_qr_heading'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'um0101_intro'.tr(),
                      style: const TextStyle(fontSize: 13),
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
                          child: Text('um0101_image_placeholder'.tr()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('um0101_steps'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _step(1, 'um0101_step1'.tr()),
            _step(2, 'um0101_step2'.tr()),
            _step(3, 'um0101_step3'.tr()),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/sc/01/04');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('um0101_proceed_qr'.tr()),
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

