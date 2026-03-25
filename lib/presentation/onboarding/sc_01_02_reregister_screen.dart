import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Sc0102ReregisterScreen extends StatefulWidget {
  const Sc0102ReregisterScreen({super.key});

  @override
  State<Sc0102ReregisterScreen> createState() => _Sc0102ReregisterScreenState();
}

class _Sc0102ReregisterScreenState extends State<Sc0102ReregisterScreen> {
  Map<String, dynamic>? _last;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
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
    final String sn = (_last?['sn'] ?? '').toString();
    final String model = (_last?['model'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_02 · Sensor re-register')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Unexpected logout detected.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please re-connect your sensor by rescanning.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registered sensors: $_count', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (sn.isNotEmpty || model.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Last sensor: ${model.isEmpty ? '-' : model} / ${sn.isEmpty ? '-' : sn}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/sensor'),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan & Connect'),
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

