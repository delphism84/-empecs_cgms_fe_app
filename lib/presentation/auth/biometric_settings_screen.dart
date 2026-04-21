import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  String? _statusKey;

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
    setState(() { _statusKey = 'bio_status_saved'; });
  }

  Future<void> _test() async {
    final ok = await BiometricService().authenticate(reason: 'bio_test_auth'.tr());
    if (!mounted) return;
    setState(() { _statusKey = ok ? 'bio_status_success' : 'bio_status_failed'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('bio_settings_appbar'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text('bio_enable_title'.tr()),
            subtitle: Text('bio_enable_sub'.tr()),
            value: _enabled,
            onChanged: (v) async {
              setState(() { _enabled = v; });
              await _save();
            },
          ),
          if (kDebugMode) ...[
            const Divider(),
            SwitchListTile(
              title: Text('bio_debug_bypass_title'.tr()),
              subtitle: Text('bio_debug_bypass_sub'.tr()),
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
            label: Text('bio_test_auth'.tr()),
          ),
          const SizedBox(height: 12),
          if (_statusKey != null) Text('bio_status_label'.tr(namedArgs: {'v': _statusKey!.tr()})),
        ],
      ),
    );
  }
}

