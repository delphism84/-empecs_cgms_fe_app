import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/biometric_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  bool _enabled = false;
  bool _bypass = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      setState(() {
        _enabled = st['biometricEnabled'] == true;
        _bypass = st['biometricDebugBypass'] == true;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final st = await SettingsStorage.load();
    st['biometricEnabled'] = _enabled;
    if (kDebugMode) st['biometricDebugBypass'] = _bypass;
    await SettingsStorage.save(st);
    setState(() { _status = 'Saved'; });
  }

  Future<void> _test() async {
    final ok = await BiometricService().authenticate(reason: 'Test biometrics');
    if (!mounted) return;
    setState(() { _status = ok ? 'Success' : 'Failed'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric (LO_02_06)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable biometrics'),
            subtitle: const Text('Use fingerprint/face to login'),
            value: _enabled,
            onChanged: (v) async {
              setState(() { _enabled = v; });
              await _save();
            },
          ),
          if (kDebugMode) ...[
            const Divider(),
            SwitchListTile(
              title: const Text('[DEBUG] Bypass biometric prompt'),
              subtitle: const Text('For bot automation only'),
              value: _bypass,
              onChanged: (v) async {
                setState(() { _bypass = v; });
                await _save();
              },
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _enabled ? _test : null,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Test authentication'),
          ),
          const SizedBox(height: 12),
          Text('Status: $_status'),
        ],
      ),
    );
  }
}

