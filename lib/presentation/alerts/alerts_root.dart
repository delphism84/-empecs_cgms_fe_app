import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/debug_badge.dart';
// import removed: report widgets not used in custom app fields
import 'package:helpcare/presentation/report/report_controls.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/widgets/app_fields.dart';
import 'package:helpcare/presentation/alarms/ar_01_08_lock_screen_screen.dart';
import 'package:helpcare/presentation/alarms/alarm_type_detail_page.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/widgets/gradient_icon.dart';
import 'package:easy_localization/easy_localization.dart';

class AlertsRootPage extends StatefulWidget {
  const AlertsRootPage({super.key});

  @override
  State<AlertsRootPage> createState() => _AlertsRootPageState();
}

class _AlertsRootPageState extends State<AlertsRootPage> {
  final SettingsService _svc = SettingsService();
  bool _loading = false;
  bool _notificationsEnabled = true;
  List<Map<String, dynamic>> _alarms = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    try {
      list = await _svc.listAlarms();
    } catch (_) {
      list = <Map<String, dynamic>>[];
    }
    if (list.isEmpty) {
      // local fallback
      try {
        final st = await SettingsStorage.load();
        final dynamic v = st['alarmsCache'];
        if (v is List) {
          list = v.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    bool notifOn = true;
    try {
      final st = await SettingsStorage.load();
      notifOn = (st['notificationsEnabled'] ?? true) == true;
      NotificationService().setEnabled(notifOn);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _alarms = list;
      _notificationsEnabled = notifOn;
      _loading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    NotificationService().setEnabled(enabled);
    try {
      final st = await SettingsStorage.load();
      st['notificationsEnabled'] = enabled;
      await SettingsStorage.save(st);
    } catch (_) {}
    // best-effort sync
    try {
      await _svc.updateAppSetting({
        'notifications': enabled,
        'preferences': {'notificationsEnabled': enabled},
      });
    } catch (_) {}
  }

  Map<String, dynamic> _alarmForType(String type) {
    final idx = _alarms.indexWhere((a) => (a['type'] ?? '').toString() == type);
    if (idx >= 0) return _alarms[idx];
    // seed local-only default (will be saved to cache on SAVE)
    return {
      '_id': 'local:$type',
      'type': type,
      'enabled': true,
      'threshold': type == 'system'
          ? -88
          : type == 'very_low'
              ? 55
              : type == 'low'
                  ? 70
                  : type == 'high'
                      ? 180
                      : type == 'rate'
                          ? 2
                          : null,
      'quietFrom': '22:00',
      'quietTo': '07:00',
      'sound': true,
      'vibrate': true,
      'repeatMin': 10,
      if (type == 'very_low') 'overrideDnd': true,
    };
  }

  String _subtitleFor(String type, Map<String, dynamic> a) {
    final String state = (a['enabled'] == true) ? 'common_on'.tr() : 'common_off'.tr();
    if (type == 'system') {
      return 'alerts_subtitle_ble_link'.tr(namedArgs: {'state': state});
    }
    if (type == 'rate') {
      return 'alerts_subtitle_rapid'.tr(namedArgs: {'state': state});
    }
    final int? th = (a['threshold'] is num) ? (a['threshold'] as num).toInt() : null;
    final int? repeatMin = (a['repeatMin'] is num) ? (a['repeatMin'] as num).toInt() : null;
    if (th != null && repeatMin != null) {
      return 'alerts_subtitle_threshold'.tr(namedArgs: {
        'th': '$th',
        'repeat': 'alerts_repeat_minutes'.tr(namedArgs: {'m': '$repeatMin'}),
        'state': state,
      });
    }
    if (th != null) {
      return 'alerts_subtitle_threshold_no_repeat'.tr(namedArgs: {'th': '$th', 'state': state});
    }
    if (repeatMin != null) {
      return '${'alerts_repeat_minutes'.tr(namedArgs: {'m': '$repeatMin'})} · $state';
    }
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('alerts_root_title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorConstant.indigo51, width: 1),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('alerts_all_notifications'.tr()),
                    subtitle: Text(_notificationsEnabled ? 'common_on'.tr().toUpperCase() : 'common_off'.tr().toUpperCase()),
                    value: _notificationsEnabled,
                    onChanged: _setNotificationsEnabled,
                  ),
                ),
                Text('alerts_new_section'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _alertItem(
                  context,
                  icon: Icons.priority_high,
                  title: 'alerts_title_very_low'.tr(),
                  subtitle: _subtitleFor('very_low', _alarmForType('very_low')),
                  reqId: 'AR_01_02',
                  pageBuilder: (_) => AlarmTypeDetailPage(type: 'very_low', title: 'alerts_title_very_low'.tr(), reqId: 'AR_01_02'),
                  onReturn: _load,
                ),
                _alertItem(
                  context,
                  icon: Icons.trending_up,
                  title: 'alerts_title_high'.tr(),
                  subtitle: _subtitleFor('high', _alarmForType('high')),
                  reqId: 'AR_01_03',
                  pageBuilder: (_) => AlarmTypeDetailPage(type: 'high', title: 'alerts_title_high'.tr(), reqId: 'AR_01_03'),
                  onReturn: _load,
                ),
                _alertItem(
                  context,
                  icon: Icons.trending_down,
                  title: 'alerts_title_low'.tr(),
                  subtitle: _subtitleFor('low', _alarmForType('low')),
                  reqId: 'AR_01_04',
                  pageBuilder: (_) => AlarmTypeDetailPage(type: 'low', title: 'alerts_title_low'.tr(), reqId: 'AR_01_04'),
                  onReturn: _load,
                ),
                _alertItem(
                  context,
                  icon: Icons.show_chart,
                  title: 'alerts_title_rapid'.tr(),
                  subtitle: _subtitleFor('rate', _alarmForType('rate')),
                  reqId: 'AR_01_05',
                  pageBuilder: (_) => AlarmTypeDetailPage(type: 'rate', title: 'alerts_title_rapid'.tr(), reqId: 'AR_01_05'),
                  onReturn: _load,
                ),
                _alertItem(
                  context,
                  icon: Icons.signal_cellular_off,
                  title: 'alerts_title_signal_loss'.tr(),
                  subtitle: _subtitleFor('system', _alarmForType('system')),
                  reqId: 'AR_01_06',
                  pageBuilder: (_) => AlarmTypeDetailPage(type: 'system', title: 'alerts_title_signal_loss'.tr(), reqId: 'AR_01_06'),
                  onReturn: _load,
                ),
                _alertItem(
                  context,
                  icon: Icons.lock,
                  title: 'alerts_title_lock_screen'.tr(),
                  subtitle: 'alerts_lock_subtitle'.tr(),
                  reqId: 'AR_01_08',
                  pageBuilder: (_) => const Ar0108LockScreenScreen(),
                  onReturn: _load,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorConstant.indigo51, width: 1),
                  ),
                  child: Text(
                    'alerts_footer_help'.tr(),
                    style: TextStyle(
                      color: ColorConstant.bluegray400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // removed old _tile in favor of card-style _alertItem
}

/// 레거시 QA용 화면. 제품 플로우는 [AlarmTypeDetailPage] → [AlarmDetailPage] 사용.
@Deprecated('레거시. AlarmTypeDetailPage 사용')
class VeryLowAlertPage extends StatefulWidget {
  const VeryLowAlertPage({super.key});
  @override
  State<VeryLowAlertPage> createState() => _VeryLowAlertPageState();
}

class _VeryLowAlertPageState extends State<VeryLowAlertPage> {
  bool enable = true;
  double threshold = 55; // mg/dL
  bool sound = true;
  bool vibrate = true;
  String tone = 'Default';
  double volume = 0.7;
  bool repeat = true;
  int repeatMin = 10;
  int snoozeMin = 10;
  TimeOfDay quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = const TimeOfDay(hour: 7, minute: 0);
  String priority = 'Default';
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_02 · Very Low Glucose',
      body: [
        _group(context, title: 'Basic', children: [
          AppSwitchRow(label: 'Enable alert', value: enable, onChanged: (v) => setState(() => enable = v)),
          AppSliderRow(
            label: 'Threshold (mg/dL)',
            value: threshold,
            min: 40,
            max: 80,
            divisions: 40,
            valueLabel: (v) => v.toStringAsFixed(0),
            onChanged: (v) => setState(() => threshold = v),
          ),
        ]),
        _group(context, title: 'Notification', children: [
          AppSwitchRow(label: 'Sound', value: sound, onChanged: (v) => setState(() => sound = v)),
          AppSwitchRow(label: 'Vibrate', value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
          AppCombo<String>(
            label: 'Alert tone',
            value: tone,
            items: const ['Default', 'Beep', 'Chime', 'Ring'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => tone = v),
          ),
          AppSliderRow(
            label: 'Volume (%)',
            value: volume * 100,
            min: 0,
            max: 100,
            divisions: 10,
            valueLabel: (v) => v.toStringAsFixed(0),
            onChanged: (v) => setState(() => volume = (v / 100).clamp(0, 1)),
          ),
        ]),
        _group(context, title: 'Repeat / Time', children: [
          AppSwitchRow(label: 'Repeat', value: repeat, onChanged: (v) => setState(() => repeat = v)),
          AppCombo<int>(
            label: 'Repeat interval (min)',
            value: repeatMin,
            items: const [5, 10, 15, 30],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => repeatMin = v),
          ),
          AppCombo<int>(
            label: 'Snooze (min)',
            value: snoozeMin,
            items: const [5, 10, 15, 20, 30],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => snoozeMin = v),
          ),
          ReportTimeTile(title: 'Quiet hours start', value: quietStart, onChanged: (t) => setState(() => quietStart = t)),
          ReportTimeTile(title: 'Quiet hours end', value: quietEnd, onChanged: (t) => setState(() => quietEnd = t)),
          AppCombo<String>(
            label: 'Alert priority',
            value: priority,
            items: const ['Low', 'Default', 'High'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => priority = v),
          ),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class HighAlertPage extends StatefulWidget {
  const HighAlertPage({super.key});
  @override
  State<HighAlertPage> createState() => _HighAlertPageState();
}

class _HighAlertPageState extends State<HighAlertPage> {
  bool enable = true;
  double threshold = 180;
  bool sound = true;
  bool vibrate = true;
  bool repeat = true;
  int repeatMin = 30;
  String priority = 'Default';
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_03 · High Glucose',
      body: [
        _group(context, title: 'Basic', children: [
          AppSwitchRow(label: 'Enable alert', value: enable, onChanged: (v) => setState(() => enable = v)),
          AppSliderRow(
            label: 'Threshold (mg/dL)',
            value: threshold,
            min: 140,
            max: 300,
            divisions: 160,
            valueLabel: (v) => v.toStringAsFixed(0),
            onChanged: (v) => setState(() => threshold = v),
          ),
          _SliderEditor(
            valueText: threshold.toStringAsFixed(0),
            onApply: (txt) {
              final double? v = double.tryParse(txt);
              if (v != null) setState(() => threshold = v.clamp(140, 300).toDouble());
            },
          ),
        ]),
        _group(context, title: 'Notification', children: [
          AppSwitchRow(label: 'Sound', value: sound, onChanged: (v) => setState(() => sound = v)),
          AppSwitchRow(label: 'Vibrate', value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
          AppCombo<String>(
            label: 'Alert priority',
            value: priority,
            items: const ['Low', 'Default', 'High'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => priority = v),
          ),
        ]),
        _group(context, title: 'Repeat', children: [
          AppSwitchRow(label: 'Repeat', value: repeat, onChanged: (v) => setState(() => repeat = v)),
          AppCombo<int>(
            label: 'Repeat interval (min)',
            value: repeatMin,
            items: const [15, 30, 45, 60],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => repeatMin = v),
          ),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class LowAlertPage extends StatefulWidget {
  const LowAlertPage({super.key});
  @override
  State<LowAlertPage> createState() => _LowAlertPageState();
}

class _LowAlertPageState extends State<LowAlertPage> {
  bool enable = true;
  double threshold = 70;
  bool sound = true;
  bool vibrate = true;
  bool repeat = true;
  int repeatMin = 15;
  String priority = 'Default';
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_04 · Low Glucose',
      body: [
        _group(context, title: 'Basic', children: [
          AppSwitchRow(label: 'Enable alert', value: enable, onChanged: (v) => setState(() => enable = v)),
          AppSliderRow(
            label: 'Threshold (mg/dL)',
            value: threshold,
            min: 60,
            max: 100,
            divisions: 40,
            valueLabel: (v) => v.toStringAsFixed(0),
            onChanged: (v) => setState(() => threshold = v),
          ),
          _SliderEditor(
            valueText: threshold.toStringAsFixed(0),
            onApply: (txt) {
              final double? v = double.tryParse(txt);
              if (v != null) setState(() => threshold = v.clamp(60, 100).toDouble());
            },
          ),
        ]),
        _group(context, title: 'Notification', children: [
          AppSwitchRow(label: 'Sound', value: sound, onChanged: (v) => setState(() => sound = v)),
          AppSwitchRow(label: 'Vibrate', value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
          AppCombo<String>(
            label: 'Alert priority',
            value: priority,
            items: const ['Low', 'Default', 'High'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => priority = v),
          ),
        ]),
        _group(context, title: 'Repeat', children: [
          AppSwitchRow(label: 'Repeat', value: repeat, onChanged: (v) => setState(() => repeat = v)),
          AppCombo<int>(
            label: 'Repeat interval (min)',
            value: repeatMin,
            items: const [5, 10, 15, 20],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => repeatMin = v),
          ),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class RapidChangeAlertPage extends StatefulWidget {
  const RapidChangeAlertPage({super.key});
  @override
  State<RapidChangeAlertPage> createState() => _RapidChangeAlertPageState();
}

class _RapidChangeAlertPageState extends State<RapidChangeAlertPage> {
  bool enable = true;
  double rate = 2.0; // mg/dL/min
  String direction = 'Both';
  bool sound = true;
  bool vibrate = true;
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_05 · Rapid Change',
      body: [
        _group(context, title: 'Basic', children: [
          AppSwitchRow(label: 'Enable alert', value: enable, onChanged: (v) => setState(() => enable = v)),
          AppSliderRow(
            label: 'Rate threshold (mg/dL/min)',
            value: rate,
            min: 1,
            max: 5,
            divisions: 40,
            valueLabel: (v) => v.toStringAsFixed(1),
            onChanged: (v) => setState(() => rate = v),
          ),
          _SliderEditor(
            valueText: rate.toStringAsFixed(1),
            onApply: (txt) {
              final double? v = double.tryParse(txt);
              if (v != null) setState(() => rate = v.clamp(1, 5).toDouble());
            },
          ),
          AppCombo<String>(
            label: 'Direction',
            value: direction,
            items: const ['Rise', 'Fall', 'Both'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => direction = v),
          ),
        ]),
        _group(context, title: 'Notification', children: [
          AppSwitchRow(label: 'Sound', value: sound, onChanged: (v) => setState(() => sound = v)),
          AppSwitchRow(label: 'Vibrate', value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class SignalLossAlertPage extends StatefulWidget {
  const SignalLossAlertPage({super.key});
  @override
  State<SignalLossAlertPage> createState() => _SignalLossAlertPageState();
}

class _SignalLossAlertPageState extends State<SignalLossAlertPage> {
  bool enable = true;
  int retryMin = 5;
  int timeoutMin = 2;
  bool escalate = true;
  int escalateAfter = 3;
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_06 · Signal Loss',
      body: [
        _group(context, title: 'Basic', children: [
          AppSwitchRow(label: 'Enable alert', value: enable, onChanged: (v) => setState(() => enable = v)),
          AppCombo<int>(
            label: 'Retry interval (min)',
            value: retryMin,
            items: const [1, 3, 5, 10],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => retryMin = v),
          ),
          AppCombo<int>(
            label: 'Timeout (min)',
            value: timeoutMin,
            items: const [1, 2, 3, 5],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => timeoutMin = v),
          ),
        ]),
        _group(context, title: 'Escalation', children: [
          AppSwitchRow(label: 'Escalate on repeated failures', value: escalate, onChanged: (v) => setState(() => escalate = v)),
          AppCombo<int>(
            label: 'Escalation attempts',
            value: escalateAfter,
            items: const [2, 3, 5, 8],
            labelFor: (e) => '$e',
            onChanged: (v) => setState(() => escalateAfter = v),
          ),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class LockAlertPage extends StatefulWidget {
  const LockAlertPage({super.key});
  @override
  State<LockAlertPage> createState() => _LockAlertPageState();
}

class _LockAlertPageState extends State<LockAlertPage> {
  bool showOnLock = true;
  String contentLevel = 'Summary';
  bool allowActions = false;
  bool soundOnLock = true;
  bool vibrateOnLock = true;
  @override
  Widget build(BuildContext context) {
    return _scaffoldForm(
      title: 'AR_01_08 · Lock Screen Alerts',
      body: [
        _group(context, title: 'Display', children: [
          AppSwitchRow(label: 'Show on lock screen', value: showOnLock, onChanged: (v) => setState(() => showOnLock = v)),
          AppCombo<String>(
            label: 'Visibility level',
            value: contentLevel,
            items: const ['Hidden', 'Summary', 'Full'],
            labelFor: (s) => s,
            onChanged: (v) => setState(() => contentLevel = v),
          ),
        ]), 
        _group(context, title: 'Actions', children: [
          AppSwitchRow(label: 'Allow actions on lock', value: allowActions, onChanged: (v) => setState(() => allowActions = v)),
        ]),
        _group(context, title: 'Notification', children: [
          AppSwitchRow(label: 'Sound', value: soundOnLock, onChanged: (v) => setState(() => soundOnLock = v)),
          AppSwitchRow(label: 'Vibrate', value: vibrateOnLock, onChanged: (v) => setState(() => vibrateOnLock = v)),
        ]),
        const SizedBox(height: 12),
        CustomButton(width: double.infinity, text: 'SAVE', variant: ButtonVariant.FillLoginGreen, onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

Widget _scaffoldForm({required String title, required List<Widget> body}) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: body,
      ),
    ),
  );
}

// legacy panel removed; using _group and _alertItem instead

class _SliderEditor extends StatefulWidget {
  const _SliderEditor({required this.valueText, required this.onApply});
  final String valueText;
  final void Function(String text) onApply;
  @override
  State<_SliderEditor> createState() => _SliderEditorState();
}

class _SliderEditorState extends State<_SliderEditor> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.valueText);
  }
  @override
  void didUpdateWidget(covariant _SliderEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueText != widget.valueText && _c.text != widget.valueText) {
      _c.text = widget.valueText;
    }
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
                focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(5)), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CustomButton(text: 'APPLY', variant: ButtonVariant.OutlinePrimaryWhite, fontStyle: ButtonFontStyle.GilroyMedium16Primary, onTap: () => widget.onApply(_c.text.trim())),
        ],
      ),
    );
  }
}

Widget _alertItem(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required String reqId,
  required WidgetBuilder pageBuilder,
  Future<void> Function()? onReturn,
}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return DebugBadge(
    reqId: reqId,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: pageBuilder));
          if (onReturn != null) await onReturn();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            GradientIcon(icon, gradient: AppIconGradients.resolve(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: ColorConstant.bluegray400), overflow: TextOverflow.ellipsis, maxLines: 2),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    ),
  );
}

Widget _group(BuildContext context, {required String title, required List<Widget> children}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ColorConstant.indigo51, width: 1),
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

// removed legacy _timeTile (replaced by ReportTimeTile)


