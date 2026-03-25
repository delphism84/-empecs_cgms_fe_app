import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// AR_01_08: 잠금화면 배너(상태) 알림 설정
class Ar0108LockScreenScreen extends StatefulWidget {
  const Ar0108LockScreenScreen({super.key});

  @override
  State<Ar0108LockScreenScreen> createState() => _Ar0108LockScreenScreenState();
}

class _Ar0108LockScreenScreenState extends State<Ar0108LockScreenScreen> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await SettingsStorage.load();
      final bool v = s['ar0108Enabled'] != false;
      if (!mounted) return;
      setState(() => _enabled = v);
    } catch (_) {}
  }

  Future<void> _save(bool v) async {
    setState(() => _enabled = v);
    try {
      final s = await SettingsStorage.load();
      s['ar0108Enabled'] = v;
      s['ar0108UpdatedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _preview() async {
    try {
      await NotificationService().showLockScreenGlucose(value: 123, trend: '↗', unit: 'mg/dL');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lock screen banner updated (sample)')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview failed')));
    }
  }

  static const _kMinTouchTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionBg = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final Color sectionBorder = isDark ? Colors.white24 : Colors.black12;
    return Scaffold(
      appBar: AppBar(title: const Text('AR_01_08 · Lock screen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sectionBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lock screen banner',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Show or hide the lock screen glucose banner. This setting is independent of the global notification toggle.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Show lock screen banner',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Switch.adaptive(value: _enabled, onChanged: _save),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: _kMinTouchTarget + 8,
              child: OutlinedButton(onPressed: _preview, child: const Text('Preview sample')),
            ),
          ],
        ),
      ),
    );
  }
}

