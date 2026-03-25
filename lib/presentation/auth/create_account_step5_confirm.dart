import 'package:flutter/material.dart';
import 'package:helpcare/presentation/auth/lo_02_signup_flow_screens.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// Create Account Step 5: Confirmation & Permissions (local-only signup)
class CreateAccountStep5ConfirmPage extends StatelessWidget {
  const CreateAccountStep5ConfirmPage({super.key});

  Future<void> _createAccount(BuildContext context) async {
    try {
      final st = await SettingsStorage.load();
      final email = (st['signupDraftEmail'] as String? ?? '').toString().trim();
      final firstName = (st['signupDraftFirstName'] as String? ?? '').toString().trim();
      final lastName = (st['signupDraftLastName'] as String? ?? '').toString().trim();
      if (email.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email is required.')));
        }
        return;
      }
      final displayName = '$firstName $lastName'.trim();
      st['lastUserId'] = email;
      st['displayName'] = displayName.isEmpty ? email : displayName;
      st['authToken'] = 'local-${DateTime.now().millisecondsSinceEpoch}';
      st['guestMode'] = false;
      for (final k in ['signupDraftEmail', 'signupDraftFirstName', 'signupDraftLastName', 'signupDraftDob', 'signupDraftGender', 'signupDraftUnit']) {
        st.remove(k);
      }
      await SettingsStorage.save(st);
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Lo0205SignUpCompleteScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Account Creation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('We will create your account with the provided information. Required permissions:'),
            const SizedBox(height: 16),
            const _PermTile(icon: Icons.location_on, title: 'Location', desc: 'May be required for BLE scan and device connection.'),
            const _PermTile(icon: Icons.bluetooth, title: 'Bluetooth', desc: 'Required for communication with the sensor.'),
            const _PermTile(icon: Icons.notifications, title: 'Notifications', desc: 'Needed to deliver glucose alerts and warnings.'),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _createAccount(context),
              child: const Text('Create Account'),
            )
          ],
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


