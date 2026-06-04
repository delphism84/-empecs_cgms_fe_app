import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';

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
                    await BleService().disconnect(clearPersistentPairing: false);
                  } catch (_) {}
                  try {
                    await GlucoseLocalRepo().clear();
                    await EventLocalRepo().clear();
                    IngestQueueService().clear();
                  } catch (_) {}
                  try {
                    await SettingsStorage.save(<String, dynamic>{
                      'authToken': '',
                      'lastUserId': '',
                      'displayName': 'Guest',
                      'guestMode': false,
                      'biometricEnabled': false,
                      'lastTrid': 0,
                      'lastServerUploadedTrid': 0,
                      'lastEvid': 0,
                      'savedLoginEmail': '',
                      'savedLoginPassword': '',
                      'offlineLastLoginEmail': '',
                      'offlinePwSaltHex': '',
                      'offlinePwHashHex': '',
                    });
                    await ApiClient().loadToken();
                    try {
                      DataSyncBus().emitGlucoseBulk(count: 0);
                      DataSyncBus().emitEventBulk(count: 0);
                    } catch (_) {}
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
