import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User detail page: shows user info and Logout button
class UserDetailPage extends StatelessWidget {
  const UserDetailPage({
    super.key,
    required this.displayName,
    required this.email,
  });
  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _section(context, title: 'Account', children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Name'),
                subtitle: Text(displayName.isEmpty ? '—' : displayName),
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(email.isEmpty ? '—' : email),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Logout'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  try {
                    await BleService().disconnect();
                  } catch (_) {}
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('cgms.last_mac');
                    await prefs.remove('cgms.last_name');
                  } catch (_) {}
                  try {
                    final s = await SettingsStorage.load();
                    s['authToken'] = '';
                    s['lastUserId'] = '';
                    s['displayName'] = 'Guest';
                    s['guestMode'] = false;
                    s['biometricEnabled'] = false;
                    s['eqsn'] = '';
                    s['registeredDevices'] = <Map<String, dynamic>>[];
                    await SettingsStorage.save(s);
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, {required String title, required List<Widget> children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final Color border = isDark ? Colors.white24 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
