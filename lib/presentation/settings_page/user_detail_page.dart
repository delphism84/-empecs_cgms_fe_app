import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      appBar: AppBar(title: Text('user_detail_appbar'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _section(context, title: 'user_detail_account_section'.tr(), children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text('common_name'.tr()),
                subtitle: Text(displayName.isEmpty ? '—' : displayName),
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: Text('common_email'.tr()),
                subtitle: Text(email.isEmpty ? '—' : email),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 20),
                label: Text('common_logout'.tr()),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('auth_logout_confirm_title'.tr()),
                      content: Text('auth_logout_confirm_body'.tr()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('common_cancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('common_logout'.tr()),
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
                    s['sensorStartAt'] = '';
                    s['sensorStartAtEqsn'] = '';
                    s['lastTrid'] = 0;
                    s['sc0106WarmupDoneAt'] = '';
                    s['sc0106WarmupActive'] = false;
                    s['sc0106WarmupEqsn'] = '';
                    s['registeredDevices'] = <Map<String, dynamic>>[];
                    s['lastScannedQrRaw'] = '';
                    s['lastScannedQrFullSn'] = '';
                    s['lastScannedQrSerial'] = '';
                    s['lastScannedQrAt'] = '';
                    s['lastScannedQrRegistered'] = false;
                    s['lastScannedQrMac'] = '';
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
