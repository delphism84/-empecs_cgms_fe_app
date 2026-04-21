import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class Sc0101PermissionRangeScreen extends StatefulWidget {
  const Sc0101PermissionRangeScreen({super.key});

  @override
  State<Sc0101PermissionRangeScreen> createState() => _Sc0101PermissionRangeScreenState();
}

class _Sc0101PermissionRangeScreenState extends State<Sc0101PermissionRangeScreen> {
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
    final st = await SettingsStorage.load();
    st['sc0101Consent'] = _consent;
    st['sc0101Low'] = _low;
    st['sc0101High'] = _high;

    // Slide5: Low/High 알람 기준값 변경·저장 반영 (local-first).
    // AlertEngine은 alarmsCache(또는 서버 alarms)를 기준으로 평가하므로, 여기서도 alarmsCache를 함께 갱신한다.
    try {
      final List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
          ? (st['alarmsCache'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      void upsert(String type, num threshold) {
        final int idx = list.indexWhere((e) => (e['type'] ?? '').toString() == type);
        if (idx >= 0) {
          list[idx] = {...list[idx], 'threshold': threshold};
        } else {
          list.add({
            '_id': 'local:$type',
            'type': type,
            'enabled': true,
            'threshold': threshold,
            'sound': true,
            'vibrate': true,
            'repeatMin': 10,
            'quietFrom': '22:00',
            'quietTo': '07:00',
          });
        }
      }
      upsert('low', _low);
      upsert('high', _high);
      st['alarmsCache'] = list;
      st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
      AlertEngine().invalidateAlarmsCache();
    } catch (_) {}

    await SettingsStorage.save(st);
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

