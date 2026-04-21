import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:easy_localization/easy_localization.dart';

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
      if (v) {
        await _syncBannerFromLatestGlucose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ar0108_snack_on'.tr())),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _syncBannerFromLatestGlucose() async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      final row = await GlucoseLocalRepo().latestPoint(eqsn: eqsn.isEmpty ? null : eqsn);
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl') == 'mmol' ? 'mmol/L' : 'mg/dL';
      final double val = row != null ? ((row['value'] as num?) ?? 0).toDouble() : double.nan;
      final int ms = (row?['time_ms'] as int?) ?? 0;
      final DateTime at = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal() : DateTime.now();
      final String trend = await GlucoseLocalRepo().lockScreenTrendArrow(eqsn: null);
      await NotificationService().showLockScreenGlucose(value: val, trend: trend, unit: u, measuredAt: at);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionBg = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final Color sectionBorder = isDark ? Colors.white24 : Colors.black12;
    return Scaffold(
      appBar: AppBar(title: Text('ar0108_title'.tr())),
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
                    'ar0108_banner_title'.tr(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ar0108_banner_desc'.tr(),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ar0108_show_banner'.tr(),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Switch.adaptive(value: _enabled, onChanged: _save),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

