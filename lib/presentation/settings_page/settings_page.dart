import 'dart:async';

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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/presentation/settings_page/local_data_page.dart';
import 'package:helpcare/presentation/settings_page/user_detail_page.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';

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
  int chartDotSize = 2;
  // support: log transmission
  String _lastLogTxAt = '';
  bool _lastLogTxOk = false;
  // 로그인 사용자 (lastUserId, displayName에서 로드)
  String displayName = 'Guest';
  String email = '';
  DateTime sensorStart = DateTime.now().subtract(const Duration(days: 3));
  int lifeDays = AppConstants.defaultSensorValidityDays;
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

  /// SharedPreferences JSON에 숫자 등이 섞여도 setState 전체가 캐스트 예외로 스킵되지 않도록.
  static String _storageString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

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
      title: 'settings_chart_dot'.tr(),
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
        _applyUserIdentityFromMap(local);
      });
    } catch (_) {}
  }

  /// 로그인/게스트 표시용: 저장소(+선택적 앱 prefs)에서 email·displayName·guestMode 반영
  void _applyUserIdentityFromMap(Map<String, dynamic> local, {Map? prefs}) {
    email = _storageString(local['lastUserId']);
    displayName = _storageString(local['displayName']);
    if (displayName.isEmpty && email.isNotEmpty) displayName = email;
    if (displayName.isEmpty) displayName = 'Guest';

    final String tok = _storageString(local['authToken']);
    final bool loggedIn =
        email.isNotEmpty && tok.isNotEmpty && tok != 'OFFLINE_USER_TOKEN' && local['guestMode'] != true;
    if (loggedIn) {
      guestMode = false;
    } else if (prefs != null) {
      guestMode = (prefs['guestMode'] ?? local['guestMode'] ?? guestMode) == true;
    } else {
      guestMode = (local['guestMode'] == true);
    }
  }

  @override
  void dispose() {
    try { AppSettingsBus.changed.removeListener(_onAppSettingsChanged); } catch (_) {}
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ProfileSyncService.ensureLocalUserFromJwt();
      final local = await SettingsStorage.load();
      // 모든 설정 기본 로컬. BE는 업로드 전용, 실패 시 폴백 없음.
      final app = await _svc.getAppSetting();
      final list = await _svc.listAlarms();
      if (!mounted) return;
      setState(() {
        final prefs = (app['preferences'] as Map?) ?? {};
        final String rawLang = (local['language'] ?? prefs['language'] ?? 'en').toString().toLowerCase();
        language = rawLang == 'ko' ? 'ko' : 'en';
        region = (prefs['region'] ?? local['region'] ?? region).toString();
        autoRegion = (prefs['autoRegion'] ?? local['autoRegion'] ?? autoRegion) == true;
        // 로그인·회원 정보가 로컬에 있으면 게스트 플래그를 서버 설정보다 우선
        _applyUserIdentityFromMap(local, prefs: prefs);
        glucoseUnit = ((local['glucoseUnit'] ?? app['unit'] ?? '') == 'mmol' || (app['unit'] ?? '') == 'mmol/L') ? 'mmol' : 'mgdl';
        timeFormat = (local['timeFormat'] ?? prefs['timeFormat'] ?? timeFormat).toString();
        accHighContrast = (prefs['accHighContrast'] ?? accHighContrast) == true;
        accLargerFont = (prefs['accLargerFont'] ?? accLargerFont) == true;
        accColorblind = (prefs['accColorblind'] ?? accColorblind) == true;
        alarms = list;
        final int cds = ((local['chartDotSize'] as num?)?.toInt() ?? 2);
        chartDotSize = cds.clamp(1, 10);
        _lastLogTxAt = (local['lastLogTxAt'] as String? ?? '').toString().trim();
        _lastLogTxOk = local['lastLogTxOk'] == true;
        _eqsn = (local['eqsn'] as String? ?? '').toString().trim();
        _snCtrl.text = _eqsn;
        _parseSn(_eqsn);
        lifeDays = AppConstants.defaultSensorValidityDays;
        final String ssRaw = _storageString(local['sensorStartAt']);
        if (ssRaw.isNotEmpty) {
          final DateTime? p = DateTime.tryParse(ssRaw);
          if (p != null) sensorStart = p.toLocal();
        }
      });
      _loadDataSummary();
      unawaited(ProfileSyncService.refreshFromServer());
    } catch (_) {}
  }

  String _logTxSubtitle() {
    if (_lastLogTxAt.isEmpty) return 'settings_tx_not_sent'.tr();
    final dt = DateTime.tryParse(_lastLogTxAt)?.toLocal();
    final ts = dt != null ? dt.toString() : _lastLogTxAt;
    return _lastLogTxOk ? '${'settings_tx_prefix_ok'.tr()}: $ts' : '${'settings_tx_prefix_fail'.tr()}: $ts';
  }

  Future<void> _sendLogTx() async {
    final DateTime now = DateTime.now();
    bool ok = false;
    try {
      final logs = await BleLogService().snapshot(limit: 80);
      final s = await SettingsStorage.load();
      final String eqsn = (s['eqsn'] as String? ?? '').trim();
      final String userId = _storageString(s['lastUserId']);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings_data_reset_done'.tr())));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings_sn_unchanged'.tr())));
      return;
    }
    // 1) update settings (+ Serial 화면 "마지막 QR" 메타가 현재 SN과 어긋나지 않게)
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final String up = newEqsn.toUpperCase();
    st['eqsn'] = newEqsn;
    st['lastScannedQrFullSn'] = up;
    st['lastScannedQrSerial'] = up;
    st['lastScannedQrAt'] = nowIso;
    st['lastScannedQrRegistered'] = true;
    await SettingsStorage.save(st);
    // 2) SN 변경 시 로컬 데이터 전부 초기화 (혼섞임 방지)
    try {
        await GlucoseLocalRepo().clear();
        await EventLocalRepo().clear();
    } catch (_) {}
    // 3) 시작일은 로컬 우선: 온라인이고 서버에 SN/MAC이 있으면 서버값 사용(req 1-7)
    String resolvedEqsn = newEqsn;
    try {
      final ss = SettingsService();
      DateTime? startLocal;
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? mac = prefs.getString('cgms.last_mac');
        final Map<String, dynamic> eq = await ss.resolveEqRegistration(serial: newEqsn, bleMac: mac);
        if (SettingsService.shouldApplyResolvedEqStart(eq, newEqsn)) {
          final String? stRemote = (eq['startAt'] as String?);
          if (stRemote != null && stRemote.trim().isNotEmpty) {
            startLocal = DateTime.tryParse(stRemote)?.toLocal();
          }
          final String? srvSn = (eq['serial'] as String?)?.trim();
          if (srvSn != null && srvSn.isNotEmpty) resolvedEqsn = srvSn;
        }
      } catch (_) {}
      startLocal ??= DateTime.now();
      try {
        final m = await SettingsStorage.load();
        m['sensorStartAt'] = startLocal.toUtc().toIso8601String();
        m['sensorStartAtEqsn'] = resolvedEqsn;
        if (resolvedEqsn != newEqsn) {
          m['eqsn'] = resolvedEqsn;
          st['eqsn'] = resolvedEqsn;
        }
        await SettingsStorage.save(m);
      } catch (_) {}
      try { await ss.upsertEqStart(serial: resolvedEqsn, startAt: startLocal); } catch (_) {}
      try { DataSyncBus().emitGlucoseBulk(count: 1); } catch (_) {}
    } catch (_) {}
    if (mounted) {
      setState(() {
        _eqsn = resolvedEqsn;
        if (resolvedEqsn != newEqsn) _snCtrl.text = resolvedEqsn;
      });
    }
    // 4) fetch from DB (server) into local cache (recent 30 days)
    try {
      final ds = DataService();
      final now = DateTime.now();
      await ds.fetchGlucose(from: now.subtract(const Duration(days: 30)), to: now, limit: 5000);
    } catch (_) {}
    // 5) RACP greater-than from last trid
    try {
      final int last = await GlucoseLocalRepo().maxTrid(eqsn: resolvedEqsn);
      await BleService().requestRacpFromTrid((last + 1) & 0xFFFF);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings_saved_syncing'.tr())));
  }

  /// 상단 사용자 카드 — [findAncestorStateOfType]은 자기 State를 찾지 못하므로 State 필드를 직접 사용
  Widget _buildUserCard(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime start = sensorStart;
    final int total = lifeDays;
    final Duration used = DateTime.now().difference(start);
    final int remain = (total - used.inDays).clamp(0, total);
    final String nameRaw = displayName.trim().isEmpty ? 'Guest' : displayName.trim();
    final String name = nameRaw == 'Guest' ? 'common_guest'.tr() : nameRaw;
    final String e = email.trim();
    final String emailLine = e.isEmpty ? '—' : e;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserDetailPage(displayName: name, email: emailLine),
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
                Text(emailLine, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                Expanded(child: Text('${'settings_remaining_days'.tr()}: $remain / $total', style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final String lang = language == 'ko' ? 'ko' : 'en';
    // 1) 로컬 저장(즉시 적용/원복 방지)
    try {
      final local = await SettingsStorage.load();
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
      local['notificationsEnabled'] = true;
      await SettingsStorage.save(local);
      try { NotificationService().setEnabled(true); } catch (_) {}
      // 런타임 언어 변경(지원 로케일만)
      try {
        if (mounted) {
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
        'notifications': true,
        'timeFormat': timeFormat,
        'preferences': {
          'language': lang,
          'region': region,
          'autoRegion': autoRegion,
          'guestMode': guestMode,
          'timeFormat': timeFormat,
          'accHighContrast': accHighContrast,
          'accLargerFont': accLargerFont,
          'accColorblind': accColorblind,
          'notificationsEnabled': true,
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
                _buildUserCard(context),
                const SizedBox(height: 12),
                if (kDebugMode) ...[
                  ReportCard(
                    title: 'settings_data_title'.tr(),
                    subtitle: 'settings_data_local_sub'.tr(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.storage, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${'settings_data_total_points'.tr()}: ${_localCount.toString()}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _loadDataSummary,
                                child: Text('settings_data_refresh'.tr()),
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
                                child: Text('settings_data_open'.tr()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _resetLocalDb,
                                child: Text('settings_data_reset'.tr()),
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
                AppHeading('settings_page_title'.tr(), level: AppHeadingLevel.h1),
                const SizedBox(height: 6),
                AppHeading('settings_app_prefs'.tr(), level: AppHeadingLevel.h3),
                const SizedBox(height: 12),
                const SizedBox(height: 8),
                // ST_01_xx: 별도 "Notifications" 행 없음 — 알림은 Alarm 탭(유형별) + 로컬 저장의 notificationsEnabled(저장 시 true)로 처리.
                ReportCard(
                  title: 'settings_general'.tr(),
                  subtitle: 'settings_general_sub'.tr(),
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.public,
                      title: 'settings_region'.tr(),
                      subtitle: autoRegion ? '${'settings_region_auto'.tr()}: $region' : region,
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'settings_region'.tr(),
                        options: const ['KR', 'US', 'GB', 'CA', 'EU'],
                        current: region,
                        onSelected: (v) => setState(() { region = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.translate,
                      title: 'settings_language'.tr(),
                      subtitle: language == 'ko' ? 'settings_language_ko'.tr() : 'settings_language_en'.tr(),
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'settings_language'.tr(),
                        options: const ['en', 'ko'],
                        current: language,
                        labelFor: (code) => code == 'ko' ? tr('settings_language_ko') : tr('settings_language_en'),
                        onSelected: (v) => setState(() { language = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.access_time,
                      title: 'settings_time_format'.tr(),
                      subtitle: timeFormat,
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'settings_time_format'.tr(),
                        options: const ['24h', '12h'],
                        current: timeFormat,
                        onSelected: (v) => setState(() { timeFormat = v; _save(); AppSettingsBus.notify(); }),
                      ),
                    ),
                    _notifItem(
                      context,
                      icon: Icons.scatter_plot,
                      title: 'settings_chart_dot'.tr(),
                      subtitle: '${chartDotSize}px',
                      onTap: () => _openDotSizeSheet(context),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                ReportCard(
                  title: 'settings_units'.tr(),
                  subtitle: 'settings_units_sub'.tr(),
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.straighten,
                      title: 'settings_glucose_unit'.tr(),
                      subtitle: glucoseUnit == 'mgdl' ? 'mg/dL' : 'mmol/L',
                      onTap: () => _showSelectSheet(
                        context,
                        title: 'settings_glucose_unit'.tr(),
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
                  title: 'settings_accessibility'.tr(),
                  subtitle: 'settings_accessibility_sub'.tr(),
                  child: Column(children: [
                    _toggleItem('settings_acc_high_contrast'.tr(), accHighContrast, (v) async {
                      setState(() { accHighContrast = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                    _toggleItem('settings_acc_larger_font'.tr(), accLargerFont, (v) async {
                      setState(() { accLargerFont = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                    _toggleItem('settings_acc_colorblind'.tr(), accColorblind, (v) async {
                      setState(() { accColorblind = v; });
                      await _save();
                      AppSettingsBus.notify();
                    }),
                  ]),
                ),
                const SizedBox(height: 12),
                ReportCard(
                  title: 'settings_developer'.tr(),
                  subtitle: 'settings_developer_sub'.tr(),
                  child: Column(children: [
                    _notifItem(
                      context,
                      icon: Icons.bug_report,
                      title: 'settings_req_overlay'.tr(),
                      subtitle: DebugConfig.overlayEnabled ? 'common_on'.tr() : 'common_off'.tr(),
                      onTap: () => setState(() { DebugConfig.overlayEnabled = !DebugConfig.overlayEnabled; }),
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.list_alt,
                      title: 'settings_ble_logs'.tr(),
                      subtitle: 'settings_ble_logs_sub'.tr(),
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
                                        Text('settings_ble_logs_sheet_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        TextButton(
                                          onPressed: () => BleLogService().clear(),
                                          child: Text('settings_ble_clear'.tr()),
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
                                          return Center(child: Text('settings_ble_no_logs'.tr()));
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
                      title: 'settings_log_tx'.tr(),
                      subtitle: _logTxSubtitle(),
                      onTap: _sendLogTx,
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.fingerprint,
                      title: 'settings_biometric_row'.tr(),
                      subtitle: 'settings_biometric_row_sub'.tr(),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BiometricSettingsScreen()));
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.delete_sweep,
                      title: 'settings_clear_points'.tr(),
                      subtitle: 'settings_clear_points_sub'.tr(),
                      onTap: () async {
                        final ok = await _svc.clearAllData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'settings_dev_cleared'.tr() : 'settings_dev_clear_fail'.tr())),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'settings_seed_1d'.tr(),
                      subtitle: 'settings_seed_1d_sub'.tr(),
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDay();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'settings_dev_seeded'.tr() : 'settings_dev_seed_fail'.tr())),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'settings_seed_3d'.tr(),
                      subtitle: 'settings_seed_3d_sub'.tr(),
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDays(3);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'settings_dev_seeded_3'.tr() : 'settings_dev_seed_fail'.tr())),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.bolt,
                      title: 'settings_seed_nd'.tr(args: <String>[AppConstants.defaultSensorValidityDays.toString()]),
                      subtitle: 'settings_seed_nd_sub'.tr(args: <String>[AppConstants.defaultSensorValidityDays.toString()]),
                      onTap: () async {
                        final ok = await _svc.seedGlucoseDays(AppConstants.defaultSensorValidityDays);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'settings_dev_seeded_n'.tr(args: <String>[AppConstants.defaultSensorValidityDays.toString()]) : 'settings_dev_seed_fail'.tr())),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _notifItem(
                      context,
                      icon: Icons.history,
                      title: 'settings_seed_pd_title'.tr(),
                      subtitle: 'settings_seed_pd_sub'.tr(),
                      onTap: () async {
                        final ok = await _svc.seedPd0101PreviousData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'settings_seed_pd_ok'.tr() : 'settings_seed_pd_fail'.tr(),
                            ),
                          ),
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

  Future<void> _showSelectSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
    String Function(String value)? labelFor,
  }) async {
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
                  title: Text(labelFor != null ? labelFor(o) : o),
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


// removed unused _navButton


