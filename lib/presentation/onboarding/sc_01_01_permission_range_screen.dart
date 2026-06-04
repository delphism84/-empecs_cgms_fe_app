import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Sc0101PermissionRangeScreen extends StatefulWidget {
  const Sc0101PermissionRangeScreen({super.key});

  @override
  State<Sc0101PermissionRangeScreen> createState() => _Sc0101PermissionRangeScreenState();
}

class _Sc0101PermissionRangeScreenState extends State<Sc0101PermissionRangeScreen> {
  final SettingsService _svc = SettingsService();
  bool _consent = false;
  int _low = 70;
  int _high = 180;
  String? _feedbackKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      setState(() {
        _consent = st['sc0101Consent'] == true;
        _low = ((st['sc0101Low'] as num?)?.toInt() ?? 70).clamp(40, 120);
        _high = ((st['sc0101High'] as num?)?.toInt() ?? 180).clamp(120, 300);
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_consent) {
      setState(() { _feedbackKey = 'perm_agree_first'; });
      return;
    }
    if (_low >= _high) {
      setState(() { _feedbackKey = 'perm_invalid_range'; });
      return;
    }
    // SC_01_01 값은 부분 저장으로 기록.
    try {
      await SettingsStorage.save(<String, dynamic>{
        'sc0101Consent': _consent,
        'sc0101Low': _low,
        'sc0101High': _high,
      });
    } catch (_) {}

    // Low/High 알람 임계값은 SettingsService 단일 저장 경로로 갱신한다.
    try {
      await _svc.upsertAlarmByType('low', <String, dynamic>{
        'type': 'low',
        'threshold': _low,
      });
      await _svc.upsertAlarmByType('high', <String, dynamic>{
        'type': 'high',
        'threshold': _high,
      });
      AlertEngine().invalidateAlarmsCache();
    } catch (_) {}

    ChartThresholdBus.notify();
    setState(() { _feedbackKey = 'perm_saved'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('perm_appbar'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('perm_alert_consent_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() { _consent = v == true; }),
            title: Text('perm_alert_receive_title'.tr()),
            subtitle: Text('perm_required_subtitle'.tr()),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          Text('perm_alarm_range_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ListTile(
            title: Text('perm_low_threshold'.tr()),
            trailing: Text('$_low'),
            subtitle: Slider(
              value: _low.toDouble(),
              min: 40,
              max: 120,
              divisions: 80,
              label: '$_low',
              onChanged: (v) => setState(() { _low = v.round().clamp(40, 120); if (_low >= _high) _high = (_low + 1).clamp(120, 300); }),
            ),
          ),
          ListTile(
            title: Text('perm_high_threshold'.tr()),
            trailing: Text('$_high'),
            subtitle: Slider(
              value: _high.toDouble(),
              min: 120,
              max: 300,
              divisions: 180,
              label: '$_high',
              onChanged: (v) => setState(() { _high = v.round().clamp(120, 300); if (_high <= _low) _low = (_high - 1).clamp(40, 120); }),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _save,
            child: Text('perm_save'.tr()),
          ),
          if (_feedbackKey != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedbackKey!.tr(),
              style: TextStyle(
                color: _feedbackKey == 'perm_saved' ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

