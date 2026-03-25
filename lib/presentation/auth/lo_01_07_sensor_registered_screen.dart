import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// LO_01_07: 센서 등록 여부 확인
/// - 등록된 센서가 있으면 "재스캔" 안내 이미지를 표시
/// - 없으면 센서 등록(스캔) 유도
class Lo0107SensorRegisteredScreen extends StatefulWidget {
  const Lo0107SensorRegisteredScreen({super.key});

  @override
  State<Lo0107SensorRegisteredScreen> createState() => _Lo0107SensorRegisteredScreenState();
}

class _Lo0107SensorRegisteredScreenState extends State<Lo0107SensorRegisteredScreen> {
  int _count = 0;
  Map<String, dynamic>? _last;

  @override
  void initState() {
    super.initState();
    _load();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['lo0107ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      final List<dynamic> list = (st['registeredDevices'] as List<dynamic>? ?? const <dynamic>[]);
      final int n = list.length;
      Map<String, dynamic>? last;
      if (n > 0 && list.last is Map) {
        last = Map<String, dynamic>.from(list.last as Map);
      }
      if (!mounted) return;
      setState(() {
        _count = n;
        _last = last;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool has = _count > 0;
    final String sn = (_last?['sn'] ?? '').toString();
    final String model = (_last?['model'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('LO_01_07 · Sensor check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              has ? 'Sensor already registered' : 'No sensor registered',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              has ? 'Please re-scan to continue using your existing sensor.' : 'Please scan and register a sensor to start.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: has ? const Color(0xFFE8F3FF) : const Color(0xFFEFFBF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black),
              ),
              alignment: Alignment.center,
              child: Icon(
                has ? Icons.qr_code_scanner : Icons.bluetooth_searching,
                size: 64,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registered sensors: $_count', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (has && (sn.isNotEmpty || model.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Text('Last sensor: ${model.isEmpty ? '-' : model} / ${sn.isEmpty ? '-' : sn}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/sc/01/04'),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(has ? 'Re-scan QR' : 'Scan QR'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

