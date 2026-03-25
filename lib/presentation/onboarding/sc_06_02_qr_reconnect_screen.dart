import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Sc0602QrReconnectScreen extends StatefulWidget {
  const Sc0602QrReconnectScreen({super.key});

  @override
  State<Sc0602QrReconnectScreen> createState() => _Sc0602QrReconnectScreenState();
}

class _Sc0602QrReconnectScreenState extends State<Sc0602QrReconnectScreen> {
  String _reason = '';
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _markViewed();
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      final String r = (st['sc0602Reason'] as String? ?? '').trim();
      if (!mounted) return;
      setState(() => _reason = r);
    } catch (_) {}
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0602ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  String _reasonTitle() {
    final r = _reason.trim().toLowerCase();
    if (r == 'expired') return 'Sensor expired';
    if (r == 'error') return 'Sensor error';
    if (r == 'abnormal') return 'Abnormal sensor signal';
    return 'Reconnect sensor';
  }

  String _reasonBody() {
    final r = _reason.trim().toLowerCase();
    if (r == 'expired') return 'The sensor usage period has expired. Please disconnect and reconnect a new sensor.';
    if (r == 'error') return 'A sensor issue was detected. Please disconnect and reconnect.';
    if (r == 'abnormal') return 'Sensor signal looks abnormal. Please reconnect.';
    return 'If the sensor has issues or needs reconnection, follow the steps below.';
  }

  Future<void> _disconnect() async {
    if (_disconnecting) return;
    setState(() => _disconnecting = true);
    try {
      await BleService().disconnect();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _disconnecting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_06_02 · QR Reconnect')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_reasonTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_reasonBody(), style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    Text('1) Tap Disconnect to release current sensor connection.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 6),
                    Text('2) Tap QR Reconnect and scan the new sensor QR code.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 6),
                    Text('3) After reconnect, warm-up starts automatically.', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnecting ? null : _disconnect,
                    icon: _disconnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_off),
                    label: Text(_disconnecting ? 'Disconnecting...' : 'Disconnect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/sc/01/04'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR Reconnect'),
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

