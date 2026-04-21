import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// AR_01_01: 무음모드 설정(모든 알람 무음)
class Ar0101MuteAllScreen extends StatefulWidget {
  const Ar0101MuteAllScreen({super.key});

  @override
  State<Ar0101MuteAllScreen> createState() => _Ar0101MuteAllScreenState();
}

class _Ar0101MuteAllScreenState extends State<Ar0101MuteAllScreen> {
  bool muteAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await SettingsStorage.load();
      if (!mounted) return;
      setState(() => muteAll = s['alarmsMuteAll'] == true);
    } catch (_) {}
  }

  Future<void> _save(bool v) async {
    setState(() => muteAll = v);
    try {
      final s = await SettingsStorage.load();
      s['alarmsMuteAll'] = v;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionBg = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final Color sectionBorder = isDark ? Colors.white24 : Colors.black12;
    return Scaffold(
      appBar: AppBar(title: Text('alarm_mute_all_title'.tr())),
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
                    'alarm_mute_all_heading'.tr(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'alarm_mute_all_body'.tr(),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'alarm_mute_all_heading'.tr(),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Switch.adaptive(value: muteAll, onChanged: _save),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For QA/bot: trigger an alarm via /emu/app/alarm/system and check lastAlert.sound/vibrate=false.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

