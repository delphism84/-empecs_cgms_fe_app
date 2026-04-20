import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:helpcare/presentation/auth/lo_02_signup_flow_screens.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';
import 'package:helpcare/core/utils/auth_response_parser.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Create Account Step 5: Confirmation & Permissions (local-first signup, server sync when online)
class CreateAccountStep5ConfirmPage extends StatefulWidget {
  const CreateAccountStep5ConfirmPage({super.key});

  @override
  State<CreateAccountStep5ConfirmPage> createState() => _CreateAccountStep5ConfirmPageState();
}

class _CreateAccountStep5ConfirmPageState extends State<CreateAccountStep5ConfirmPage> {
  bool _busy = false;

  Future<void> _createAccount() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final st = await SettingsStorage.load();
      final email = (st['signupDraftEmail'] as String? ?? '').toString().trim();
      final firstName = (st['signupDraftFirstName'] as String? ?? '').toString().trim();
      final lastName = (st['signupDraftLastName'] as String? ?? '').toString().trim();
      final password = (st['signupDraftPassword'] as String? ?? '').toString();
      final dob = (st['signupDraftDob'] as String? ?? '').toString().trim();
      if (email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email is required.')));
        }
        return;
      }
      final displayName = '$firstName $lastName'.trim();
      st['lastUserId'] = email;
      st['displayName'] = displayName.isEmpty ? email : displayName;
      st['authToken'] = 'local-${DateTime.now().millisecondsSinceEpoch}';
      st['guestMode'] = false;
      for (final k in [
        'signupDraftEmail',
        'signupDraftFirstName',
        'signupDraftLastName',
        'signupDraftDob',
        'signupDraftGender',
        'signupDraftUnit',
        'signupDraftPassword',
      ]) {
        st.remove(k);
      }
      // 신규 회원가입: 이전 게스트/세션의 센서 메타·BLE MAC 제거 (req 1-7)
      st['sensorStartAt'] = '';
      st['sensorStartAtEqsn'] = '';
      st['eqsn'] = '';
      st['lastTrid'] = 0;
      st['sc0106WarmupDoneAt'] = '';
      st['sc0106WarmupActive'] = false;
      st['sc0106WarmupEqsn'] = '';
      st['registeredDevices'] = <Map<String, dynamic>>[];
      st['lastScannedQrRaw'] = '';
      st['lastScannedQrFullSn'] = '';
      st['lastScannedQrSerial'] = '';
      st['lastScannedQrAt'] = '';
      st['lastScannedQrRegistered'] = false;
      st['lastScannedQrMac'] = '';
      await SettingsStorage.save(st);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cgms.last_mac');
        await prefs.remove('cgms.last_name');
      } catch (_) {}
      try {
        AppSettingsBus.notify();
      } catch (_) {}

      if (email.isNotEmpty && password.length >= 8) {
        try {
          final api = ApiClient();
          final resp = await api.post('/api/auth/register', body: {
            'email': email,
            'password': password,
            'firstName': firstName.isNotEmpty ? firstName : 'User',
            'lastName': lastName.isNotEmpty ? lastName : 'User',
            if (dob.length >= 10) 'dateOfBirth': dob.substring(0, 10),
            'agreeTerms': true,
          });
          if (resp.statusCode == 201) {
            final raw = jsonDecode(resp.body);
            final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            final token = AuthResponseParser.pickToken(AuthResponseParser.normalizeLoginEnvelope(data));
            if (token != null && token.isNotEmpty) {
              await api.saveToken(token);
              final s2 = await SettingsStorage.load();
              s2['authToken'] = token;
              await SettingsStorage.save(s2);
              await ProfileSyncService.refreshFromServer();
              try {
                AppSettingsBus.notify();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Lo0205SignUpCompleteScreen()),
        (r) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Account Creation')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('We will create your account with the provided information. Required permissions:'),
              const SizedBox(height: 16),
              const _PermTile(icon: Icons.location_on, title: 'Location', desc: 'May be required for BLE scan and device connection.'),
              const _PermTile(icon: Icons.bluetooth, title: 'Bluetooth', desc: 'Required for communication with the sensor.'),
              const _PermTile(icon: Icons.notifications, title: 'Notifications', desc: 'Needed to deliver glucose alerts and warnings.'),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _createAccount,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _PermTile({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(desc),
    );
  }
}
