import 'package:flutter/material.dart';
// ignore_for_file: unused_import, unused_field, unused_element
// removed: local settings storage
import 'package:helpcare/widgets/gradient_icon.dart';
// debug navigation imports
// removed unused debug navigation imports
import 'package:helpcare/core/utils/debug_config.dart';
// removed unused debug navigation imports
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/report/_report_widgets.dart';
// sensor_detail_page: Sensors 패널 제거로 미사용
import 'package:helpcare/presentation/settings_page/alarm_detail_page.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/presentation/auth/biometric_settings_screen.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/widgets/app_switch.dart';
import 'package:helpcare/presentation/widgets/app_heading.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/presentation/settings_page/local_data_page.dart';
import 'package:helpcare/presentation/settings_page/user_detail_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // replace local storage with server-backed settings
  final SettingsService _svc = SettingsService();
  String language = 'en';
  String region = 'KR';
  bool autoRegion = true;
  bool guestMode = false;
  String glucoseUnit = 'mgdl';
  String timeFormat = '24h';
  bool accHighContrast = false;
  bool accLargerFont = false;
  bool accColorblind = false;
  bool notificationsEnabled = true;
  bool alarmsMuteAll = false;
  int chartDotSize = 2;
  // support: log transmission
  String _lastLogTxAt = '';
  bool _lastLogTxOk = false;
  // 로그인 사용자 (lastUserId, displayName에서 로드)
  String displayName = 'Guest';
  String email = '';
  DateTime sensorStart = DateTime.now().subtract(const Duration(days: 3));
  int lifeDays = 14;
  // alarms from server
  List<Map<String, dynamic>> alarms = [];
  // sensors: Setup에서 제거(중복). Sensor 탭에서 관리.
  // SN / EQSN
  final TextEditingController _snCtrl = TextEditingController();
  String _eqsn = '';
  String _snModel = '';
  String _snYear = '';
  String _snSample = '';
  String _snSerial = '';

  // row color palette
  static const List<Color> _rowColors = <Color>[
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.purple,
    Colors.pink,
    Colors.blueGrey,
    Colors.blue,
    Colors.green,
  ];
  Color _rowColor(int index) => _rowColors[index % _rowColors.length];

  @override
  void initState() {
    super.initState();
    _load();
    // 반영 즉시 UI에 보여주기 위해 설정 변경 이벤트 수신
    AppSettingsBus.changed.addListener(_onAppSettingsChanged);
  }

  Future<int> _getStoredDotSize() async {
    try {
      final local = await SettingsStorage.load();
      final int cds = ((local['chartDotSize'] as num?)?.toInt() ?? chartDotSize);
      return cds.clamp(1, 10);
    } catch (_) {
      return chartDotSize.clamp(1, 10);
    }
  }

  Future<void> _openDotSizeSheet(BuildContext context) async {
    final int current = await _getStoredDotSize();
    await _showSelectSheet(
      context,
      title: 'Chart dot size',
      options: List<String>.generate(10, (i) => '${i + 1}'),
      current: '$current',
      onSelected: (v) async {
        final int sel = int.tryParse(v) ?? current;
        setState(() { chartDotSize = sel.clamp(1, 10); });
        final s = await SettingsStorage.load();
        s['chartDotSize'] = chartDotSize;
        await SettingsStorage.save(s);
        AppSettingsBus.notify();
      },
    );
  }

  void _onAppSettingsChanged() async {
    try {
      final local = await SettingsStorage.load();
      if (!mounted) return;
      setState(() {
        final int cds = ((local['chartDotSize'] as num?)?.toInt() ?? 2);
        chartDotSize = cds.clamp(1, 10);
        email = (local['lastUserId'] as String? ?? '').toString().trim();
        displayName = (local['displayName'] as String? ?? '').toString().trim();
        if (displayName.isEmpty && email.isNotEmpty) displayName = email;
        if (displayName.isEmpty) displayName = 'Guest';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    try { AppSettingsBus.changed.removeListener(_onAppSettingsChanged); } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 재진입 시 로컬 저장된 도트 크기 등 최신값을 다시 반영
    _load();
  }

  Future<void> _load() async {
    try {
      final local = await SettingsStorage.load();
      // 모든 설정 기본 로컬. BE는 업로드 전용, 실패 시 폴백 없음.
      final app = await _svc.getAppSetting();
      final list = await _svc.listAlarms();
      if (!mounted) return;
      setState(() {
        final prefs = (app['preferences'] as Map?) ?? {};
        language = (prefs['language'] ?? local['language'] ?? language).toString();
        region = (prefs['region'] ?? local['region'] ?? region).toString();
        autoRegion = (prefs['autoRegion'] ?? local['autoRegion'] ?? autoRegion) == true;
        guestMode = (prefs['guestMode'] ?? local['guestMode'] ?? guestMode) == true;
        glucoseUnit = ((local['glucoseUnit'] ?? app['unit'] ?? '') == 'mmol' || (app['unit'] ?? '') == 'mmol/L') ? 'mmol' : 'mgdl';
        timeFormat = (local['timeFormat'] ?? prefs['timeFormat'] ?? timeFormat).toString();
        accHighContrast = (prefs['accHighContrast'] ?? accHighContrast) == true;
        accLargerFont = (prefs['accLargerFont'] ?? accLargerFont) == true;
        accColorblind = (prefs['accColorblind'] ?? accColorblind) == true;
        alarms = list;
        final bool? notif = (prefs['notificationsEnabled'] as bool?);
        notificationsEnabled = notif ?? (app['notifications'] == true);
        alarmsMuteAll = local['alarmsMuteAll'] == true;
        final int cds = ((local['chartDotSize'] as num?)?.toInt() ?? 2);
        chartDotSize = cds.clamp(1, 10);
        _lastLogTxAt = (local['lastLogTxAt'] as String? ?? '').toString().trim();
        _lastLogTxOk = local['lastLogTxOk'] == true;
        // user: local only
        email = (local['lastUserId'] as String? ?? '').toString().trim();
        displayName = (local['displayName'] as String? ?? '').toString().trim();
        if (displayName.isEmpty && email.isNotEmpty) displayName = email;
        if (displayName.isEmpty) displayName = 'Guest';
        _eqsn = (local['eqsn'] as String? ?? '').toString().trim();
        _snCtrl.text = _eqsn;
        _parseSn(_eqsn);
      });
      _loadDataSummary();
    } catch (_) {}
  }

  String _logTxSubtitle() {
    if (_lastLogTxAt.isEmpty) return 'Not sent yet';
    final dt = DateTime.tryParse(_lastLogTxAt)?.toLocal();
    final ts = dt != null ? dt.toString() : _lastLogTxAt;
    return _lastLogTxOk ? 'Transmission Completed: $ts' : 'Last attempt failed: $ts';
  }

  Future<void> _sendLogTx() async {
    final DateTime now = DateTime.now();
    bool ok = false;
    try {
      final logs = await BleLogService().snapshot(limit: 80);
      final s = await SettingsStorage.load();
      final String eqsn = (s['eqsn'] as String? ?? '').trim();
      final String userId = (s['lastUserId'] as String? ?? '').trim();
      final String apiBase = (s['apiBaseUrl'] as String? ?? '').trim();
      final memo = [
        '[log_tx]',
        'time=${now.toUtc().toIso8601String()}',
        if (userId.isNotEmpty) 'userId=$userId',
        if (eqsn.isNotEmpty) 'eqsn=$eqsn',
        if (apiBase.isNotEmpty) 'apiBase=$apiBase',
        'region=$region',
        'language=$language',
        'timeFormat=$timeFormat',
        'glucoseUnit=$glucoseUnit',
        '--- ble_logs (latest ${logs.length}) ---',
        ...logs,
      ].join('\n');
      // backend 이벤트 타입 enum 제한이 있어, memo 타입으로 전송하고 본문에 tag를 포함한다.
      ok = await DataService().postEvent(type: 'memo', time: now, memo: memo);
    } catch (_) {
      ok = false;
    }
    try {
      final st = await SettingsStorage.load();
      st['lastLogTxAt'] = now.toUtc().toIso8601String();
      st['lastLogTxOk'] = ok;
      await SettingsStorage.save(st);
      if (mounted) {
        setState(() {
          _lastLogTxAt = (st['lastLogTxAt'] as String? ?? '').trim();
          _lastLogTxOk = st['lastLogTxOk'] == true;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Transmission Completed' : 'Transmission Failed (offline?)')),
    );
  }

  int _localCount = 0;
  List<String> _localDays = <String>[];

  Future<void> _loadDataSummary() async {
    try {
      final repo = GlucoseLocalRepo();
      final int c = await repo.count();
      final List<String> days = await repo.listDaysDesc();
      if (!mounted) return;
      setState(() {
        _localCount = c;
        _localDays = days;
      });
    } catch (_) {}
  }

  Future<void> _resetLocalDb() async {
    try {
      await GlucoseLocalRepo().clear();
      await EventLocalRepo().clear();
      // reset counters
      final st = await SettingsStorage.load();
      st['lastTrid'] = 0;
      st['lastEvid'] = 0;
      await SettingsStorage.save(st);
      await _loadDataSummary();
      // notify charts to refresh immediately
      try { DataSyncBus().emitGlucoseBulk(count: 0); } catch (_) {}
      try { DataSyncBus().emitEventBulk(count: 0); } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local DB reset completed')));
    } catch (_) {}
  }

  void _parseSn(String sn) {
    final s = sn.trim().toUpperCase();
    String model = '';
    String year = '';
    String sample = '';
    String serial = '';
    if (s.length >= 7) {
      model = s.substring(0, 3); // C21
      final String y = s.substring(3, 4); // Z
      // simple mapping: Z=2025, Y=2024, A=2026 (rollover)
      final Map<String, String> ymap = {'Y': '2024', 'Z': '2025', 'A': '2026', 'B': '2027'};
      year = ymap[y] ?? y;
      sample = s.substring(4, 5); // S or P
      serial = s.substring(5); // remaining digits
    }
    _snModel = model;
    _snYear = year.isEmpty ? '' : year;
    _snSample = sample;
    _snSerial = serial;
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Row(children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Future<void> _saveAndSync() async {
    final String newEqsn = _snCtrl.text.trim();
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String prevEqsn = (st['eqsn'] as String? ?? '').trim();
    if (newEqsn == prevEqsn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SN unchanged')));
      return;
    }
    // 1) update settings
    st['eqsn'] = newEqsn;
    await SettingsStorage.save(st);
    setState(() { _eqsn = newEqsn; });
    // 2) SN 변경 시 로컬 데이터 전부 초기화 (혼섞임 방지)
    try {
        await GlucoseLocalRepo().clear();
        await EventLocalRepo().clear();
    } catch (_) {}
    // 3) 시작일은 로컬 우선: 온라인이고 서버에 SN이 있으면 서버값 사용, 없으면 로컬(현재시각) 기록 후 서버로 동기화
    try {
      final ss = SettingsService();
      DateTime? startLocal;
      try {
        final Map<String, dynamic> eq = await ss.getEqBySerial(newEqsn);
        final String? stRemote = (eq['startAt'] as String?);
        if (stRemote != null && stRemote.trim().isNotEmpty) {
          startLocal = DateTime.tryParse(stRemote)?.toLocal();
        }
      } catch (_) {}
      startLocal ??= DateTime.now();
      try { final m = await SettingsStorage.load(); m['sensorStartAt'] = startLocal.toUtc().toIso8601String(); await SettingsStorage.save(m); } catch (_) {}
      try { await ss.upsertEqStart(serial: newEqsn, startAt: startLocal); } catch (_) {}
      try { DataSyncBus().emitGlucoseBulk(count: 1); } catch (_) {}
    } catch (_) {}
    // 4) fetch from DB (server) into local cache (recent 30 days)
    try {
      final ds = DataService();
      final now = DateTime.now();
      await ds.fetchGlucose(from: now.subtract(const Duration(days: 30)), to: now, limit: 5000);
    } catch (_) {}
    // 5) RACP greater-than from last trid
    try {
      final int last = await GlucoseLocalRepo().maxTrid(eqsn: newEqsn);
      await BleService().requestRacpFromTrid((last + 1) & 0xFFFF);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved & syncing...')));
  }

  Future<void> _save() async {
    // 1) 로컬 저장(즉시 적용/원복 방지)
    try {
      final local = await SettingsStorage.load();
      final String lang = (language == 'ar' || language == 'en') ? language : 'en';
      final String tf = (timeFormat == '12h' || timeFormat == '24h') ? timeFormat : '24h';
      local['language'] = lang;
      local['region'] = region;
      local['autoRegion'] = autoRegion;
      local['guestMode'] = guestMode;
      local['glucoseUnit'] = glucoseUnit;
      local['timeFormat'] = tf;
      local['accHighContrast'] = accHighContrast;
      local['accLargerFont'] = accLargerFont;
      local['accColorblind'] = accColorblind;
      local['notificationsEnabled'] = notificationsEnabled;
      local['alarmsMuteAll'] = alarmsMuteAll;
      await SettingsStorage.save(local);
      // Notification on/off 즉시 반영
      try { NotificationService().setEnabled(notificationsEnabled); } catch (_) {}
      // 런타임 언어 변경(지원 로케일만)
      try {
        if (mounted && (lang == 'en' || lang == 'ar')) {
          await context.setLocale(Locale(lang));
        }
      } catch (_) {}
      AppSettingsBus.notify();
    } catch (_) {}

    // 2) 서버 저장(가능하면) - 실패해도 로컬은 유지
    // 요구사항: glucoseUnit은 최우선이며 autoRegion이 unit을 덮어쓰지 않는다.
    try {
      await _svc.updateAppSetting({
        'unit': glucoseUnit == 'mgdl' ? 'mg/dL' : 'mmol/L',
        'notifications': notificationsEnabled,
        'timeFormat': timeFormat,
        'alarmsMuteAll': alarmsMuteAll,
        'preferences': {
          'language': language,
          'region': region,
          'autoRegion': autoRegion,
          'guestMode': guestMode,
          'timeFormat': timeFormat,
          'accHighContrast': accHighContrast,
          'accLargerFont': accLargerFont,
          'accColorblind': accColorblind,
          'notificationsEnabled': notificationsEnabled,
        },
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontalMargin = width > 600 ? 32 : (width > 400 ? 24 : 16);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _userCard(context),
                const SizedBox(height: 12),
                if (kDebugMode) ...[
                  ReportCard(
                    title: 'Data',
                    subtitle: 'Local cache summary',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.storage, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Total points: ' + _localCount.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _loadDataSummary,
                                child: const Text('REFRESH'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalDataPage()));
                                },
                                child: const Text('OPEN DATA'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _resetLocalDb,
                                child: const Text('RESET DB'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                // (moved SN card to Sensor tab)
                // report-style header
                const AppHeading('Settings', level: AppHeadingLevel.h1),
                const SizedBox(height: 6),
                const AppHeading('Application preferences', level: AppHeadingLevel.h3),
                const SizedBox(height: 12),
                const SizedBox(height: 8),
                ReportCard(
                  title: 'General',
                  subtitle: 'Language, Region, Notifications',
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.public,
                      title: 'Region',
                      subtitle: autoRegion ? 'Auto-detect: $region' : region,
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'Region',
                        options: const ['KR', 'US', 'GB', 'CA', 'EU'],
                        current: region,
                        onSelected: (v) => setState(() { region = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.translate,
                      title: 'Language',
                      subtitle: language,
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'Language',
                        options: const ['en', 'ar'],
                        current: language,
                        onSelected: (v) => setState(() { language = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.access_time,
                      title: 'Time format',
                      subtitle: timeFormat,
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'Time format',
                        options: const ['24h', '12h'],
                        current: timeFormat,
                        onSelected: (v) => setState(() { timeFormat = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.scatter_plot,
                      title: 'Chart dot size',
                      subtitle: '${chartDotSize}px',
                      onTap: () => _openDotSizeSheet(context),
                    ),
                    _toggleItem('Notifications', notificationsEnabled, (v) async {
                      setState(() { notificationsEnabled = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                    _toggleItem('Mute all alarms (AR_01_01)', alarmsMuteAll, (v) async {
                      setState(() { alarmsMuteAll = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                  ]),
                ),
                const SizedBox(height: 12),
                ReportCard(
                  title: 'Units',
                  subtitle: 'Glucose unit',
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.straighten,
                      title: 'Glucose unit',
                      subtitle: glucoseUnit == 'mgdl' ? 'mg/dL' : 'mmol/L',
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'Glucose unit',
                        options: const ['mg/dL', 'mmol/L'],
                        current: glucoseUnit == 'mgdl' ? 'mg/dL' : 'mmol/L',
                        onSelected: (v) => setState(() {
                          glucoseUnit = (v == 'mmol/L') ? 'mmol' : 'mgdl';
                          _save();
                          AppSettingsBus.notify();
                        }),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // NOTE: Sensors 패널은 Sensor 탭과 중복 — req_remove.md 참조. 제거함.
                ReportCard(
                  title: 'Accessibility',
                  subtitle: 'Contrast and font',
                  child: Column(children: [
                    _toggleItem('High contrast', accHighContrast, (v) async {
                      setState(() { accHighContrast = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                    _toggleItem('Larger font', accLargerFont, (v) async {
                      setState(() { accLargerFont = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                    _toggleItem('Color blind mode', accColorblind, (v) async {
                      setState(() { accColorblind = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                  ]),
                ),
                const SizedBox(height: 12),
                ReportCard(
                  title: 'Developer',
                  subtitle: 'Debug options',
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.bug_report,
                      title: 'Requirement overlay',
                      subtitle: DebugConfig.overlayEnabled ? 'On' : 'Off',
                      onTap: () => setState(() { DebugConfig.overlayEnabled = !DebugConfig.overlayEnabled; }),
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.list_alt,
                      title: 'BLE Logs',
                      subtitle: 'Most recent BLE/OPS/Notify debug logs',
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) {
                            return SafeArea(
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('BLE Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        TextButton(
                                          onPressed: () => BleLogService().clear(),
                                          child: const Text('Clear'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ValueListenableBuilder<List<String>>(
                                      valueListenable: BleLogService().lines,
                                      builder: (context, lines, _) {
                                        if (lines.isEmpty) {
                                          return const Center(child: Text('No logs'));
                                        }
                                        return ListView.builder(
                                          padding: const EdgeInsets.all(12),
                                          itemCount: lines.length,
                                          itemBuilder: (_, i) => Text(lines[i], style: const TextStyle(fontSize: 12)),
                                        );
                                      },
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.support_agent,
                      title: 'Log Data Transmission',
                      subtitle: _logTxSubtitle(),
                      onTap: _sendLogTx,
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.fingerprint,
                      title: 'Biometric (LO_02_06)',
                      subtitle: 'Enable / Debug bypass / Test',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BiometricSettingsScreen()));
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.delete_sweep,
                      title: 'Clear Data (points + events)',
                      subtitle: 'Delete all glucose points and events for current user',
                      onTap: () async {
                        final ok = await _svc.clearAllData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Cleared' : 'Failed to clear')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'Seed 1 day (1-min interval)',
                      subtitle: 'Generate 1-day data ending now',
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDay();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Seeded' : 'Failed to seed')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'Seed 3 days (1-min interval)',
                      subtitle: 'Generate 3 days of data ending now',
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDays(3);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Seeded 3 days' : 'Failed to seed')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'Seed 14 days (1-min interval)',
                      subtitle: 'Generate 14 days of data ending now',
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDays(14);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Seeded 14 days' : 'Failed to seed')),
                        );
                      },
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // removed unused _section; replaced by ReportCard

  Widget _toggleItem(String label, bool value, ValueChanged<bool> onChanged) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        AppSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ]),
    );
  }

  // --- Alarms UI ---
  Color _alarmColor(String type) {
    switch (type) {
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.cyan;
      case 'rate':
        return Colors.purple;
      case 'system':
      default:
        return Colors.grey;
    }
  }

  IconData _alarmIcon(String type) {
    switch (type) {
      case 'high':
        return Icons.trending_up;
      case 'low':
        return Icons.trending_down;
      case 'rate':
        return Icons.speed;
      case 'system':
      default:
        return Icons.settings;
    }
  }

  Widget _alarmItem(int index, Map<String, dynamic> a) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String type = (a['type'] ?? '').toString();
    final bool enabled = a['enabled'] == true;
    final num? threshold = a['threshold'] as num?;
    final String id = (a['_id'] ?? '').toString();
    final title = () {
      switch (type) {
        case 'high':
          return 'High alert';
        case 'low':
          return 'Low alert';
        case 'rate':
          return 'Rate-of-change';
        case 'system':
          return 'System alert';
        default:
          return type;
      }
    }();
    final String subtitle = threshold != null ? 'Threshold: $threshold' : (enabled ? 'Enabled' : 'Disabled');
    final Color c = _alarmColor(type).withOpacity(0.9);
    final Color rowAccent = _rowColor(index);
    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlarmDetailPage(alarm: a)),
        );
        if (changed == true) {
          _load();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: rowAccent, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(_alarmIcon(type), color: c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 2),
          ]),
        ),
        AppSwitch(
          value: enabled,
          onChanged: (v) async {
            setState(() {
              final idx = alarms.indexWhere((e) => (e['_id'] ?? '') == id);
              if (idx >= 0) alarms[idx] = {...alarms[idx], 'enabled': v};
            });
            // local-first cache (so alarms/notifications still work even when backend is unreachable)
            try {
              final st = await SettingsStorage.load();
              final List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
                  ? (st['alarmsCache'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
                  : <Map<String, dynamic>>[];
              final String ty = (a['type'] ?? '').toString();
              final int i = list.indexWhere((e) => (e['type'] ?? '').toString() == ty);
              if (i >= 0) list[i] = {...list[i], 'enabled': v};
              else list.add({'_id': id.isEmpty ? 'local:$ty' : id, 'type': ty, 'enabled': v});
              st['alarmsCache'] = list;
              st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
              await SettingsStorage.save(st);
              AlertEngine().invalidateAlarmsCache();
            } catch (_) {}
            // best-effort server update
            if (id.isNotEmpty && !id.startsWith('local:')) {
              try { await _svc.updateAlarm(id, {'enabled': v}); } catch (_) {}
            }
          },
        ),
      ]),
      ),
    );
  }

  Widget _notifItem(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
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
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 2),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  Future<void> _showSelectSheet(BuildContext context, {required String title, required List<String> options, required String current, required ValueChanged<String> onSelected}) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...options.map((o) => ListTile(
                  title: Text(o),
                  trailing: o == current ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(o);
                  },
                )),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }
}


Widget _userCard(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final _SettingsPageState? st = context.findAncestorStateOfType<_SettingsPageState>();
  final DateTime start = st?.sensorStart ?? DateTime.now();
  final int total = st?.lifeDays ?? 14;
  final Duration used = DateTime.now().difference(start);
  final int remain = (total - used.inDays).clamp(0, total);
  final String name = (st?.displayName ?? '').toString().trim().isEmpty ? 'Guest' : (st!.displayName.toString().trim());
  final String e = (st?.email ?? '').toString().trim();
  final String email = e.isEmpty ? '—' : e;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDetailPage(displayName: name, email: email),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 22, child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.hourglass_bottom, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text('Remaining days: $remain / $total', style: const TextStyle(fontSize: 13))),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// removed unused _navButton


