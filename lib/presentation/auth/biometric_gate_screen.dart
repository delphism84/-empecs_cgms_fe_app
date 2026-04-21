import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/biometric_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _busy = true; _error = null; });
    try {
      final st = await SettingsStorage.load();
      final bool enabled = st['biometricEnabled'] == true;
      final String token = (st['authToken'] as String? ?? '').trim();
      if (!enabled || token.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final ok = await BiometricService().authenticate(reason: 'bio_unlock_reason'.tr());
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      } else {
        // fallback
        final bool passEnabled = st['passcodeEnabled'] == true;
        final String ph = (st['passcodeHash'] as String? ?? '').trim();
        if (passEnabled && ph.isNotEmpty) {
          Navigator.of(context).pushReplacementNamed('/passcode');
        } else {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'bio_failed'.tr(namedArgs: {'e': '$e'}); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth_biometric_title'.tr())),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy) const CircularProgressIndicator(),
                if (!_busy) const Icon(Icons.fingerprint, size: 64),
                const SizedBox(height: 12),
                Text(_busy ? 'auth_biometric_authenticating'.tr() : 'auth_biometric_prompt'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _busy ? null : _run, child: Text('common_retry'.tr())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

