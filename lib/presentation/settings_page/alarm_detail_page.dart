import 'dart:async';
import 'dart:developer';
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
  bool _saving = false;
  int _repeatMin = 10;
  late TextEditingController _threshold;
  late TextEditingController _quietFrom;
  late TextEditingController _quietTo;

  // 혈당 임계값은 저장/비교가 항상 mg/dL 기준(AlertEngine 계약). 화면은 사용자 단위로 표시/입력.
  static const double _mmolFactor = 18.02;
  String _glucoseUnit = 'mgdl';
  bool get _isMmol => _glucoseUnit == 'mmol';
  bool get _isGlucoseThreshold => _type == 'high' || _type == 'low' || _type == 'very_low';
  String get _unitLabel => _isMmol ? 'mmol/L' : 'mg/dL';
  String _mgdlToDisplay(num mgdl) => _isMmol ? (mgdl / _mmolFactor).toStringAsFixed(1) : mgdl.round().toString();
  num _displayToMgdl(num shown) => _isMmol ? (shown * _mmolFactor).round() : shown;

  @override
  void initState() {
    super.initState();
    final a = Map<String, dynamic>.from(widget.alarm);
    // method 레거시 필드는 진입 시 sound/vibrate로 정규화
    if (!a.containsKey('sound') && !a.containsKey('vibrate')) {
      final String raw = (a['method'] ?? a['alertMethod'] ?? '').toString().trim().toLowerCase();
      final String norm = raw.replaceAll(RegExp(r'[\s\-+]'), '_');
      if (norm == 'sound_vibration' || norm == 'soundandvibration' || norm == 'both') {
        a['sound'] = true;
        a['vibrate'] = true;
      } else if (norm == 'sound_only' || norm == 'sound') {
        a['sound'] = true;
        a['vibrate'] = false;
      } else if (norm == 'vibration_only' || norm == 'vibrate_only' || norm == 'vibration') {
        a['sound'] = false;
        a['vibrate'] = true;
      } else if (norm == 'silent' || norm == 'none' || norm == 'off') {
        a['sound'] = false;
        a['vibrate'] = false;
      }
    }
    _type = (widget.fixedType ?? (a['type'] ?? 'high')).toString();
    _enabled = a['enabled'] == null ? true : a['enabled'] == true || a['enabled'].toString() == '1';
    _sound = a['sound'] == null ? true : a['sound'] == true || a['sound'].toString() == '1';
    _vibrate = a['vibrate'] == null ? true : a['vibrate'] == true || a['vibrate'].toString() == '1';
    _overrideDnd = a['overrideDnd'] == true;
    _repeatMin = int.tryParse('${a['repeatMin'] ?? 10}') ?? 10;
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
    unawaited(_loadUnitAndConvert());
  }

  /// 저장소의 glucoseUnit을 읽어, 혈당 임계값 필드를 mg/dL → 사용자 단위로 변환해 표시.
  Future<void> _loadUnitAndConvert() async {
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl').trim();
      if (!mounted) return;
      setState(() {
        _glucoseUnit = (u == 'mmol') ? 'mmol' : 'mgdl';
        if (_isGlucoseThreshold && _isMmol) {
          final num? raw = num.tryParse(_threshold.text.trim());
          if (raw != null) _threshold.text = _mgdlToDisplay(raw);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _threshold.dispose();
    _quietFrom.dispose();
    _quietTo.dispose();
    super.dispose();
  }

  Future<bool> _saveLocalCache() async {
    try {
      SettingsService.invalidateAlarmsMemCache();
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
        // high/low/very_low: 화면값(사용자 단위) → 저장은 항상 mg/dL 로 변환.
        final p = num.tryParse(_threshold.text.trim());
        if (p != null) {
          one['threshold'] = _isGlucoseThreshold ? _displayToMgdl(p) : p;
        }
      }
      await _svc.upsertAlarmByType(_type, one);
      AlertEngine().invalidateAlarmsCache();
      if (_type == 'system') {
        BleService().rescheduleSignalLossRepeatsIfDisconnected();
      }
      if (_type == 'high' || _type == 'low') {
        ChartThresholdBus.notify();
      }
      return true;
    } catch (e, st) {
      log('[qa][AlarmDetailPage._saveLocalCache] failed type=$_type: $e', name: 'qa', stackTrace: st);
      return false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bool ok = await _saveLocalCache();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('alarm_detail_save_failed'.tr())),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                    if (!isRate) _textField(label: '${'alarm_section_threshold'.tr()} (${_isGlucoseThreshold ? _unitLabel : 'mg/dL'})', controller: _threshold, icon: Icons.straighten, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
                onPressed: _saving ? null : _save,
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

  static const String _ar0106Help = 'Signal loss (link lost only).\n'
      'Alerts do not fire until the CGM measurement notify subscription has succeeded at least once.\n\n'
      'When the Bluetooth connection drops (out of range, timeout, etc.), a signal loss alert is evaluated.\n'
      'Weak RSSI while still connected is not used.\n\n'
      'Repeat interval applies to signal loss re-notifications while the link stays down.\n'
      'Quiet hours suppress sound/vibration; the app must not exit.\n\n'
      'During sensor warm-up, these alerts are suppressed.';

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


