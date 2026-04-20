import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/signal_loss_monitor_log.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:easy_localization/easy_localization.dart';

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
    _repeatMin = SettingsService.parseAlarmRepeatMinutes(a['repeatMin']);
    final dynamic thRaw = a['threshold'];
    final String thStr = (thRaw == null) ? '' : thRaw.toString();
    String thInitial = thStr;
    if (_type == 'system') {
      final num? n = thRaw is num ? thRaw : num.tryParse(thStr.trim());
      thInitial = (n != null) ? n.toString() : '-88';
    }
    _threshold = TextEditingController(text: thInitial);
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
      final Map<String, dynamic> one = {
        '_id': id.isEmpty ? 'local:$_type' : id,
        'type': _type,
        'enabled': _enabled,
        'quietFrom': _quietFrom.text.trim(),
        'quietTo': _quietTo.text.trim(),
        'sound': _sound,
        'vibrate': _vibrate,
        'repeatMin': _repeatMin,
        if (_type == 'very_low') 'overrideDnd': _overrideDnd,
      };
      if (_type == 'system') {
        one['threshold'] = -88;
      } else if (_type == 'rate') {
        one['threshold'] = num.tryParse(_threshold.text.trim()) ?? 2;
      } else {
        final p = num.tryParse(_threshold.text.trim());
        if (p != null) {
          one['threshold'] = p;
        }
      }
      final st = await SettingsStorage.load();
      final List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
          ? (st['alarmsCache'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      final int idx = list.indexWhere((e) => (e['type'] ?? '').toString() == _type);
      if (idx >= 0) {
        list[idx] = {...list[idx], ...one};
      } else {
        list.add(one);
      }
      st['alarmsCache'] = list;
      st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
      AlertEngine().invalidateAlarmsCache();
      if (_type == 'system') {
        BleService().rescheduleSignalLossRepeatsIfDisconnected();
      }
      AppSettingsBus.notify(); // 메인 차트 고/저 라인(AR_01_03/AR_01_04) 즉시 반영
    } catch (_) {}
  }

  Future<void> _save() async {
    final id = (widget.alarm['_id'] ?? '').toString();
    final num? thresholdServer = _type == 'system'
        ? -88
        : (_type == 'rate'
            ? (num.tryParse(_threshold.text.trim()) ?? 2)
            : num.tryParse(_threshold.text.trim()));
    // 1) local-first: apply immediately even when backend is unavailable
    await _saveLocalCache();
    // 2) best-effort server update
    if (id.isNotEmpty && !id.startsWith('local:')) {
      // 네트워크가 느릴 때도 UI 전환(저장 완료/화면 닫기)은 즉시 처리.
      unawaited(() async {
        try {
          await _svc.updateAlarm(id, {
            'type': _type,
            'enabled': _enabled,
            'threshold': thresholdServer,
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

  Future<void> _testSignalAlert() async {
    if (!_sound && !_vibrate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('alarm_detail_sound_vibration_off'.tr())),
      );
      return;
    }
    if (_sound) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    if (_vibrate) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 120));
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    // Also emit one preview notification for channel-level verification.
    await NotificationService().showAlert(
      id: 1099,
      title: 'Signal Loss Test',
      body: 'Sound=${_sound ? 'ON' : 'OFF'}, Vibration=${_vibrate ? 'ON' : 'OFF'}',
      payload: 'preview:system',
      critical: false,
      sound: _sound,
      vibrate: _vibrate,
    );
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
              title: 'alarm_section_alarm'.tr(),
              subtitle: 'alarm_section_alarm_sub'.tr(),
              child: Column(
                children: [
                  if (!widget.hideTypePicker) _typePicker(),
                  if (widget.hideTypePicker)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category),
                      title: Text(_titleForType(_type), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${'alarm_detail_type'.tr()}: $_type'),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('alarm_detail_enabled'.tr()),
                    subtitle: isSystem ? Text('alarm_detail_system_disabled_sub'.tr()) : null,
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!isSystem)
              _section(
                title: 'alarm_section_threshold'.tr(),
                subtitle: 'alarm_section_threshold_sub'.tr(),
                child: Column(
                  children: [
                    if (!isRate) _textField(label: 'alarm_section_threshold'.tr(), controller: _threshold, icon: Icons.straighten, keyboardType: TextInputType.number),
                    if (isRate) _ratePicker(),
                  ],
                ),
              ),
            if (!isSystem) const SizedBox(height: 12),
            _section(
              title: 'alarm_section_repeat'.tr(),
              subtitle: 'alarm_section_repeat_sub'.tr(),
              child: _repeatPicker(),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'alarm_section_method'.tr(),
              subtitle: 'alarm_section_method_sub'.tr(),
              child: Column(
                children: [
                  _modePicker(),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('alarm_detail_sound'.tr()),
                    secondary: const Icon(Icons.volume_up),
                    value: _sound,
                    onChanged: (v) => setState(() => _sound = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('alarm_detail_vibration'.tr()),
                    secondary: const Icon(Icons.vibration),
                    value: _vibrate,
                    onChanged: (v) => setState(() => _vibrate = v),
                  ),
                  if (isSystem)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_fill),
                      title: Text('alarm_detail_test_signal'.tr()),
                      subtitle: Text('alarm_detail_test_signal_sub'.tr()),
                      onTap: _testSignalAlert,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isVeryLow)
              _section(
                title: 'alarm_section_override_title'.tr(),
                subtitle: 'alarm_section_override_sub'.tr(),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('alarm_detail_override_dnd'.tr()),
                  secondary: const Icon(Icons.do_not_disturb_off),
                  value: _overrideDnd,
                  onChanged: (v) => setState(() => _overrideDnd = v),
                ),
              ),
            if (isVeryLow) const SizedBox(height: 12),
            _section(
              title: 'alarm_section_quiet'.tr(),
              subtitle: 'alarm_section_quiet_sub'.tr(),
              child: Column(
                children: [
                  _textField(label: 'alarm_quiet_from'.tr(), controller: _quietFrom, icon: Icons.schedule),
                  const SizedBox(height: 10),
                  _textField(label: 'alarm_quiet_to'.tr(), controller: _quietTo, icon: Icons.schedule),
                ],
              ),
            ),
            if (isSystem) ...[
              const SizedBox(height: 12),
              _ar0106BehaviorGuide(),
              const SizedBox(height: 12),
              _signalLossLogSection(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text('alarm_detail_save'.tr()),
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
      decoration: InputDecoration(
        labelText: 'alarm_field_type_label'.tr(),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(_titleForType(e)))).toList(),
      onChanged: (v) => setState(() => _type = v ?? _type),
    );
  }

  String _titleForType(String type) {
    switch (type) {
      case 'very_low':
        return 'alarm_type_very_low'.tr();
      case 'low':
        return 'alarm_type_low'.tr();
      case 'high':
        return 'alarm_type_high'.tr();
      case 'rate':
        return 'alarm_type_rate'.tr();
      case 'system':
        return 'alarm_type_system'.tr();
      default:
        return type;
    }
  }

  Widget _repeatPicker() {
    const items = [1, 5, 10, 15, 30, 60];
    return DropdownButtonFormField<int>(
      value: _repeatMin,
      decoration: InputDecoration(
        labelText: 'alarm_field_repeat_label'.tr(),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      items: items.map((e) => DropdownMenuItem<int>(value: e, child: Text('$e ${'common_min'.tr()}'))).toList(),
      onChanged: (v) => setState(() => _repeatMin = v ?? _repeatMin),
    );
  }

  Widget _ratePicker() {
    const items = [2, 3];
    return DropdownButtonFormField<int>(
      value: int.tryParse(_threshold.text) ?? 2,
      decoration: InputDecoration(
        labelText: 'alarm_field_rapid'.tr(),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
      decoration: InputDecoration(
        labelText: 'alarm_field_mode_label'.tr(),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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

  static const String _ar0106Help = 'AR_01_06 · Signal loss (link lost only).\n'
      'Alerts do not fire until the CGM measurement notify subscription has succeeded at least once.\n\n'
      'When the Bluetooth connection drops (out of range, timeout, etc.), a signal loss alert is evaluated.\n'
      'Weak RSSI while still connected is not used (req 1-2).\n\n'
      'Repeat interval applies to signal loss re-notifications while the link stays down.\n'
      'Quiet hours suppress sound/vibration; the app must not exit (req 1-3).\n\n'
      'During sensor warm-up (SC_01_06), these alerts are suppressed.';

  Widget _ar0106BehaviorGuide() {
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text('alarm_detail_signal_help_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(_ar0106Help, style: TextStyle(fontSize: 13, height: 1.35, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
        ),
      ],
    );
  }

  Widget _signalLossLogSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _section(
      title: 'alarm_log_section_title'.tr(),
      subtitle: 'alarm_log_section_sub'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => SignalLossMonitorLog.clear(),
              child: Text('alarm_detail_clear_log'.tr()),
            ),
          ),
          ValueListenableBuilder<List<String>>(
            valueListenable: SignalLossMonitorLog.lines,
            builder: (_, lines, __) {
              return Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: lines.isEmpty
                    ? Center(
                        child: Text(
                          'alarm_log_empty'.tr(),
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: lines.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            lines[i],
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.25),
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      readOnly: false,
      enableInteractiveSelection: true,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }
}


