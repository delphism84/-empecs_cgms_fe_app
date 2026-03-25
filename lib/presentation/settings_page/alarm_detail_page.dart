import 'dart:async';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/focus_bus.dart';

class AlarmDetailPage extends StatefulWidget {
  const AlarmDetailPage({
    super.key,
    required this.alarm,
    this.title,
    this.fixedType,
    this.hideTypePicker = false,
  });
  final Map<String, dynamic> alarm;
  final String? title;
  final String? fixedType;
  final bool hideTypePicker;
  @override
  State<AlarmDetailPage> createState() => _AlarmDetailPageState();
}

class _AlarmDetailPageState extends State<AlarmDetailPage> {
  final SettingsService _svc = SettingsService();
  late String _type;
  bool _enabled = true;
  bool _sound = true;
  bool _vibrate = true;
  bool _overrideDnd = false;
  int _repeatMin = 10;
  late TextEditingController _threshold;
  late TextEditingController _quietFrom;
  late TextEditingController _quietTo;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _type = (widget.fixedType ?? (a['type'] ?? 'high')).toString();
    _enabled = a['enabled'] == true;
    _sound = (a['sound'] is bool) ? (a['sound'] == true) : true;
    _vibrate = (a['vibrate'] is bool) ? (a['vibrate'] == true) : true;
    _overrideDnd = a['overrideDnd'] == true;
    _repeatMin = (a['repeatMin'] is num) ? (a['repeatMin'] as num).toInt() : 10;
    _threshold = TextEditingController(text: (a['threshold'] ?? '').toString());
    _quietFrom = TextEditingController(text: (a['quietFrom'] ?? '').toString());
    _quietTo = TextEditingController(text: (a['quietTo'] ?? '').toString());
  }

  @override
  void dispose() {
    _threshold.dispose();
    _quietFrom.dispose();
    _quietTo.dispose();
    super.dispose();
  }

  Future<void> _saveLocalCache() async {
    try {
      final id = (widget.alarm['_id'] ?? '').toString();
      final bool enabled = _type == 'system' ? true : _enabled;
      final Map<String, dynamic> one = {
        '_id': id.isEmpty ? 'local:$_type' : id,
        'type': _type,
        'enabled': enabled,
        if (_type != 'system') 'threshold': num.tryParse(_threshold.text),
        'quietFrom': _quietFrom.text.trim(),
        'quietTo': _quietTo.text.trim(),
        'sound': _sound,
        'vibrate': _vibrate,
        'repeatMin': _repeatMin,
        if (_type == 'very_low') 'overrideDnd': _overrideDnd,
      };
      final st = await SettingsStorage.load();
      final List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
          ? (st['alarmsCache'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      final int idx = list.indexWhere((e) => (e['type'] ?? '').toString() == _type);
      if (idx >= 0) list[idx] = {...list[idx], ...one};
      else list.add(one);
      st['alarmsCache'] = list;
      st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
      AlertEngine().invalidateAlarmsCache();
      AppSettingsBus.notify(); // 메인 차트 고/저 라인(AR_01_03/AR_01_04) 즉시 반영
    } catch (_) {}
  }

  Future<void> _save() async {
    final id = (widget.alarm['_id'] ?? '').toString();
    // AR_01_06: system/signal loss는 On/Off 토글 삭제(항상 enabled로 저장)
    final bool enabled = _type == 'system' ? true : _enabled;
    // 1) local-first: apply immediately even when backend is unavailable
    await _saveLocalCache();
    // 2) best-effort server update
    if (id.isNotEmpty && !id.startsWith('local:')) {
      // 네트워크가 느릴 때도 UI 전환(저장 완료/화면 닫기)은 즉시 처리.
      unawaited(() async {
        try {
          await _svc.updateAlarm(id, {
            'type': _type,
            'enabled': enabled,
            'threshold': num.tryParse(_threshold.text),
            'quietFrom': _quietFrom.text.trim(),
            'quietTo': _quietTo.text.trim(),
            'sound': _sound,
            'vibrate': _vibrate,
            'repeatMin': _repeatMin,
            if (_type == 'very_low') 'overrideDnd': _overrideDnd,
          });
        } catch (_) {}
      }());
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSystem = _type == 'system';
    final bool isVeryLow = _type == 'very_low';
    final bool isRate = _type == 'rate';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? _titleForType(_type)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _section(
              title: 'Alarm',
              subtitle: 'Type and status',
              child: Column(
                children: [
                  if (!widget.hideTypePicker) _typePicker(),
                  if (widget.hideTypePicker)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category),
                      title: Text(_titleForType(_type), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Type: $_type'),
                    ),
                  if (!isSystem)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  if (isSystem)
                    const ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text('Signal loss alarm is always enabled'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Threshold',
              subtitle: 'Alert threshold',
              child: isSystem
                  ? const Text('No threshold for system/signal loss alarm.')
                  : Column(
                      children: [
                        if (!isRate) _textField(label: 'Threshold', controller: _threshold, icon: Icons.straighten, keyboardType: TextInputType.number),
                        if (isRate) _ratePicker(),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Repeat',
              subtitle: 'Alarm repeat interval (minutes)',
              child: _repeatPicker(),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Method',
              subtitle: 'Sound / Vibration',
              child: Column(
                children: [
                  _modePicker(),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sound'),
                    secondary: const Icon(Icons.volume_up),
                    value: _sound,
                    onChanged: (v) => setState(() => _sound = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vibration'),
                    secondary: const Icon(Icons.vibration),
                    value: _vibrate,
                    onChanged: (v) => setState(() => _vibrate = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isVeryLow)
              _section(
                title: 'Override Do Not Disturb',
                subtitle: 'AR_01_02 only',
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Override DND'),
                  secondary: const Icon(Icons.do_not_disturb_off),
                  value: _overrideDnd,
                  onChanged: (v) => setState(() => _overrideDnd = v),
                ),
              ),
            if (isVeryLow) const SizedBox(height: 12),
            _section(
              title: 'Quiet hours',
              subtitle: 'Do-not-disturb period',
              child: Column(
                children: [
                  _textField(label: 'From (HH:mm)', controller: _quietFrom, icon: Icons.schedule),
                  const SizedBox(height: 10),
                  _textField(label: 'To (HH:mm)', controller: _quietTo, icon: Icons.schedule),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('SAVE'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final Color border = isDark ? Colors.white24 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Setup(Settings) UI와 비슷한 밀도/폰트 크기(과도하게 크지 않게)
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _typePicker() {
    final items = const ['very_low', 'low', 'high', 'rate', 'system'];
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(
        labelText: 'Type',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(_titleForType(e)))).toList(),
      onChanged: (v) => setState(() => _type = v ?? _type),
    );
  }

  String _titleForType(String type) {
    switch (type) {
      case 'very_low':
        return 'Very Low';
      case 'low':
        return 'Low';
      case 'high':
        return 'High';
      case 'rate':
        return 'Rapid Change';
      case 'system':
        return 'Signal Loss';
      default:
        return type;
    }
  }

  Widget _repeatPicker() {
    const items = [1, 5, 10, 15, 30, 60];
    return DropdownButtonFormField<int>(
      value: _repeatMin,
      decoration: const InputDecoration(
        labelText: 'Repeat',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<int>(value: e, child: Text('$e min'))).toList(),
      onChanged: (v) => setState(() => _repeatMin = v ?? _repeatMin),
    );
  }

  Widget _ratePicker() {
    const items = [2, 3];
    return DropdownButtonFormField<int>(
      value: int.tryParse(_threshold.text) ?? 2,
      decoration: const InputDecoration(
        labelText: 'Rapid change (mg/dL/min)',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<int>(value: e, child: Text('$e'))).toList(),
      onChanged: (v) => setState(() => _threshold.text = (v ?? 2).toString()),
    );
  }

  Widget _modePicker() {
    // UX: 모드 선택 시 sound/vibrate 토글을 동기화해준다.
    final String mode = _sound && _vibrate ? 'Sound+Vibration' : _sound ? 'Sound Only' : _vibrate ? 'Vibration Only' : 'Silent';
    const items = ['Sound+Vibration', 'Sound Only', 'Vibration Only', 'Silent'];
    return DropdownButtonFormField<String>(
      value: mode,
      decoration: const InputDecoration(
        labelText: 'Mode',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: (v) {
        final m = v ?? mode;
        setState(() {
          if (m == 'Sound+Vibration') {
            _sound = true;
            _vibrate = true;
          } else if (m == 'Sound Only') {
            _sound = true;
            _vibrate = false;
          } else if (m == 'Vibration Only') {
            _sound = false;
            _vibrate = true;
          } else {
            _sound = false;
            _vibrate = false;
          }
        });
      },
    );
  }

  Widget _textField({required String label, required TextEditingController controller, required IconData icon, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }
}


