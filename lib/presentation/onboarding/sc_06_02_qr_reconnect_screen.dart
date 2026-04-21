import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
    if (r == 'expired') return 'sc0602_reason_expired'.tr();
    if (r == 'error') return 'sc0602_reason_error'.tr();
    if (r == 'abnormal') return 'sc0602_reason_abnormal'.tr();
    return 'sc0602_reason_default'.tr();
  }

  String _reasonBody() {
    final r = _reason.trim().toLowerCase();
    if (r == 'expired') return 'sc0602_body_expired'.tr();
    if (r == 'error') return 'sc0602_body_error'.tr();
    if (r == 'abnormal') return 'sc0602_body_abnormal'.tr();
    return 'sc0602_body_default'.tr();
  }

  Future<void> _disconnect() async {
    if (_disconnecting) return;
    setState(() => _disconnecting = true);
    try {
      await BleService().disconnect();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _disconnecting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sensor_reconnect_disconnected_snack'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sensor_sc0602_title'.tr())),
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
                  children: [
                    Text('sensor_reconnect_steps'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text('sc0602_step1'.tr(), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('sc0602_step2'.tr(), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('sc0602_step3'.tr(), style: const TextStyle(fontSize: 13)),
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
                    label: Text(_disconnecting ? 'common_disconnecting'.tr() : 'common_disconnect'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/sc/01/04'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text('sensor_qr_reconnect_button'.tr()),
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

