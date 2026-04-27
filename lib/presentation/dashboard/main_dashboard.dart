import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:helpcare/widgets/spacing.dart';
import 'package:helpcare/widgets/debug_badge.dart';
import 'package:helpcare/presentation/dashboard/memo_modal.dart';
import 'package:helpcare/widgets/glucose_glow_orb.dart';
import 'package:helpcare/presentation/chart_page/chart_page.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/debug_toast.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helpcare/presentation/dashboard/pd_01_01_previous_data_screen.dart';
import 'package:helpcare/presentation/dashboard/pd_previous_routes.dart';
import 'package:easy_localization/easy_localization.dart';

bool _bleShowsConnected(BleConnPhase p) => p == BleConnPhase.notifySubscribed;

enum Trend { up, down, flat }
// 5단계 화살표 방향 (분당 변화율 기준)
enum Trend5 { upFast, up, flat, down, downFast }

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _glucoseValueKey = GlobalKey();

  late final AnimationController _toastController;
  Timer? _nextToastTimer;
  double _currentGlucose = 0;
  int _simulated = 0; // mock 비활성: 기본 0
  int _lastSpecOutYmd = -1; // 일 1회 스펙아웃 플래그 (yyyyMMdd)
  /// e.g. localized "Last Update mm/dd HH:mm" or em dash when no data
  late String _lastUpdateLine;
  Trend5 _trend5 = Trend5.flat;
  double _ratePerMin = 0; // mg/dL per minute
  bool _autoSimulate = false; // 자동 센서 데이터 시뮬레이션 게이트 (기본 off)
  String _unit = 'mg/dL';
  double _unitFactor = 1.0; // 1.0 for mg/dL, 1/18.02 for mmol/L
  bool _use24h = true;
  final List<Map<String, dynamic>> _series = <Map<String, dynamic>>[]; // {'time':DateTime,'value':double}
  // removed: 24h min/max, TIR (상단 오브 통계 제거에 따라 비표시)
  int _daysLeft = 0;
  DateTime? _sensorStart;
  int _sensorLifeDays = AppConstants.defaultSensorValidityDays;
  StreamSubscription<DataSyncEvent>? _syncSub;
  StreamSubscription<String>? _toastSub;
  // removed: external memo FAB open state (moved to ChartPage overlay)
  final ValueNotifier<int> _chartRefresh = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _toastController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _lastUpdateLine = 'dash_last_update_none'.tr();
    _loadSensorInfo();
    _loadUnit();
    AppSettingsBus.changed.addListener(_onSettingsChanged);
    BleService().phase.addListener(_onBlePhase);
    _seedPoints();
    _syncSub = DataSyncBus().stream.listen(_onDataSync);
    _toastSub = DebugToastBus().stream.listen(_onDebugToast);
    // 자동 시뮬레이션은 게이트가 on일 때만 시작
    if (_autoSimulate) {
      _triggerToast();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _markGuRendered());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 재진입 시 시작일 재조회 → days-left 즉시 반영
    _loadSensorInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextToastTimer?.cancel();
    _toastController.dispose();
    _syncSub?.cancel();
    _toastSub?.cancel();
    try { AppSettingsBus.changed.removeListener(_onSettingsChanged); } catch (_) {}
    BleService().phase.removeListener(_onBlePhase);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 스크린세이버/백그라운드 복귀 직후 로컬 DB에서 즉시 재로드 → 표시 공백 구간 최소화
      unawaited(_seedPoints());
    }
  }

  void _onSettingsChanged() {
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    // local-first: SettingsStorage.glucoseUnit (mgdl|mmol) is the UX source of truth
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl').trim();
      final String tf = (st['timeFormat'] as String? ?? '24h').toString();
      if (!mounted) return;
      setState(() {
        _unit = (u == 'mmol') ? 'mmol/L' : 'mg/dL';
        _unitFactor = (_unit == 'mmol/L') ? (1.0 / 18.02) : 1.0;
        _use24h = tf == '24h';
      });
    } catch (_) {}
  }
  void _onDebugToast(String msg) {
    if (!mounted) return;
    // reuse flying toast ui; display bottom-left simple toast
    final scaffold = ScaffoldMessenger.maybeOf(context);
    scaffold?.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)));
  }

  void _openPreviousDataScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: PdPreviousRoutes.stack),
        builder: (_) => const Pd0101PreviousDataScreen(),
      ),
    );
  }

  void _openMemoModal() async {
    debugPrint('[MemoModal] open requested');
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        debugPrint('[MemoModal] showModal builder enter');
        return SafeArea(
          top: false,
          child: Builder(builder: (_) {
            final mq = MediaQuery.of(ctx);
            return SizedBox(
              height: mq.size.height * 0.9,
              child: Padding(
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                child: Material(
                  type: MaterialType.transparency,
                  child: const MemoModal(),
                ),
              ),
            );
          }),
        );
      },
    );
    debugPrint('[MemoModal] modal closed, result=${result != null ? result.toString() : 'null'}');
    if (result != null) {
      try {
        final ds = DataService();
        // MemoModal returns keys: type (English), note, when(ISO)
        final String k = (result['type'] as String? ?? '').toLowerCase();
        final String type = {
          'blood glucose': 'bloodGlucose',
          'exercise': 'exercise',
          'insulin': 'insulin',
          'memo': 'memo',
          'meal': 'meal',
          'medication': 'medication',
        }[k] ?? 'memo';
        final String? note = result['note'] as String?;
        final DateTime when = DateTime.tryParse(result['when'] as String? ?? '') ?? DateTime.now();
        final ok = await ds.postEvent(type: type, time: when, memo: note);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'dash_event_saved'.tr() : 'dash_event_save_failed'.tr())),
        );
        if (ok) _chartRefresh.value++;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('dash_event_save_failed'.tr())));
      }
    }
  }

  void _triggerToast() {
    if (!mounted) return;
    if (!_autoSimulate) return; // 게이트 off 시 동작 중단
    // 샘플 데이터 수신 게이트: 10초 주기 → 인입 큐로 전달 → 서버 동기화 → 알림
    try {
      final DateTime now = DateTime.now();
      final int ymd = now.year * 10000 + now.month * 100 + now.day;
      // 범위: 50~230, 반등폭 1~3 유지
      int next;
      if (_lastSpecOutYmd != ymd) {
        // 오늘 첫 스펙아웃 강제: 50 미만 또는 230 초과
        final bool high = math.Random().nextBool();
        next = high ? (231 + math.Random().nextInt(15)) : (40 + math.Random().nextInt(10));
        _lastSpecOutYmd = ymd;
      } else {
        final int step = 1 + math.Random().nextInt(3); // 1..3
        final int dir = math.Random().nextBool() ? 1 : -1; // up/down
        next = _simulated + dir * step;
        if (next < 50) next = 50 + step; // 하한 반등
        if (next > 230) next = 230 - step; // 상한 반등
      }
      _simulated = next;
      IngestQueueService().enqueueGlucose(now, next);
      DataSyncBus().emitGlucosePoint(time: now, value: next.toDouble());
      _chartRefresh.value++; // 차트 새로고침 트리거
    } catch (_) {}
    setState(() {
      _lastUpdateLine = _formatLastUpdateLine(DateTime.now());
    });
    _nextToastTimer?.cancel();
    _toastController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      // schedule next generation after 1 minute idle
      if (_autoSimulate) {
        _nextToastTimer = Timer(const Duration(minutes: 1), () {
          if (mounted && _autoSimulate) _triggerToast();
        });
      }
    });
  }

  Future<void> _seedPoints() async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(hours: 24));
      final to = now.add(const Duration(hours: 1));
      String? eqsn;
      try {
        final st = await SettingsStorage.load();
        final String q = (st['eqsn'] as String? ?? '').trim();
        eqsn = q.isEmpty ? null : q;
      } catch (_) {}
      // 오프라인 우선: 로컬 DB에서 24h 범위 조회 (현재 SN·계정 범위)
      List<Map<String, dynamic>> rows = await GlucoseLocalRepo().range(from: from, to: to, limit: 2000, eqsn: eqsn);
      if (rows.isEmpty && (eqsn != null && eqsn.isNotEmpty)) {
        final loose = await GlucoseLocalRepo().range(from: from, to: to, limit: 2000, eqsn: null);
        if (loose.isNotEmpty) rows = loose;
      }
      _series.clear();
      for (final r in rows) {
        final int ms = (r['time_ms'] as int?) ?? 0;
        final DateTime t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
        final double v = ((r['value'] as num?) ?? 0).toDouble();
        _series.add({'time': t, 'value': v});
      }
      _series.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
      _recompute();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadSensorInfo() async {
    try {
      final ss = SettingsService();
      // 1) 로컬 캐시 우선 (오프라인 우선 원칙)
      try {
        final Map<String, dynamic> s = await SettingsStorage.load();
        final String eqsn = (s['eqsn'] as String? ?? '').trim();
        if (SettingsService.stripStaleSensorStart(s)) {
          await SettingsStorage.save(s);
        }
        final String cached = (s['sensorStartAt'] as String? ?? '').trim();
        if (cached.isNotEmpty) {
          _sensorStart = DateTime.tryParse(cached)?.toLocal();
        } else if (eqsn.isNotEmpty) {
          // 2) 로컬 없으면 서버에서 조회 후 캐시 (SN 또는 BLE MAC 일치 시, req 1-7)
          try {
            final prefs = await SharedPreferences.getInstance();
            final String? mac = prefs.getString('cgms.last_mac');
            final Map<String, dynamic> eq = await ss.resolveEqRegistration(serial: eqsn, bleMac: mac);
            if (SettingsService.shouldApplyResolvedEqStart(eq, eqsn)) {
              final String? st = (eq['startAt'] as String?);
              if (st != null && st.isNotEmpty) {
                _sensorStart = DateTime.tryParse(st)?.toLocal();
                try {
                  final m = await SettingsStorage.load();
                  m['sensorStartAt'] = st;
                  m['sensorStartAtEqsn'] = eqsn;
                  await SettingsStorage.save(m);
                } catch (_) {}
              }
              final String? srvSn = (eq['serial'] as String?)?.trim();
              if (srvSn != null && srvSn.isNotEmpty && srvSn != eqsn) {
                try {
                  final m = await SettingsStorage.load();
                  m['eqsn'] = srvSn;
                  await SettingsStorage.save(m);
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
      // 3) 기존 sensors 엔드포인트(백업 경로)
      try {
        if (_sensorStart == null) {
          final sens = await ss.listSensors();
          final Map<String, dynamic>? active = sens.cast<Map<String, dynamic>?>().firstWhere(
            (s) => (s?['isActive'] == true),
            orElse: () => sens.isNotEmpty ? sens.first : null,
          );
          if (active != null) {
            final String? st = active['startAt'] as String?;
            if (st != null && st.isNotEmpty) _sensorStart = DateTime.tryParse(st)?.toLocal();
            // 센서 유효일은 앱 상수(15일) 기준. 캐시/서버의 legacy lifeDays(14)는 무시.
            _sensorLifeDays = AppConstants.defaultSensorValidityDays;
          }
        }
      } catch (_) {}
      _recompute();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onDataSync(DataSyncEvent ev) {
    try {
      _onDataSyncImpl(ev);
    } catch (e) {
      assert(() {
        debugPrint('_onDataSync error: $e');
        return true;
      }());
    }
  }

  void _onDataSyncImpl(DataSyncEvent ev) {
    if (ev.kind == DataSyncKind.glucoseBulk) {
      // count==0 (예: SN 변경/DB clear) 시 즉시 대시(–) 표시를 위해 시리즈 초기화
      final int? c = ev.payload['count'] as int?;
      if (c != null && c == 0) {
        _series.clear();
        _lastUpdateLine = 'dash_last_update_none'.tr();
        _recompute();
        // SN 변경 신호로 간주하고 시작일 재조회 → 남은 일수 즉시 갱신
        try { _loadSensorInfo(); } catch (_) {}
        if (mounted) setState(() {});
        return;
      }
      // RACP 등 silent 배치는 DB에만 쌓일 수 있음 → 로컬에서 시리즈 재로드
      unawaited(_seedPoints());
      try { _loadSensorInfo(); } catch (_) {}
      if (mounted) setState(() {});
      return;
    }
    // 기타 동기화 이벤트(이벤트 생성/삭제 등)에도 시작일을 재조회해 days-left 반영
    if (ev.kind == DataSyncKind.eventBulk || ev.kind == DataSyncKind.eventItem) {
      _loadSensorInfo();
      if (mounted) setState(() {});
      return;
    }
    if (ev.kind != DataSyncKind.glucosePoint) return;
    final DateTime t = (ev.payload['time'] as DateTime);
    final double v = ((ev.payload['value'] as num?) ?? double.nan).toDouble();
    if (v.isNaN) return;
    _series.add({'time': t, 'value': v});
    final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _series.removeWhere((e) => (e['time'] as DateTime).isBefore(cutoff));
    _recompute();
    if (!mounted) return;
    setState(() {
      _lastUpdateLine = _formatLastUpdateLine(t);
    });
    // 실제 notify 이벤트용 토스트 애니메이션: 완료 후 자동 숨김, 재스케줄 없음
    _toastController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
    });
  }

  void _recompute() {
    if (_series.isEmpty) {
      _lastUpdateLine = 'dash_last_update_none'.tr();
      return;
    }
    final DateTime now = DateTime.now();
    // removed: 24h min/max 계산
    final Map<String, dynamic> last = _series.last;
    _currentGlucose = (last['value'] as double);
    _lastUpdateLine = _formatLastUpdateLine(last['time'] as DateTime);
    if (_series.length >= 2) {
      final Map<String, dynamic> prevPt = _series[_series.length - 2];
      final double prev = (prevPt['value'] as double);
      final DateTime tPrev = (prevPt['time'] as DateTime);
      final DateTime tLast = (last['time'] as DateTime);
      final double minutes = (tLast.difference(tPrev).inSeconds / 60.0).clamp(0.001, 1e9);
      final double delta = _currentGlucose - prev; // mg/dL
      _ratePerMin = delta / minutes; // mg/dL per minute
      // 5단계 분류
      _trend5 = _ratePerMin > 2
          ? Trend5.upFast
          : (_ratePerMin > 1
              ? Trend5.up
              : (_ratePerMin < -2
                  ? Trend5.downFast
                  : (_ratePerMin < -1 ? Trend5.down : Trend5.flat)));
    }
    // removed: TIR 계산 및 표시
    if (_sensorStart != null) {
      final int total = _sensorLifeDays;
      final int used = now.difference(_sensorStart!).inDays;
      _daysLeft = (total - used).clamp(0, total);
    }
    _markGuEvidence();
  }

  String _guBand(double v) {
    if (v <= 70) return 'low';
    if (v >= 180) return 'high';
    return 'in';
  }

  Future<void> _markGuRendered() async {
    try {
      final st = await SettingsStorage.load();
      st['gu0101RenderedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  void _markGuEvidence() {
    () async {
      try {
        final st = await SettingsStorage.load();
        st['gu0101RenderedAt'] = DateTime.now().toUtc().toIso8601String();
        st['gu0101Value'] = _series.isEmpty ? null : _currentGlucose.round();
        st['gu0102Trend'] = _trend5.toString().split('.').last;
        st['gu0103Color'] = _series.isEmpty ? '' : _guBand(_currentGlucose);
        st['gu0101Unit'] = _unit;
        await SettingsStorage.save(st);
      } catch (_) {}
    }();
  }
  String _glucoseDisplay() {
    if (_series.isEmpty) return '--';
    final double v = _currentGlucose * _unitFactor;
    return (_unit == 'mmol/L') ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
  }

  String _daysLeftLabel() {
    if (_sensorStart == null) return '-';
    // 0도 그대로 노출 (치환 제거)
    return _daysLeft.toString();
  }

  String _formatTime(DateTime t) {
    final String mm = t.minute.toString().padLeft(2, '0');
    if (_use24h) {
      return '${t.hour.toString().padLeft(2, '0')}:$mm';
    }
    final int h12 = (t.hour % 12 == 0) ? 12 : (t.hour % 12);
    final String suffix = t.hour < 12 ? 'AM' : 'PM';
    return '$h12:$mm $suffix';
  }

  /// Localized last-update line (로컬 날짜·시간)
  String _formatLastUpdateLine(DateTime t) {
    final DateTime local = t.toLocal();
    final String mo = local.month.toString().padLeft(2, '0');
    final String dy = local.day.toString().padLeft(2, '0');
    final String timePart = _formatTime(local);
    return 'dash_last_update_fmt'.tr(namedArgs: {'mo': mo, 'dy': dy, 'time': timePart});
  }

  void _onBlePhase() {
    if (!mounted) return;
    setState(() {});
  }

  // BLE 아이콘: 항상 흰색, 연결 상태에 따라 체인 아이콘 표시

  Color _lighterPrimary(Color base, [double amount = 0.22]) {
    final HSLColor hsl = HSLColor.fromColor(base);
    final double nextLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(nextLightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    // bool isDark = Theme.of(context).brightness == Brightness.dark;
    // sample realtime/status values (replace with live values when integrated)
    // sample values
    const double borderRadius = 15;
    // sample values (not used in this scope)
    return Scaffold(
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 카드
            DebugBadge(
              reqId: 'GU_01_01',
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // 데이터 유무·혈당 구간과 무관하게 항상 앱 테마 녹색 계열(primary)만 사용 (고정 hex 미사용)
                  color: _lighterPrimary(Theme.of(context).colorScheme.primary, 0.10),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1row: time left, BLE right (within card)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(children: [
                            const Icon(Icons.access_time, color: Colors.white),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _lastUpdateLine,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                        Row(children: [
                          Icon(
                            _bleShowsConnected(BleService().phase.value)
                                ? Icons.link
                                : Icons.link_off,
                            color: Colors.white,
                            size: 20,
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 2row: 좌(값+단위+추세), 우(orb)
                    Row(
                      children: [
                        // 좌측: 값 + 단위 + 추세 (55%)
                        Expanded(
                          flex: 55,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  key: _glucoseValueKey,
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _glucoseDisplay(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 80),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              DebugBadge(
                                reqId: 'GU_01_02',
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: _trendAngle(_trend5),
                                      child: const _ArrowGlow(icon: Icons.arrow_upward, color: Colors.white, size: 44),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_unit, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 우측: orb 영역 (45%)
                        Expanded(
                          flex: 45,
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                DebugBadge(
                                  reqId: 'GU_01_03',
                                  child: GlucoseGlowOrb(value: '', size: 100, cycleSeconds: 10),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RichText(
                                        text: TextSpan(children: [
                                          TextSpan(
                                            text: _daysLeftLabel(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'dash_sensor_days_suffix'.tr(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ]),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'dash_sensor_left_label'.tr(),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
            // TIR card removed per request
            VerticalSpace(height: 8),
            // 홈 화면 내 차트 탭 페이지를 임베드 (유지)
            Expanded(
              child: DebugBadge(
                reqId: 'TG_01_01',
                child: Stack(children: [                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Column(children: [
                        Expanded(child: 
                        ChartPage(
                        embedded: true,
                        hoursRange: '12h',
                        onAddMemo: _openMemoModal,
                        onPreviousData: _openPreviousDataScreen,
                        refreshTick: _chartRefresh,
                      ),
                      ),
                      ],),
                    ),
                  ),
                ]),
              ),
            ),
            // 하단 확대 버튼은 ChartPage 내부(메모 버튼 좌측)만 유지
            // 외부 FAB 제거: 내부 ChartPage 오버레이 FAB 사용
          ],
          ),
            ),
            // debug flying toast removed on main screen
          ],
        ),
      ),
    );
  }

}

// removed: old icon mapping (단일 화살표 회전으로 대체)

// 단일 화살표 회전 각도 매핑 (기준: 위쪽 화살표)
double _trendAngle(Trend5 t) {
  switch (t) {
    case Trend5.upFast:
      return 0; // 위
    case Trend5.up:
      return math.pi / 4; // 우상향
    case Trend5.flat:
      return math.pi / 2; // 오른쪽
    case Trend5.down:
      return 3 * math.pi / 4; // 우하향
    case Trend5.downFast:
      return math.pi; // 아래
  }
}

class _ArrowGlow extends StatefulWidget {
  const _ArrowGlow({required this.icon, required this.color, this.size = 20});
  final IconData icon;
  final Color color;
  final double size;
  @override
  State<_ArrowGlow> createState() => _ArrowGlowState();
}

class _ArrowGlowState extends State<_ArrowGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final double blur = 3 + 7 * _a.value; // 3..10
        final double scale = 1.0 + 0.06 * _a.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: 0.9,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Icon(widget.icon, color: widget.color, size: widget.size),
                ),
              ),
            ),
            Icon(widget.icon, color: widget.color, size: widget.size),
          ],
        );
      },
    );
  }
}

// removed: status chip (MAX/MIN 등 통계 표기)

class _AnimatedRing extends StatefulWidget {
  const _AnimatedRing({required this.size, required this.color, required this.backgroundColor, required this.strokeWidth, required this.label});
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Widget label;
  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          // fill/unfill 효과: 0.75~0.85 사이 왕복
          final double v = 0.75 + 0.10 * _a.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: widget.strokeWidth,
                  color: widget.color,
                  backgroundColor: widget.backgroundColor,
                ),
              ),
              widget.label,
            ],
          );
        },
      ),
    );
  }
}

// removed: unused remain days badge (직접 텍스트 표기)


