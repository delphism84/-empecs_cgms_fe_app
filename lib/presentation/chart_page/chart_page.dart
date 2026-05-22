import 'dart:ui' as ui;
import 'package:flutter/material.dart';
// removed unused async import
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:easy_localization/easy_localization.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({
    super.key,
    this.embedded = false,
    this.startWide = false,
    this.initialDay,
    this.hoursRange = '6h',
    this.onAddMemo,
    this.onPreviousData,
    this.refreshTick,
  });

  final bool embedded;
  final bool startWide;
  final DateTime? initialDay;
  final String hoursRange;
  final VoidCallback? onAddMemo;
  final VoidCallback? onPreviousData;
  final ValueNotifier<int>? refreshTick;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  static const double _defaultMaxY = 250.0;

  DateTime currentDay = DateTime.now();
  List<GlucosePoint> points = [];
  List<GlucoseEvent> events = [];
  String _unit = 'mg/dL';
  static const double _mmolFactor = 18.02; // mg/dL ÷ 18.02 = mmol/L (소수점 1자리)
  double _unitFactor = 1.0; // 1.0 for mg/dL, 1/18.02 for mmol/L
  bool _use24h = true;
  double _dotRadius = Constants.chartDotRadius;
  double _lowTh = 70.0;  // AR_01_04 Low / sc0101Low
  double _highTh = 180.0; // AR_01_03 High / sc0101High

  // interaction state
  int? selectedIndex;
  bool isWideMode = false;
  String? selectedEventId;

  final ScrollController recordScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialDay != null) {
      currentDay = widget.initialDay!;
    }
    isWideMode = widget.startWide;
    _fetchFromServer();
    _loadUnit();
    _loadDotSize();
    _loadThresholds();
    widget.refreshTick?.addListener(_fetchFromServer);
    GlucoseFocus.focusTime.addListener(_onExternalFocus);
    AppSettingsBus.changed.addListener(_onSettingsChanged);
    _syncSub = DataSyncBus().stream.listen(_onDataSync);
  }

  @override
  void didUpdateWidget(covariant ChartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      oldWidget.refreshTick?.removeListener(_fetchFromServer);
      widget.refreshTick?.addListener(_fetchFromServer);
    }
  }

  @override
  void dispose() {
    GlucoseFocus.focusTime.removeListener(_onExternalFocus);
    AppSettingsBus.changed.removeListener(_onSettingsChanged);
    _syncSub?.cancel();
    super.dispose();
  }

  void _onExternalFocus() {
    final DateTime? t = GlucoseFocus.focusTime.value;
    if (t == null || points.isEmpty) return;
    int best = 0;
    int bestDelta = 1 << 30;
    for (int i = 0; i < points.length; i++) {
      final int d = (points[i].time.millisecondsSinceEpoch - t.millisecondsSinceEpoch).abs();
      if (d < bestDelta) { bestDelta = d; best = i; }
    }
    setState(() { selectedIndex = best; });
    // 스크롤 뷰포트에 보이도록 이동
    final double desiredCenter = best.toDouble();
    final n = math.max(1, points.length - 1);
    windowSizeClamp() {
      int stepMinutes = 30;
      if (points.length >= 2) {
        stepMinutes = (points[1].time.difference(points[0].time).inMinutes.abs()).clamp(1, 240);
      }
      final double pointsPerHour = 60.0 / stepMinutes;
      return (widget.hoursRange == '12h' ? 12.0 : 6.0) * pointsPerHour;
    }
    final double size = windowSizeClamp().clamp(2, n.toDouble());
    final double start = (desiredCenter - size / 2).clamp(0, math.max(0.0, n - size));
    setState(() {
      // _FlGlucoseChartState의 상태에 접근할 수 없으므로 selectedIndex만 반영하고,
      // 최신 데이터 로드로 뷰포트는 자연스럽게 최신 구간으로 유지되도록 둔다.
      // 필요 시 내부 상태 공유로 확장 가능.
    });
  }

  void _onSettingsChanged() {
    // 단위/임계값 등 설정이 바뀌면 서버에서 재로드하고 y축/데이터 갱신
    _loadUnit();
    _loadDotSize();
    _loadThresholds();
    _fetchFromServer();
    setState(() {});
  }

  StreamSubscription<DataSyncEvent>? _syncSub;
  void _onDataSync(DataSyncEvent ev) {
    if (!mounted) return;
    if (ev.kind == DataSyncKind.glucosePoint) {
      // 새 포인트 수신 시 이벤트를 재조회하지 않고, 포인트만 로컬에서 갱신
      _reloadPointsOnly();
    } else if (ev.kind == DataSyncKind.glucoseBulk) {
      // 히스토리 일괄 동기화 후에는 배치로만 로드
      _reloadPointsOnly();
    } else if (ev.kind == DataSyncKind.eventBulk) {
      // 이벤트도 일괄 동기화 완료 시 1회만 재조회
      _fetchFromServer();
    } else if (ev.kind == DataSyncKind.eventItem) {
      // delete 이벤트는 로컬에서 즉시 반영하고 서버 재조회 생략
      final String? op = ev.payload['_op'] as String?;
      if (op == 'delete') {
        final String idOrEvid = ((ev.payload['id'] as String?) ?? '').trim();
        if (idOrEvid.isNotEmpty) {
          setState(() {
            events.removeWhere((x) {
              final String key = x.id.isNotEmpty ? x.id : (x.evid?.toString() ?? '');
              return key == idOrEvid;
            });
          });
          return;
        }
      }
      // 그 외(create 등)는 기존대로 재조회
      _fetchFromServer();
      // 자동 포커스/스크롤 이동 금지
    }
  }

  Future<void> _reloadPointsOnly() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final DateTime to = now.add(const Duration(hours: 1));
    try {
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final local = await GlucoseLocalRepo().range(from: from, to: to, limit: 5000, eqsn: eqsn, userId: userId);
      if (!mounted) return;
      setState(() {
        points = local
            .map((e) => GlucosePoint(
                  time: DateTime.fromMillisecondsSinceEpoch(e['time_ms'] as int).toLocal(),
                  value: ((e['value'] as num?) ?? 0).toDouble(),
                ))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
      });
    } catch (_) {}
  }

  Future<void> _fetchFromServer() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final DateTime to = now.add(const Duration(hours: 1));
    // 1) 혈당 데이터는 로컬 DB에서 즉시 로드 (오프라인에서도 동작)
    try {
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final local = await GlucoseLocalRepo().range(from: from, to: to, limit: 5000, eqsn: eqsn, userId: userId);
      if (!mounted) return;
      setState(() {
        points = local
            .map((e) => GlucosePoint(
                  time: DateTime.fromMillisecondsSinceEpoch(e['time_ms'] as int).toLocal(),
                  value: ((e['value'] as num?) ?? 0).toDouble(),
                ))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
      });
    } catch (_) {}
    // 2) 이벤트는 가능하면 서버에서 조회, 실패 시 기존 이벤트 유지
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final bool syncEvents = (st['eventsSync'] as bool?) ?? true;
      final ds = DataService();
      final ev = await ds.fetchEvents(from: from, to: to, limit: 1000, sync: syncEvents);
      if (!mounted) return;
        setState(() {
          events = ev.map((e) {
            final String t = (e['type'] as String).toString();
            final EventType ty = {
              'bloodGlucose': EventType.bloodGlucose,
              'exercise': EventType.exercise,
              'insulin': EventType.insulin,
              'memo': EventType.memo,
              'meal': EventType.meal,
              'medication': EventType.medication,
            }[t] ?? EventType.memo;
            return GlucoseEvent(
              id: (e['_id'] as String?) ?? '',
              evid: (e['evid'] as int?),
              type: ty,
              time: DateTime.parse(e['time'] as String).toLocal(),
              memo: e['memo'] as String?,
            );
          }).toList()
            ..sort((a, b) => a.time.compareTo(b.time));
        });
    } catch (_) {}
  }

  Future<void> _loadUnit() async {
    // local-first: 즉시 반영(오프라인/서버 지연 시에도 UI가 바뀌어야 함)
    try {
      final s = await SettingsStorage.load();
      final String u0 = (s['glucoseUnit'] as String? ?? 'mgdl').trim();
      final String tf = (s['timeFormat'] as String? ?? '24h').toString();
      if (!mounted) return;
      setState(() {
        _unit = (u0 == 'mmol') ? 'mmol/L' : 'mg/dL';
        _unitFactor = (_unit == 'mmol/L') ? (1.0 / _mmolFactor) : 1.0;
        _use24h = tf == '24h';
      });
    } catch (_) {}
    // best-effort: 서버 설정도 확인(단, 로컬과 다르면 로컬을 우선)
    try {
      final SettingsService ss = SettingsService();
      final Map<String, dynamic> app = await ss.getAppSetting();
      final String u = (app['unit'] as String?) ?? 'mg/dL';
      final String normalized = (u == 'mmol/L') ? 'mmol/L' : 'mg/dL';
      if (!mounted) return;
      if (normalized != _unit) return;
      setState(() {
        _unit = normalized;
        _unitFactor = (_unit == 'mmol/L') ? (1.0 / _mmolFactor) : 1.0;
      });
    } catch (_) {}
  }

  Future<void> _loadDotSize() async {
    try {
      final s = await SettingsStorage.load();
      final int ds = ((s['chartDotSize'] as num?)?.toInt() ?? 2).clamp(1, 10);
      setState(() { _dotRadius = ds.toDouble(); });
    } catch (_) {}
  }

  Future<void> _loadThresholds() async {
    try {
      final s = await SettingsStorage.load();
      double low = (s['sc0101Low'] as num?)?.toDouble() ?? 70;
      double high = (s['sc0101High'] as num?)?.toDouble() ?? 180;
      // AR_01_04(Low) / AR_01_03(High) 알람 설정값 우선 반영
      final dynamic ac = s['alarmsCache'];
      if (ac is List) {
        for (final e in ac.cast<Map>()) {
          final map = e.cast<String, dynamic>();
          final t = (map['type'] ?? '').toString();
          final th = (map['threshold'] as num?)?.toDouble();
          if (th == null || !th.isFinite) continue;
          if (t == 'low') low = th.clamp(40.0, 120.0);
          if (t == 'high') high = th.clamp(120.0, 300.0);
        }
      }
      if (!mounted) return;
      setState(() { _lowTh = low; _highTh = high; });
    } catch (_) {}
  }

  // 날짜 단위 이동 제거 (스와이프로 시간축 이동)

  double _averageGlucose() {
    if (points.isEmpty) return 0;
    final double sum = points.map((p) => p.value).reduce((a, b) => a + b);
    return sum / points.length;
  }

  double _stdDevGlucose() {
    if (points.length < 2) return 0;
    final double avg = _averageGlucose();
    final double varSum = points.map((p) => math.pow(p.value - avg, 2).toDouble()).reduce((a, b) => a + b);
    final double variance = varSum / (points.length - 1);
    return math.sqrt(variance);
  }

  // trend calc moved to tooltip; no separate trend indicator for fl_chart version

  double _resolvedMaxY() {
    double maxVal = 0.0;
    for (final p in points) {
      if (p.value > maxVal) maxVal = p.value;
    }
    // 50의 배수로 올림, 기본 250 유지
    final int step = 50;
    final double rounded = (maxVal <= 0)
        ? _defaultMaxY
        : ( ((maxVal + (step - 1)) ~/ step) * step ).toDouble();
    return math.max(_defaultMaxY, rounded);
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 라벨/요일 미사용 (시간축 연속 스와이프)
    final double avg = _averageGlucose();
    final double std = _stdDevGlucose();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // theme

    // y-axis fixed: no dynamic/auto scale
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: null,
      body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                  children: [
                      // graph area (rounded box + light grey border 1px)
                      Expanded(flex: 5,
                        child: Container(
                          margin: isWideMode ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 0, 0, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              
                              Positioned.fill(
                                child: _FlGlucoseChart(
                                  points: points,
                                  events: events,
                                  // y축: 기본 250, 데이터 최대값 기준 50의 배수로 자동 조절
                                  maxY: _resolvedMaxY(),
                                  isWideMode: isWideMode,
                                  average: avg,
                                  stddev: std,
                                  targetY: 140,
                                  lowTh: _lowTh,
                                  highTh: _highTh,
                                  initialHours: _hoursFromRange(widget.hoursRange),
                                  displayUnit: _unit,
                                  unitFactor: _unitFactor,
                                  use24h: _use24h,
                                  dotRadius: _dotRadius,
                                  onSelectIndex: (i) {
                                    setState(() => selectedIndex = i);
                                    // 선택 지점과 가장 가까운 이벤트로 리스트 스크롤 연동
                                    if (!isWideMode && events.isNotEmpty) {
                                      final DateTime pt = points[i].time;
                                      int best = 0;
                                      int bestDelta = 1 << 30;
                                      for (int k = 0; k < events.length; k++) {
                                        final int d = (events[k].time.millisecondsSinceEpoch - pt.millisecondsSinceEpoch).abs();
                                        if (d < bestDelta) {
                                          bestDelta = d;
                                          best = k;
                                        }
                                      }
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        recordScrollController.animateTo(
                                          best * 72.0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                        );
                                      });
                                    }
                                  },
                                  onEventTap: (eventId) {
                                    setState(() => selectedEventId = eventId);
                                    final int idx = events.indexWhere((e) => e.id == eventId);
                                    if (idx != -1) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        recordScrollController.animateTo(
                                          idx * 72.0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              // removed chart overlay maximize; now in top bar
                            // wide 평균 표시는 내부 차트에서 뷰포트 기준으로 렌더링
                  ],
                ),
                        ),
                      ),
                      if (!isWideMode) const Divider(height: 1),
                      // records area (하단까지 확장) + 내부 오버레이 FAB
                      if (!isWideMode)
                        Expanded(flex: 3,
                          child: Stack(
                            children: [
                              ListView.separated(
                                controller: recordScrollController, 
                                itemBuilder: (context, index) {
                                  final GlucoseEvent e = events[index];
                                  final bool isSel = (selectedEventId != null && selectedEventId == e.id);
                                  final Color? bg = isSel ? Colors.green.withOpacity(0.08) : null;
                                  return Container(
                                    key: ValueKey(e.id.isNotEmpty ? e.id : (e.evid?.toString() ?? 'ev_$index')),
                                    color: bg,
                                    child: ListTile(
                                      visualDensity: const VisualDensity(vertical: -2),
                                      minLeadingWidth: 0,
                                      horizontalTitleGap: 8,
                                      dense: true,
                                      leading: _EventBadge(type: e.type, size: 28),
                                      title: Text(
                                        '${_eventLabel(e.type)} · ${_formatDateTime(e.time)}',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontSize: getFontSize(13),
                                          fontFamily: 'Gilroy-Medium',
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                                        ),
                                      ),
                                      subtitle: Text(
                                        e.memo ?? '',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : ColorConstant.bluegray400,
                                          fontSize: getFontSize(11),
                                          fontFamily: 'Gilroy-Medium',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      onTap: () async {
                                        final result = await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => EventViewPage(initial: e)),
                                        );
                                        if (result is String) {
                                          if (result == 'deleted') {
                                            final ds = DataService();
                                            final String delId = (e.id.isNotEmpty) ? e.id : (e.evid?.toString() ?? '');
                                            final ok = await ds.deleteEvent(delId);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(ok ? 'chart_event_deleted'.tr() : 'chart_event_delete_failed'.tr())),
                                            );
                                            if (ok) {
                                              setState(() {
                                                final String targetId = delId;
                                                events.removeWhere((x) {
                                                  final String xId = x.id;
                                                  final String xEvid = x.evid?.toString() ?? '';
                                                  if (xId.isNotEmpty) return xId == targetId;
                                                  return xEvid == targetId;
                                                });
                                              });
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  );
                                },
                                separatorBuilder: (context, _) => const Divider(height: 1),
                                itemCount: events.length,
                              ),
                              if (widget.onPreviousData != null || widget.onAddMemo != null)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.onPreviousData != null) ...[
                                        FloatingActionButton.small(
                                          heroTag: 'chart_prev_data',
                                          onPressed: widget.onPreviousData,
                                          tooltip: 'chart_tooltip_previous_data'.tr(),
                                          child: const Icon(Icons.history),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      if (widget.onAddMemo != null)
                                        FloatingActionButton.small(
                                          heroTag: 'chart_memo',
                                          onPressed: widget.onAddMemo,
                                          child: const Icon(Icons.sticky_note_2_outlined),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  // removed dynamic y-axis resolver; fixed to _defaultMaxY (250)

  static IconData _iconForEvent(EventType t) {
    switch (_categoryForType(t)) {
      case EventCategory.bloodGlucose:
        // 혈액방울 아이콘으로 변경
        return Icons.water_drop;
      case EventCategory.insulin:
        return Icons.vaccines;
      case EventCategory.medication:
        return Icons.medication;
      case EventCategory.exercise:
        return Icons.directions_run;
      case EventCategory.meal:
        return Icons.restaurant;
      case EventCategory.memo:
        return Icons.sticky_note_2_outlined;
    }
  }

  static Color _colorForEvent(EventType t) {
    // Memo(녹색)로 통일
    return Colors.green;
  }

  static String _eventLabel(EventType t) {
    switch (_categoryForType(t)) {
      case EventCategory.bloodGlucose:
        return 'chart_type_blood_glucose'.tr();
      case EventCategory.insulin:
        return 'chart_type_insulin'.tr();
      case EventCategory.medication:
        return 'chart_type_medication'.tr();
      case EventCategory.exercise:
        return 'chart_type_exercise'.tr();
      case EventCategory.meal:
        return 'chart_type_meal'.tr();
      case EventCategory.memo:
        return 'chart_type_memo'.tr();
    }
  }

  // replaced by _formatDateTime

  static String _formatDateTime(DateTime d) {
    final String yyyy = d.year.toString().padLeft(4, '0');
    final String mm1 = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm1-$dd $hh:$mm';
  }

  double _hoursFromRange(String r) {
    if (r.endsWith('h')) {
      final String n = r.substring(0, r.length - 1);
      final double? v = double.tryParse(n);
      if (v != null && v > 0) return v;
    }
    return 12; // default 12h
  }

}

class _InteractiveChart extends StatefulWidget {
  const _InteractiveChart({
    required this.points,
    required this.events,
    required this.maxY,
    required this.isWideMode,
    required this.scaleX,
    required this.translateX,
    required this.onInteraction,
    required this.onSelectIndex,
    required this.onEventTap,
    required this.hoursRange,
  });

  final List<GlucosePoint> points;
  final List<GlucoseEvent> events;
  final double maxY;
  final bool isWideMode;
  final double scaleX;
  final double translateX;
  final void Function(double scaleX, double translateX) onInteraction;
  final void Function(int index) onSelectIndex;
  final void Function(String eventId) onEventTap;
  final String hoursRange;

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  // view transform state (managed by parent via onInteraction)
  double startScaleX = 1.0;
  double startTranslateX = 0.0;
  // removed pan tracking in touch-disabled mode

  // inspect mode
  bool inspectMode = false;
  int? selectedIndex;
  Timer? _touchTimer;

  // hit tolerances (unused while touch disabled)
  // static const double yHitTolerancePx = 8.0;
  // static const double xHitTolerancePx = 12.0;

  @override
  void dispose() {
    _touchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        // compute time range for top date label (fallback to now if empty)
        DateTime minTime = DateTime.now();
        DateTime maxTime = minTime;
        if (widget.points.isNotEmpty) {
          minTime = widget.points.first.time;
          maxTime = widget.points.last.time;
          for (final p in widget.points) {
            if (p.time.isBefore(minTime)) minTime = p.time;
            if (p.time.isAfter(maxTime)) maxTime = p.time;
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _flashSelectAt(d.localPosition.dx, width),
          onPanDown: (d) => _flashSelectAt(d.localPosition.dx, width),
          child: CustomPaint(
          size: Size(width, height),
          painter: GlucoseChartPainter(
            points: widget.points,
            maxY: widget.maxY,
            scaleX: widget.scaleX,
            translateX: widget.translateX,
            selectedIndex: selectedIndex,
            showXLabelsFor: widget.hoursRange,
              minTime: minTime,
              maxTime: maxTime,
            ),
          ),
        );
      },
    );
  }

  void _flashSelectAt(double dx, double width) {
    if (widget.points.isEmpty) return;
    final int idx = _nearestIndexForDx(dx, width);
    setState(() { selectedIndex = idx; });
    _touchTimer?.cancel();
    _touchTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() { selectedIndex = null; });
    });
  }

  int _nearestIndexForDx(double dx, double width) {
    if (widget.points.length == 1) return 0;
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < widget.points.length; i++) {
      final double xi = _xForIndexLocal(i, width);
      final double d = (xi - dx).abs();
      if (d < bestDist) { bestDist = d; best = i; }
    }
    return best;
  }

  double _xForIndexLocal(int i, double width) {
    final int n = widget.points.length;
    if (n <= 1) return width / 2 + widget.translateX;
    final double x = (i / (n - 1)) * width;
    final double transformed = ((x - width / 2) * widget.scaleX) + width / 2 + widget.translateX;
    return transformed;
  }

  // int _hitTestX(double dx, double width) { return 0; }

  // double? _yForIndex(int idx, double height) => null;

  // double _xForIndex(int i, double width) => width / 2;

  // Offset _posForIndex(int idx, double width, double height) => Offset.zero;

  // double _xForTime(DateTime t, double width) => width / 2;
}

class GlucoseChartPainter extends CustomPainter {
  GlucoseChartPainter({
    required this.points,
    required this.maxY,
    required this.scaleX,
    required this.translateX,
    this.selectedIndex,
    required this.showXLabelsFor,
    required this.minTime,
    required this.maxTime,
  });

  final List<GlucosePoint> points;
  final double maxY;
  final double scaleX;
  final double translateX;
  final int? selectedIndex;
  final String showXLabelsFor;
  final DateTime minTime;
  final DateTime maxTime;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;

    // grid horizontal lines (5 levels)
    for (int i = 0; i <= 5; i++) {
      final double y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // draw later again on top to avoid covering by paths
    final DateTime latest = maxTime;
    final double hrs = _hoursFromRange(showXLabelsFor);
    final DateTime periodStart = latest.subtract(Duration(hours: hrs.round()));
    final DateTime earliest = minTime;
    final DateTime start = earliest.isBefore(periodStart) ? earliest : periodStart;
    // 상단 날짜 카드는 범위가 아닌 중앙 날짜만 표시
    final int midMs = ((start.millisecondsSinceEpoch + latest.millisecondsSinceEpoch) ~/ 2);
    final DateTime center = DateTime.fromMillisecondsSinceEpoch(midMs);
    final String _topLabel = _formatDateOnly(center);

    if (points.isEmpty) return;

    final Path path = Path();
    final Paint linePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < points.length; i++) {
      final double x = _xForIndex(i, size.width);
      final double y = size.height - (points[i].value / maxY * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // draw point only when selected (hide all dots by default)
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < points.length) {
      final Paint dot = Paint()..color = Colors.blueAccent;
      final double x = _xForIndex(selectedIndex!, size.width);
      final double y = size.height - (points[selectedIndex!].value / maxY * size.height);
      canvas.drawCircle(Offset(x, y), 3, dot);
    }

    // 항상 마지막 데이터 포인트를 표시
    if (points.isNotEmpty) {
      final Paint lastDot = Paint()..color = Colors.blueAccent;
      final double lx = _xForIndex(points.length - 1, size.width);
      final double ly = size.height - (points.last.value / maxY * size.height);
      canvas.drawCircle(Offset(lx, ly), 3.6, lastDot);
    }

    // selection indicator
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < points.length) {
      final double sx = _xForIndex(selectedIndex!, size.width);
      final double sy = size.height - (points[selectedIndex!].value / maxY * size.height);
      final Paint sel = Paint()..color = Colors.redAccent;
      canvas.drawCircle(Offset(sx, sy), 4.5, sel);
      // vertical line
      final Paint v = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), v);
    }

    // draw top date label on the very top layer (with background chip)
    final TextPainter tp2 = TextPainter(
      text: TextSpan(text: _topLabel, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w700)),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: size.width - 12);
    final double tx = (size.width - tp2.width) / 2;
    final double ty = 8;
    final RRect bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(tx - 6, ty - 4, tp2.width + 12, tp2.height + 8),
      const Radius.circular(6),
    );
    final Paint bgp = Paint()..color = const Color(0xCCFFFFFF);
    canvas.drawRRect(bg, bgp);
    // debug border to verify label box area
    final Paint dbg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red;
    canvas.drawRRect(bg, dbg);
    tp2.paint(canvas, Offset(tx, ty));

  }

  double _xForIndex(int i, double width) {
    if (points.length == 1) return width / 2 + translateX;
    final double x = (i / (points.length - 1)) * width;
    final double tx = _clampedTranslateX(width);
    final double transformed = ((x - width / 2) * scaleX) + width / 2 + tx;
    return transformed;
  }

  double _clampedTranslateX(double width) {
    if (points.length <= 1) return translateX;
    const double leftPad = 8.0;
    const double rightPad = 8.0;
    double tx = translateX;
    // compute transformed ends with current translate
    double leftX = _xForIndexWithTranslate(0, width, tx);
    double rightX = _xForIndexWithTranslate(points.length - 1, width, tx);
    if (leftX > leftPad) {
      tx -= (leftX - leftPad);
    }
    rightX = _xForIndexWithTranslate(points.length - 1, width, tx);
    if (rightX < width - rightPad) {
      tx += ((width - rightPad) - rightX);
    }
    return tx;
  }

  double _xForIndexWithTranslate(int i, double width, double tx) {
    if (points.length == 1) return width / 2 + tx;
    final double x = (i / (points.length - 1)) * width;
    return ((x - width / 2) * scaleX) + width / 2 + tx;
  }

  @override
  bool shouldRepaint(covariant GlucoseChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxY != maxY ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.translateX != translateX ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.showXLabelsFor != showXLabelsFor;
  }

  int _xLabelStep(String r) {
    // 시간 범위에 따라 레이블 샘플링 조절 (겹침 방지)
    if (r == '6h') return 4;   // 3시간당 1개
    if (r == '12h') return 8;  // 4시간당 1개
    if (r == '24h') return 12; // 6시간당 1개
    return 8; // default
  }

  String _formatHour(DateTime d) {
    final int h = d.hour;
    final int h12 = (h % 12 == 0) ? 12 : (h % 12);
    final String suffix = (h < 12) ? 'AM' : 'PM';
    return '$h12$suffix';
  }

  String _formatDateOnly(DateTime d) {
      final String yyyy = d.year.toString().padLeft(4, '0');
      final String mm = d.month.toString().padLeft(2, '0');
      final String dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
    }

  // removed: range label formatter (상단 날짜 카드가 중앙 날짜만 표시하도록 변경)

  double _hoursFromRange(String r) {
    if (r.endsWith('h')) {
      final String n = r.substring(0, r.length - 1);
      final double? v = double.tryParse(n);
      if (v != null && v > 0) return v;
    }
    return 12;
  }
}

class GlucosePoint {
  GlucosePoint({required this.time, required this.value});
  final DateTime time;
  final double value;
}

// 6개 카테고리에 맞춘 간소화된 이벤트 타입
enum EventType { bloodGlucose, insulin, medication, exercise, meal, memo }

class GlucoseEvent {
  GlucoseEvent({required this.id, this.evid, required this.type, required this.time, this.memo});
  final String id;
  final int? evid;
  final EventType type;
  final DateTime time;
  final String? memo;
}

// Canonical categories to unify icon set across features
enum EventCategory { bloodGlucose, insulin, medication, exercise, meal, memo }

EventCategory _categoryForType(EventType t) {
  switch (t) {
    case EventType.bloodGlucose:
      return EventCategory.bloodGlucose;
    case EventType.insulin:
      return EventCategory.insulin;
    case EventType.medication:
      return EventCategory.medication;
    case EventType.exercise:
      return EventCategory.exercise;
    case EventType.meal:
      return EventCategory.meal;
    case EventType.memo:
      return EventCategory.memo;
  }
}

class _EventBadge extends StatelessWidget {
  const _EventBadge({required this.type, this.size = 32});
  final EventType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final _EventAsset asset = _eventAsset(type);
    final Color ring = Colors.white;
    final Color bg = asset.backgroundColor ?? _ChartPageState._colorForEvent(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Stack(children: [
        // white ring
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: size * 0.10),
              ),
            ),
          ),
        ),
        // center icon (asset or fallback material icon)
        Center(
          child: SizedBox(
            width: size * 0.55,
            height: size * 0.55,
            child: asset.widget ?? Icon(
              _ChartPageState._iconForEvent(type),
              size: size * 0.55,
              color: Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}

class _EventAsset {
  const _EventAsset({this.widget, this.backgroundColor});
  final Widget? widget;
  final Color? backgroundColor;
}

_EventAsset _eventAsset(EventType type) {
  // 에셋 파일명을 필요시 여기에 매핑한다. 없으면 null로 두어 머티리얼 아이콘을 폴백.
  switch (type) {
    case EventType.meal:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFFFFB74D)); // meal – orange
    case EventType.medication:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFF26A69A)); // medication – teal
    case EventType.exercise:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFF5C6BC0)); // exercise – indigo
    case EventType.insulin:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFFAB47BC)); // insulin – purple
    case EventType.bloodGlucose:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFFE57373)); // blood glucose – red
    case EventType.memo:
      return const _EventAsset(widget: null, backgroundColor: Color(0xFF2ECC71)); // memo – green
  }
}

enum TrendArrow { up, down, steady }

class EventViewPage extends StatelessWidget {
  const EventViewPage({super.key, required this.initial});

  final GlucoseEvent initial;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController memo = TextEditingController(text: initial.memo ?? '');
    return Scaffold(
      appBar: AppBar(title: Text('chart_event_detail'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 카드: 아이콘 + 타입 + 시간
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: ColorConstant.green500, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _EventBadge(type: initial.type, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ChartPageState._eventLabel(initial.type),
                            style: TextStyle(fontSize: getFontSize(16), fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _ChartPageState._formatDateTime(initial.time),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 메모 카드: 로그인 폼과 동일한 입력 필드 톤 사용
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: ColorConstant.green500, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('chart_memo'.tr(), style: TextStyle(fontSize: getFontSize(14), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    CustomTextFormField(
                      isDark: isDark,
                      width: double.infinity,
                      controller: memo,
                      variant: TextFormFieldVariant.OutlineDeeppurple101,
                      padding: TextFormFieldPadding.PaddingT19,
                      hintText: 'chart_memo_hint'.tr(),
                      textInputAction: TextInputAction.newline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 액션 버튼: 로그인 화면의 버튼 스타일 사용
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('deleted'),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('common_delete'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop('saved:${memo.text}'),
                    icon: const Icon(Icons.save),
                    label: Text('common_save'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlGlucoseChart extends StatefulWidget {
  const _FlGlucoseChart({
    required this.points,
    required this.events,
    required this.maxY,
    required this.isWideMode,
    required this.average,
    required this.stddev,
    required this.targetY,
    required this.lowTh,
    required this.highTh,
    required this.onSelectIndex,
    required this.onEventTap,
    this.initialHours = 12,
    required this.displayUnit,
    required this.unitFactor,
    this.use24h = true,
    this.dotRadius,
  });

  final List<GlucosePoint> points;
  final List<GlucoseEvent> events;
  final double maxY;
  final bool isWideMode;
  final double average;
  final double stddev;
  final double targetY;
  final double lowTh;   // AR_01_04 Low
  final double highTh;  // AR_01_03 High
  final void Function(int index) onSelectIndex;
  final void Function(String eventId) onEventTap;
  final double initialHours;
  final String displayUnit;
  final double unitFactor;
  final bool use24h;
  // dynamic dot radius from local settings
  final double? dotRadius;

  @override
  State<_FlGlucoseChart> createState() => _FlGlucoseChartState();
}

class _FlGlucoseChartState extends State<_FlGlucoseChart> {
  static double? _cachedWindowStart;
  static double? _cachedWindowSize;
  bool _initialSnapDone = false;
  int? touchedIndex;
  Timer? _touchTimer;
  // recent interaction timestamp to suppress auto-scroll for a short time window
  DateTime? _lastInteractionAt;
  double? _oneFingerLastDx;
  String? _selectedEventId;
  // time-based viewport in milliseconds
  double windowStart = 0; // start time (ms since epoch)
  double windowSize = 0;  // duration (ms)
  double startWindowStart = 0;
  double startWindowSize = 5;
  Offset? lastFocal;
  // removed bottom popup feature; using top label at crosshair instead
  int _activePointers = 0; // 1-finger: data touch, 2-finger: pan/zoom
  final Map<int, Offset> _pointerPositions = <int, Offset>{};
  bool _twoFingerActive = false;
  Offset? _twoStartFocal;
  Offset? _twoPrevFocal;
  double _twoStartSpan = 1.0;
  double _panelWidth = 1.0;
  // touch circle indicator
  Offset? _touchCircle;
  Timer? _touchCircleTimer;
  // unified right padding for viewport computations (in pixels)
  static const double kRightPadPx = 10.0;
  // selection sensitivity reverted to immediate updates
  // touch pulse visualization removed
  // measure top popup badge width to center it exactly on crosshair
  final GlobalKey _badgeKey = GlobalKey();
  double _badgeWidth = 144.0; // initial guess; updated after first build
  double _lastRightEnd = 0.0;
  int _snapRightEndMs(DateTime now) {
    // 현재시간을 3시간 배수 경계(예: 03:00, 06:00, 09:00 ...)의 직후로 스냅
    final DateTime local = now;
    final int hour = local.hour;
    final int snappedHour = ((hour / 3).ceil()) * 3; // 다음 3의 배수 시각
    final DateTime snapped = DateTime(local.year, local.month, local.day, snappedHour).add(const Duration(minutes: 0));
    return snapped.millisecondsSinceEpoch;
  }

  double _dataRightEndMs() {
    final double nowPad = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch.toDouble();
    double lastPoint = widget.points.isNotEmpty ? widget.points.last.time.millisecondsSinceEpoch.toDouble() : 0.0;
    double lastEvent = widget.events.isNotEmpty ? widget.events.last.time.millisecondsSinceEpoch.toDouble() : 0.0;
    final double last = math.max(lastPoint, lastEvent);
    if (last <= 0) return nowPad;
    return math.min(last, nowPad);
  }

  double _rightEndMs() {
    return _dataRightEndMs();
  }

  void _clampWindow() {
    // 좌/우 모두 데이터 범위를 벗어나지 않도록 창(windowStart, windowSize)을 클램프한다.
    // Keep windowSize positive and finite.
    if (!windowSize.isFinite || windowSize <= 0) {
      windowSize = 12 * 3600000.0; // default 12h
    }
    final double widthPx = (_panelWidth <= 0) ? 1.0 : _panelWidth;
    // 우측 패딩(px)을 창 크기 비율로 ms 환산 (좌측 패딩은 클램프에서 사용하지 않음)
    final double rightPadMs = windowSize * (kRightPadPx / widthPx);

    final double dataRight = _rightEndMs();

    // 허용 창의 최소/최대 시작점
    final double maxRight = dataRight + rightPadMs;
    final double currentRight = windowStart + windowSize;

    // 우측 경계 초과 시 우측에 맞춤
    if (currentRight > maxRight) {
      windowStart = maxRight - windowSize;
    }
    // 좌측은 최소 기간 보장: 데이터가 부족해도 창 크기를 유지하도록 제한하지 않음
    // 필요 시 원하는 최소 시작점으로 제한하려면 다음 라인을 사용
    // final double minStart = (dataRight - windowSize);
    // if (windowStart < minStart) windowStart = minStart;
  }

  // 데이터의 가장 이른 시각(ms). 포인트/이벤트가 없으면 현재 시각 기준으로 보수적 반환
  double _dataLeftStartMs() {
    double first = double.infinity;
    if (widget.points.isNotEmpty) {
      // points는 시간 오름차순이라고 가정
      first = math.min(first, widget.points.first.time.millisecondsSinceEpoch.toDouble());
    }
    if (widget.events.isNotEmpty) {
      first = math.min(first, widget.events.first.time.millisecondsSinceEpoch.toDouble());
    }
    if (first == double.infinity) {
      // 데이터가 없으면 현재 - 창 절반 정도로 설정해 과도한 좌측 이동 방지
      final double now = DateTime.now().millisecondsSinceEpoch.toDouble();
      return now - (windowSize > 0 ? windowSize / 2 : 6 * 3600000.0);
    }
    return first;
  }

  double _tickIntervalMs() {
    // 범위 스냅: 3/6/12/24h만 허용
    final double currentHours = (windowSize / 3600000.0).clamp(0.5, 240.0);
    final List<double> allowed = <double>[3, 6, 12, 24];
    double snap = allowed.first;
    double bestDelta = (currentHours - snap).abs();
    for (final double h in allowed) {
      final double d = (currentHours - h).abs();
      if (d < bestDelta) { snap = h; bestDelta = d; }
    }
    // 간격 매핑: 3->1h, 6->1h, 12->3h, 24->3h
    final double tickHours = (snap <= 6.0) ? 1.0 : 3.0;
    return (tickHours * 3600000.0);
  }

  String _formatHoursLabel() {
    final double hRaw = (windowSize / 3600000.0);
    final double h = hRaw.isFinite ? hRaw.clamp(0.1, 240.0) : 3.0;
    // 라벨 스냅: 3/6/12/24
    final List<double> allowed = <double>[3, 6, 12, 24];
    double best = allowed.first;
    double bestDelta = (h - best).abs();
    for (final double a in allowed) {
      final double d = (h - a).abs();
      if (d < bestDelta) { best = a; bestDelta = d; }
    }
    final double snapped = best;
    return '${snapped.toStringAsFixed(0)} Hours';
  }
  double _pointsPerHour() {
    int stepMinutes = 30;
    if (widget.points.length >= 2) {
      stepMinutes = (widget.points[1].time.difference(widget.points[0].time).inMinutes.abs()).clamp(1, 240);
    }
    return 60.0 / stepMinutes;
  }

  double _rightPadPoints() {
    final double pph = _pointsPerHour();
    final double currentHours = (windowSize / pph).clamp(0.5, 240.0);
    final List<double> allowed = <double>[3, 6, 12, 24];
    double best = allowed.first;
    double bestDelta = (currentHours - best).abs();
    for (final double h in allowed) {
      final double d = (currentHours - h).abs();
      if (d < bestDelta) { best = h; bestDelta = d; }
    }
    final double tickHours = best <= 3.0 ? 0.5 : (best <= 6.0 ? 1.0 : (best <= 12.0 ? 2.0 : 4.0));
    return tickHours * pph;
  }

  // removed: _effectiveWindowSize (ms 기반으로 일원화)
  // focus/scrub mode via long-press
  // scrub mode, haptic vars removed (unused)
  // removed unused haptic buckets

  @override
  void initState() {
    super.initState();
    // 초기 뷰포트: 캐시가 있으면 복원, 없으면 최신 데이터의 우측에 맞춰 시작
    if (_cachedWindowStart != null && _cachedWindowSize != null) {
      windowStart = _cachedWindowStart!;
      windowSize = _cachedWindowSize!;
    } else {
      final int desiredMs = (widget.initialHours * 3600000).round();
      final double rightEnd = _rightEndMs();
      windowSize = desiredMs.toDouble();
      windowStart = (rightEnd - windowSize);
    }
    _lastRightEnd = _rightEndMs();
    // removed: external date callback
  }

  @override
  void didUpdateWidget(covariant _FlGlucoseChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 사용자 상호작용 여부 + 최근 입력(2초 이내) 판단
    final bool recentlyInteracted = _lastInteractionAt != null &&
        DateTime.now().difference(_lastInteractionAt!).inMilliseconds < 2000;
    final bool userInteracting = (_activePointers > 0) || _twoFingerActive || (touchedIndex != null) || recentlyInteracted;

    // 데이터가 최초 로드되어 points가 비지 않았을 때, 우측 끝(+패딩)으로 스냅 (1회)
    if (!_initialSnapDone && widget.points.isNotEmpty && !userInteracting) {
      _snapToRightWithPadding();
      _initialSnapDone = true;
    }

    // 초기화면 크기 변경: 우측 정렬 유지
    if (oldWidget.initialHours != widget.initialHours) {
      final double rightEnd = windowStart + windowSize;
      final int desiredMs = (widget.initialHours * 3600000).round();
      windowSize = desiredMs.toDouble();
      windowStart = (rightEnd - windowSize);
      setState(() {});
    }

    // 포인트 추가 여부 판단
    final bool appended = widget.points.isNotEmpty &&
        (oldWidget.points.isEmpty ||
            widget.points.length > oldWidget.points.length ||
            widget.points.last.time.isAfter(
                oldWidget.points.isNotEmpty ? oldWidget.points.last.time : DateTime.fromMillisecondsSinceEpoch(0)));

    final double newRight = _rightEndMs();
    final double currentRight = windowStart + windowSize;

    if (appended) {
      if (!userInteracting) {
        // 드래그/터치 중이 아니면 최신 데이터 우측으로 스냅
        _snapToRightWithPadding();
      } else {
        // 사용자가 우측에 거의 붙어있던 경우에만 우측 정렬 유지
        if ((currentRight - _lastRightEnd).abs() <= 1000.0) {
          final double panelW = (_panelWidth <= 0) ? 1.0 : _panelWidth;
          final double padMs = windowSize * (kRightPadPx / panelW);
          final double maxRight = newRight + padMs;
          windowStart = maxRight - windowSize;
          setState(() {});
        }
      }
    } else {
      // 포인트 추가가 없어도 우측에 붙어있다면 우측 정렬 유지 (기존 동작)
      if (!userInteracting && (currentRight - _lastRightEnd).abs() <= 1000.0) {
        final double panelW = (_panelWidth <= 0) ? 1.0 : _panelWidth;
        final double padMs = windowSize * (kRightPadPx / panelW);
        final double maxRight = newRight + padMs;
        windowStart = maxRight - windowSize;
        setState(() {});
      }
    }

    _lastRightEnd = newRight;
    // setState 호출은 위 분기에서 수행됨
  }

  void _snapToRightWithPadding() {
    final double widthPx = (_panelWidth <= 0) ? 1.0 : _panelWidth;
    final double padMs = windowSize * (kRightPadPx / math.max(1.0, widthPx));
    final double rightEnd = _rightEndMs();
    final double maxRight = rightEnd + padMs;
    windowStart = maxRight - windowSize;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _touchCircleTimer?.cancel();
    // 화면 전환 시 마지막 뷰포트 상태 보존
    _cachedWindowStart = windowStart;
    _cachedWindowSize = windowSize;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final List<FlSpot> spots = [
      for (int i = 0; i < widget.points.length; i++)
        FlSpot(widget.points[i].time.millisecondsSinceEpoch.toDouble(), widget.points[i].value)
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Column(children: [
        SizedBox(height: 16),
        Expanded(child: 
          Stack(
          children: [
            // glow when two-finger gesture is active
            if (_twoFingerActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.12),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 20, // leave space for top date strip (increased)
              bottom: 0,
              child: LayoutBuilder(builder: (context, c) {
                final double panelWidth = c.maxWidth;
                final double safeWidth = math.max(1.0, panelWidth);
                final double padMs = windowSize * (kRightPadPx / safeWidth);
                final double maxXWithPad = windowStart + windowSize + padMs;
                // keep for overlays
                _panelWidth = panelWidth;
                return LineChart(
        LineChartData(
          // plot/axis insets for consistent overlay alignment
          // keep small left gap to reduce Y-axis to chart spacing
          minX: windowStart,
          maxX: maxXWithPad,
          minY: 0,
          maxY: widget.maxY,
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 50,
            verticalInterval: _tickIntervalMs(),
            getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFE0E0E0), strokeWidth: 1),
            getDrawingVerticalLine: (v) => const FlLine(color: Color(0xFFE0E0E0), strokeWidth: 1),
          ),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    // In Range 영역만 배경 표시 (AR_01_03/AR_01_04 설정값 반영)
                    HorizontalRangeAnnotation(
                      y1: widget.lowTh,
                      y2: widget.highTh,
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ],
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // explicit 0-line to anchor baseline at the bottom
                    HorizontalLine(y: 0, color: const Color(0xFFE0E0E0), strokeWidth: 1),
                    // in-range lower boundary (red) dashed
                    HorizontalLine(
                      y: widget.lowTh,
                      color: Colors.red,
                      strokeWidth: 1,
                      dashArray: [4, 3],
                    ),
                    // in-range upper boundary (dark orange) dashed
                    HorizontalLine(
                      y: widget.highTh,
                      color: const Color(0xFFEF6C00),
                      strokeWidth: 1,
                      dashArray: [4, 3],
                    ),
                  ],
                  verticalLines: [
                    for (int i = 0; i < widget.events.length; i++)
                      VerticalLine(
                        x: widget.events[i].time.millisecondsSinceEpoch.toDouble(),
                        color: _ChartPageState._colorForEvent(widget.events[i].type).withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [4, 3],
                        label: VerticalLineLabel(show: false),
                      ),
                  ],
                ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
                reservedSize: 0,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _tickIntervalMs(),
                getTitlesWidget: (value, meta) {
                  final DateTime t = DateTime.fromMillisecondsSinceEpoch(value.round());
                  final int h = t.hour;
                  final String labelStr;
                  if (widget.use24h) {
                    labelStr = h.toString().padLeft(2, '0');
                  } else {
                    final int h12 = (h % 12 == 0) ? 12 : (h % 12);
                    final String suffix = (h < 12) ? 'AM' : 'PM';
                    labelStr = '$h12$suffix';
                  }
                  // 좌우 가드 40px: 해당 영역에 해당하는 값은 빈 문자열 처리
                  const double guardPx = 1.0;
                  final double panelW = _panelWidth <= 0 ? 1.0 : _panelWidth;
                  final double guardRatio = (guardPx / panelW).clamp(0.0, 0.49);
                  final double minXv = windowStart;
                  final double maxXv = windowStart + windowSize;
                  final double ratio = ((value - minXv) / (maxXv - minXv)).clamp(0.0, 1.0);
                  final bool inGuard = (ratio <= guardRatio) || (ratio >= 1.0 - guardRatio);
                  final String label = inGuard ? '' : labelStr;
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: const LineTouchData(
            enabled: false,
            handleBuiltInTouches: false,
          ),
          lineBarsData: (() {
            // 상태별(LOW/IN/HIGH)로 선을 분할해 각자 색상으로 직선 렌더링 (AR_01_03/AR_01_04 반영)
            final double lowTh = widget.lowTh;
            final double highTh = widget.highTh;
            Color colorForY(double y) {
              if (y < lowTh) return Colors.red; // low
              if (y > highTh) return const Color(0xFFEF6C00); // high: dark orange
              return primary; // in-range
            }
            int stateForY(double y) {
              if (y < lowTh) return -1; // low
              if (y > highTh) return 1; // high
              return 0; // in
            }

            final double lastX = spots.isNotEmpty ? spots.last.x : -1.0;

            final List<LineChartBarData> bars = <LineChartBarData>[];
            List<FlSpot> current = <FlSpot>[];
            int? currentState;
            for (int i = 0; i < spots.length; i++) {
              final double x = spots[i].x;
              final double y = spots[i].y;
              final int st = stateForY(y);
              if (currentState == null) {
                currentState = st;
              }
              if (st != currentState && current.isNotEmpty) {
                final Color segColor = colorForY(current.first.y);
                bars.add(
                  LineChartBarData(
                    isCurved: false,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, idx) {
                        final bool isLast = (s.x == lastX);
                        final bool isSelected = (touchedIndex != null &&
                          widget.points[touchedIndex!.clamp(0, widget.points.length - 1)].time.millisecondsSinceEpoch.toDouble() == s.x);
                    if (isLast || isSelected) {
                          final double base = isSelected ? 4.5 : 4.0;
                          final double radius = isLast ? base * 1.2 : base;
                          return FlDotCirclePainter(
                            radius: radius,
                            color: segColor,
                            strokeWidth: 2,
                            strokeColor: Colors.black,
                          );
                        }
                        return FlDotCirclePainter(
                          radius: (widget.dotRadius ?? Constants.chartDotRadius),
                          color: segColor,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        );
                      },
                    ),
                    spots: List<FlSpot>.from(current),
                    belowBarData: BarAreaData(show: false),
                  ),
                );
                current = <FlSpot>[];
                currentState = st;
              }
              current.add(FlSpot(x, y));
            }
            if (current.isNotEmpty) {
              final Color segColor = colorForY(current.first.y);
              bars.add(
                LineChartBarData(
                  isCurved: false,
                  barWidth: 0,
                  color: Colors.transparent,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, p, b, idx) {
                      final bool isLast = (s.x == lastX);
                      final bool isSelected = (touchedIndex != null &&
                        widget.points[touchedIndex!.clamp(0, widget.points.length - 1)].time.millisecondsSinceEpoch.toDouble() == s.x);
                  if (isLast || isSelected) {
                        final double base = isSelected ? 4.5 : 4.0;
                        final double radius = isLast ? base * 1.2 : base;
                        return FlDotCirclePainter(
                          radius: radius,
                          color: segColor,
                          strokeWidth: 2,
                          strokeColor: Colors.black,
                        );
                      }
                      return FlDotCirclePainter(
                        radius: (widget.dotRadius ?? Constants.chartDotRadius),
                        color: segColor,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                  spots: List<FlSpot>.from(current),
                  belowBarData: BarAreaData(show: false),
                ),
              );
            }
            return bars;
          })(),
          // view port & animation (tooltip indicators omitted for compatibility)
              ),
              );
              }),
            ),
            // custom left Y-axis overlay (labels + unit)
            Positioned(
              left: 0,
              top: 20, // align with chart panel top inset (increased)
              bottom: 0,
              width: 30,
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, cs) {
                    final double h = cs.maxHeight;
                    final List<Widget> marks = <Widget>[];
                    final double interval = 50;
                    if (interval > 0) {
                      // fl_chart bottomTitles reservedSize와 일치시켜 0이 플롯 하단에 정렬되도록 함
                      const double bottomReservedPx = 22.0;
                      final double effH = math.max(1.0, h - bottomReservedPx);
                      for (double v = 0; v <= widget.maxY + 0.001; v += interval) {
                        final double y = effH - (v / widget.maxY) * effH;
                        final double displayVal = v * widget.unitFactor;
                        final String txt = (widget.displayUnit == 'mmol/L')
                            ? displayVal.toStringAsFixed(1)
                            : displayVal.toStringAsFixed(0);
                        marks.add(Positioned(
                          right: 2,
                          top: (y - 6).clamp(0, math.max(0.0, effH - 12)),
                          child: Text(txt, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ));
                      }
                    }
                    return Stack(children: marks);
                  },
                ),
              ),
            ),
        // animation disabled for compatibility
      
            // top date stripe (16px): show day boxes synced to viewport (align leftInset=0)
      // y-axis labels moved to fl_chart leftTitles (50-unit interval)
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 20,
        child: IgnorePointer(
          child: Container(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, cs) {
                    // plot area = full width (no left padding)
                        const double leftInset = 0.0;
                    const double rightInset = 0.0;
                    final double plotWidth = math.max(1.0, cs.maxWidth - leftInset - rightInset);
                    final double ws = windowStart;
                    const double guardPx = 40.0; // 좌우 40px 가드 영역 (라벨 미표시)
                    // include the same right padding (20px) in time domain for stripe
                    final double padMs = windowSize * (kRightPadPx / math.max(1.0, cs.maxWidth));
                    final double we = windowStart + windowSize + padMs;
                    final DateTime startTime = DateTime.fromMillisecondsSinceEpoch(ws.round());
                    final DateTime endTime = DateTime.fromMillisecondsSinceEpoch(we.round());
                    final DateTime centerTime = DateTime.fromMillisecondsSinceEpoch((ws + windowSize / 2).round());
                    final List<_DaySeg> segs = <_DaySeg>[];
                    DateTime segStart = startTime;
                    while (segStart.isBefore(endTime)) {
                      final DateTime nextMidnight = DateTime(segStart.year, segStart.month, segStart.day + 1);
                      final DateTime segEnd = nextMidnight.isBefore(endTime) ? nextMidnight : endTime;
                      segs.add(_DaySeg(segStart, segEnd));
                      segStart = segEnd;
                    }
                    List<Widget> children = <Widget>[];
                      final int startMs = startTime.millisecondsSinceEpoch;
                      final int endMs = endTime.millisecondsSinceEpoch;
                    final double total = math.max(1.0, (endMs - startMs).toDouble());
                    for (final _DaySeg s in segs) {
                      final int segStartMs = s.start.millisecondsSinceEpoch;
                      final int segEndMs = s.end.millisecondsSinceEpoch;
                      final double rxStart = ((segStartMs - startMs) / total).clamp(0.0, 1.0);
                      final double rxEnd = ((segEndMs - startMs) / total).clamp(0.0, 1.0);
                      double left = leftInset + rxStart * plotWidth;
                      double width = (rxEnd - rxStart) * plotWidth;
                      if (width <= 0.5) continue;
                      final bool isCenter = !centerTime.isBefore(s.start) && centerTime.isBefore(s.end);
                      final bool inGuard = (left < guardPx) || (left + width > cs.maxWidth - guardPx);
                      final String label = inGuard ? '' : '${s.start.month}/${s.start.day}';
                      children.add(Positioned(
                        left: left + 4,
                        width: width - 8,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: isCenter ? 14 : 10,
                              fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ));
                    }
                    // 중앙 날짜 라벨: 범위 대신 중앙 날짜만 표시
                    final String centerLabel = '${centerTime.month}/${centerTime.day}';
                    children.add(
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Text(
                              centerLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                    // 좌측에 단위 표시(예: mg/dL, mmol/L)
                    children.add(
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.displayUnit,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                    return Stack(children: children);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
            // removed: internal top-center date (will be rendered by parent just above chart bounds)
            // viewport-average (wide mode only) -> move under first event icon area as white card
            if (widget.isWideMode)
              Positioned(
                top: 56, // back 버튼 하단으로 내리고 +20px 상단 패딩 효과
                left: 20, // add 20px left padding in wide mode
                child: Material(
                  color: Colors.white,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.show_chart, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('chart_avg_prefix'.tr(namedArgs: {'v': _viewportAverage().toStringAsFixed(0)}), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
            // gesture overlay: strictly 2-finger for pan/zoom
            Positioned.fill(
              child: LayoutBuilder(builder: (context, c) {
                final double width = c.maxWidth;
                return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  _lastInteractionAt = DateTime.now();
                  _pointerPositions[e.pointer] = e.position;
                  _activePointers = _pointerPositions.length;
                  if (_activePointers == 2) {
                    // start two-finger gesture
                    final List<Offset> pts = _pointerPositions.values.toList();
                    _twoStartFocal = (pts[0] + pts[1]) / 2;
                    _twoPrevFocal = _twoStartFocal;
                    _twoStartSpan = (pts[0] - pts[1]).distance;
                    startWindowStart = windowStart;
                    startWindowSize = windowSize;
                    _twoFingerActive = true;
                  }
                  setState(() {});
                },
                  onPointerMove: (e) {
                  _lastInteractionAt = DateTime.now();
                  _pointerPositions[e.pointer] = e.position;
                  if (_pointerPositions.length >= 2 && _twoFingerActive) {
                    final List<Offset> pts = _pointerPositions.values.take(2).toList();
                    final Offset focal = (pts[0] + pts[1]) / 2;
                    final double span = (pts[0] - pts[1]).distance;
                    // incremental pan based on focal delta to avoid jump on gesture start
                    if (_twoPrevFocal != null) {
                      final double dx = focal.dx - _twoPrevFocal!.dx;
                      if (dx.abs() > 0) {
                        final double deltaMs = (dx / math.max(1.0, width)) * windowSize;
                        windowStart -= deltaMs;
                        _clampWindow();
                      }
                    }
                    _twoPrevFocal = focal;
                    // zoom based on span ratio -> snap to 3h/6h/12h/24h, anchored to focal
                    if (_twoStartSpan > 0) {
                      final double scale = span / _twoStartSpan;
                      final double proposed = startWindowSize / scale;
                      final List<double> steps = <double>[3, 6, 12, 24].map((h) => h * 3600000.0).toList();
                      double best = steps.first;
                      double bestDelta = (proposed - best).abs();
                      for (final double s in steps) {
                        final double d = (proposed - s).abs();
                        if (d < bestDelta) { best = s; bestDelta = d; }
                      }
                      // compute focal ratio within current window
                      final double panelW = (_panelWidth <= 0) ? 1.0 : _panelWidth;
                      final double r = (focal.dx / panelW).clamp(0.0, 1.0);
                      final double tFocus = windowStart + r * windowSize;
                      windowSize = best;
                      windowStart = tFocus - r * windowSize;
                      _clampWindow();
                    }
                    setState(() {});
                  }
                },
                onPointerUp: (e) {
                  _lastInteractionAt = DateTime.now();
                  _pointerPositions.remove(e.pointer);
                  _activePointers = _pointerPositions.length;
                  if (_activePointers < 2) {
                    _twoFingerActive = false;
                    _twoStartFocal = null;
                    _twoPrevFocal = null;
                    _twoStartSpan = 1.0;
                  }
                  setState(() {});
                },
                onPointerCancel: (e) {
                  _lastInteractionAt = DateTime.now();
                  _pointerPositions.remove(e.pointer);
                  _activePointers = _pointerPositions.length;
                  _twoFingerActive = false;
                  _twoStartFocal = null;
                  _twoPrevFocal = null;
                  _twoStartSpan = 1.0;
                  setState(() {});
                },
                child: const SizedBox.expand(),
              );
            }),
            ),
            // crosshair line at touched index (left inset = 0; Y축은 오버레이로 그림)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  _panelWidth = c.maxWidth;
                  if (touchedIndex == null || widget.points.isEmpty) return const SizedBox.shrink();
                  final double width = c.maxWidth;
                  // no left padding in the draw panel
                  const double leftInset = 0.0;
                  const double rightInset = 0.0;
                  final double plotWidth = math.max(1.0, width - leftInset - rightInset);
                  final double xMs = widget.points[touchedIndex!.clamp(0, widget.points.length - 1)].time.millisecondsSinceEpoch.toDouble();
                  // include right pad in ratio mapping
                  final double padMs = windowSize * (kRightPadPx / math.max(1.0, width));
                  final double effWindow = windowSize + padMs;
                  final double xRatio = (xMs - windowStart) / math.max(1e-6, effWindow);
                  final double x = (leftInset + xRatio * plotWidth).clamp(leftInset, leftInset + plotWidth);
                  // range-based crosshair color: low=red, in-range=green, high=orange (slightly lighter)
                  final double v = widget.points[touchedIndex!.clamp(0, widget.points.length - 1)].value;
                  final Color crossColor = (v < widget.lowTh)
                      ? Colors.red.withValues(alpha: 0.5)
                      : (v > widget.highTh ? const Color(0xFFEF6C00).withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5));
                  return Stack(children: [
                    Positioned(
                      left: (x - 0.5).clamp(leftInset, leftInset + plotWidth - 1),
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: crossColor),
                    ),
                    // removed fixed end date labels on x-axis
                    // top badge: glucose value with direction arrow
                    Positioned(
                      left: ((x - (_badgeWidth / 2))).clamp(leftInset, math.max(leftInset, leftInset + plotWidth - _badgeWidth)),
                      top: 0, // 16px date stripe + 20px padding
                      child: Builder(builder: (context) {
                        final int i = touchedIndex!.clamp(0, widget.points.length - 1);
                        final double v = widget.points[i].value;
                        final double? prev = i > 0 ? widget.points[i - 1].value : null;
                        final double? next = (i + 1 < widget.points.length) ? widget.points[i + 1].value : null;
                        double delta = 0;
                        if (prev != null) {
                          delta = v - prev;
                        } else if (next != null) {
                          delta = v - next;
                        }
                        final IconData arrow = delta > 0.5
                            ? Icons.arrow_upward
                            : (delta < -0.5 ? Icons.arrow_downward : Icons.horizontal_rule);
                        final Color badgeBg = v < widget.lowTh
                            ? Colors.red
                            : (v > widget.highTh ? Colors.orange : Theme.of(context).colorScheme.primary);
                        // measure width after build to keep the badge centered on the crosshair
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final RenderBox? rb = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
                          if (rb != null) {
                            final double w = rb.size.width;
                            if ((w - _badgeWidth).abs() > 0.5 && mounted) {
                              setState(() => _badgeWidth = w);
                            }
                          }
                        });
                        return Material(
                          key: _badgeKey,
                          color: Colors.white,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(arrow, size: 14, color: Colors.black54),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    v.toStringAsFixed(0),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Builder(builder: (context) {
                                  final DateTime tt = widget.points[i].time;
                                  final String mm = tt.minute.toString().padLeft(2, '0');
                                  final String timeStr = widget.use24h
                                      ? '${tt.hour.toString().padLeft(2, '0')}:$mm'
                                      : '${(tt.hour % 12 == 0 ? 12 : tt.hour % 12)}:$mm ${tt.hour < 12 ? 'AM' : 'PM'}';
                                  return Text(timeStr, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600));
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    // removed: time label under the badge (hh:mm)
                  ]);
                },
              ),
            ),
            // interaction overlay: tap/double-tap/long-press + event taps
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                onTapDown: (d) {
                  _lastInteractionAt = DateTime.now();
                  _touchCircleTimer?.cancel();
                  setState(() { _touchCircle = d.localPosition; });
                  _touchCircleTimer = Timer(const Duration(milliseconds: 200), () {
                    if (!mounted) return;
                    setState(() { _touchCircle = null; });
                  });
                },
                onPanStart: (d) {
                  _lastInteractionAt = DateTime.now();
                  _oneFingerLastDx = d.localPosition.dx;
                },
                    onPanUpdate: (d) {
                  _lastInteractionAt = DateTime.now();
                  // 기존 감도로 복원: 선택모드가 아니면 드래그, 선택모드면 선택만 갱신
                  if (touchedIndex == null) {
                    final double dx = d.localPosition.dx - (_oneFingerLastDx ?? d.localPosition.dx);
                    _oneFingerLastDx = d.localPosition.dx;
                    final double width = c.maxWidth;
                    final double deltaMs = (dx / math.max(1.0, width)) * windowSize;
                    windowStart = windowStart - deltaMs;
                    _clampWindow();
                    setState(() {});
                  } else {
                    // 선택 모드: 드래그 X 위치에 가장 가까운 데이터로 스크럽
                    final int idx = _nearestIndexForDx(d.localPosition.dx, c.maxWidth);
                    setState(() => touchedIndex = idx);
                    widget.onSelectIndex(idx);
                  }
                    },
                    onPanEnd: (_) {
                      _oneFingerLastDx = null;
                  // allow AnimatedOpacity to finish; touch point cleared on animation end
                    },
                    onTapUp: (d) {
                      _lastInteractionAt = DateTime.now();
                      final Size sz = Size(c.maxWidth, c.maxHeight);
                      final Offset p = d.localPosition;
              _touchCircleTimer?.cancel();
              setState(() { _touchCircle = p; });
              _touchCircleTimer = Timer(const Duration(milliseconds: 200), () {
                if (!mounted) return;
                setState(() { _touchCircle = null; });
              });
                  // 원 안에 점이 없으면 선택 해제 (고정 반경 사용)
                  final int idx = _indexWithinCircle(p, sz.width, sz.height, 12.0);
                  if (idx == -1) {
                    setState(() => touchedIndex = null);
                  } else {
                    final int clamped = idx.clamp(0, widget.points.length - 1);
                    setState(() => touchedIndex = clamped);
                    widget.onSelectIndex(clamped);
                  }
                    },
                  );
                },
              ),
            ),
        // touch circle overlay (30px) for hit validation
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _touchCircle == null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: (_touchCircle == null)
                  ? const SizedBox.shrink()
                  : CustomMultiChildLayout(
                      delegate: _SingleChildAtOffsetDelegate(_touchCircle!),
                      children: [
                        LayoutId(
                          id: 'circle',
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black.withOpacity(0.3), width: 2),
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        )
                      ],
                    ),
            ),
          ),
        ),
            // bottom popup removed; top label shown near crosshair instead
            // removed fixed top-right round box (now list scroll sync only)
            // event markers: icon with gray round badge background
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  final double width = c.maxWidth;
                  if (widget.events.isEmpty) return const SizedBox.shrink();
                  final List<Widget> children = <Widget>[];
                  // reorder events: 혈당(bloodGlucose) 운동(exercise) 인슐린(insulin) 메모(memo) 식사(meal) 약물(medication)
                  final List<GlucoseEvent> ordered = List<GlucoseEvent>.from(widget.events);
                  int weight(EventType t) {
                    switch (t) {
                      case EventType.bloodGlucose:
                        return 0;
                      case EventType.exercise:
                        return 1;
                      case EventType.insulin:
                        return 2;
                      case EventType.memo:
                        return 3;
                      case EventType.meal:
                        return 4;
                      case EventType.medication:
                        return 5;
                    }
                  }
                  ordered.sort((a, b) => weight(a.type).compareTo(weight(b.type)));
                  // viewport transform with no left inset
                  const double leftInset = 0.0;
                  const double rightInset = 0.0;
                  final double plotWidth = math.max(1.0, width - leftInset - rightInset);
                  final double ws = windowStart;
                  final double padMs = windowSize * (kRightPadPx / math.max(1.0, width));
                  final double we = windowStart + windowSize + padMs;
                  for (int i = 0; i < ordered.length; i++) {
                    final double tMs = ordered[i].time.millisecondsSinceEpoch.toDouble();
                    if (tMs < ws || tMs > we) {
                      // hide events outside current x-axis viewport
                      continue;
                    }
                    final double xRatio = (tMs - ws) / math.max(1e-6, (windowSize + padMs));
                  final double x = leftInset + xRatio * plotWidth;
                    final bool isSelected = (ordered[i].id == _selectedEventId);
                    children.add(Positioned(
                      // align icons on a bottom row inside plot, not on Y-axis
                      top: 30,
                      left: (x - 16).clamp(leftInset, leftInset + plotWidth - 32),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // highlight selected badge
                          setState(() { _selectedEventId = ordered[i].id; });
                          // center viewport on this event time
                          final double desiredStart = tMs - (windowSize / 2);
                          windowStart = desiredStart;
                          _clampWindow();
                          // enable data selection mode at nearest data point to this event time
                          final int idxAtEvent = _indexForTime(DateTime.fromMillisecondsSinceEpoch(tMs.round()));
                          touchedIndex = idxAtEvent;
                          setState(() {});
                          // propagate selection to parent if needed
                          widget.onSelectIndex(idxAtEvent);
                          widget.onEventTap(ordered[i].id);
                        },
                        child: Container(
                          padding: EdgeInsets.zero,
                          decoration: isSelected
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black87, width: 1),
                                )
                              : null,
                          child: _EventBadge(type: ordered[i].type, size: 32),
                        ),
                      ),
                    ));
                  }
                  return Stack(children: children);
                },
              ),
            ),
            // back button (wide mode) placed on top of overlays
            
          ],
        ),),],  
      ),
    ); 
  }

  double _viewportAverage() {
    if (widget.points.isEmpty) return 0;
    final int startIdx = windowStart.ceil().clamp(0, widget.points.length - 1);
    final int endIdx = (windowStart + windowSize).floor().clamp(0, widget.points.length - 1);
    if (endIdx < startIdx) return widget.points.last.value;
    double sum = 0;
    int count = 0;
    for (int i = startIdx; i <= endIdx; i++) {
      sum += widget.points[i].value;
      count++;
    }
    if (count == 0) return 0;
    return sum / count;
  }

  // x-label interval removed (bottom titles hidden)

  int _nearestIndexForDx(double dx, double width) {
    if (widget.points.isEmpty) return 0;
    // match plot insets used in crosshair calculation (left titles reserved space)
    const double leftInset = 0.0;
    const double rightInset = 0.0;
    final double plotWidth = math.max(1.0, width - leftInset - rightInset);
    final double clamped = dx.clamp(leftInset, leftInset + plotWidth) - leftInset;
    final double ratio = (clamped / plotWidth).clamp(0.0, 1.0);
    final double tMs = windowStart + ratio * math.max(1e-6, windowSize);
    // 시간 기반으로 가장 가까운 인덱스를 찾음
    int best = 0; int bestDelta = 1 << 30;
    for (int i = 0; i < widget.points.length; i++) {
      final int ms = widget.points[i].time.millisecondsSinceEpoch;
      final int d = (ms - tMs).abs().round();
      if (d < bestDelta) { bestDelta = d; best = i; }
    }
    return best;
  }

  int _nearestIndexForPoint(Offset p, double width, double height) {
    if (widget.points.isEmpty) return 0;
    const double leftInset = 0.0;
    const double rightInset = 0.0;
    final double plotWidth = math.max(1.0, width - leftInset - rightInset);
    const double panelTopInset = 20.0; // chart panel Positioned top (increased)
    const double bottomReservedPx = 22.0; // must match bottomTitles reservedSize
    final double effPlotH = (height - panelTopInset - bottomReservedPx).clamp(1.0, double.infinity);
    int best = 0;
    double bestDist2 = double.infinity;
    for (int i = 0; i < widget.points.length; i++) {
      final double tMs = widget.points[i].time.millisecondsSinceEpoch.toDouble();
      final double xRatio = (tMs - windowStart) / math.max(1e-6, windowSize);
      final double sx = (leftInset + xRatio * plotWidth).clamp(leftInset, leftInset + plotWidth);
      final double vScaled = widget.points[i].value;
      final double syPlot = effPlotH - (vScaled / widget.maxY * effPlotH);
      final double sy = panelTopInset + syPlot;
      final double dx = p.dx - sx;
      final double dy = p.dy - sy;
      final double d2 = dx * dx + dy * dy;
      if (d2 < bestDist2) {
        bestDist2 = d2;
        best = i;
      }
    }
    return best;
  }

  int _indexWithinCircle(Offset p, double width, double height, double radius) {
    if (widget.points.isEmpty) return -1;
    const double leftInset = 0.0;
    const double rightInset = 0.0;
    final double plotWidth = math.max(1.0, width - leftInset - rightInset);
    const double panelTopInset = 20.0;
    const double bottomReservedPx = 22.0;
    final double effPlotH = (height - panelTopInset - bottomReservedPx).clamp(1.0, double.infinity);
    // use actual drawn circle center after clamping to bounds
    final double cx = p.dx.clamp(radius, math.max(radius, width - radius));
    final double cy = p.dy.clamp(radius, math.max(radius, height - radius));
    int best = -1;
    double bestDist2 = radius * radius;
    for (int i = 0; i < widget.points.length; i++) {
      final double tMs = widget.points[i].time.millisecondsSinceEpoch.toDouble();
      final double xRatio = (tMs - windowStart) / math.max(1e-6, windowSize);
      final double sx = (leftInset + xRatio * plotWidth).clamp(leftInset, leftInset + plotWidth);
      final double vScaled = widget.points[i].value;
      final double syPlot = effPlotH - (vScaled / widget.maxY * effPlotH);
      final double sy = panelTopInset + syPlot;
      final double dx = cx - sx;
      final double dy = cy - sy;
      final double d2 = dx * dx + dy * dy;
      if (d2 <= bestDist2) {
        bestDist2 = d2;
        best = i;
      }
    }
    return best;
  }

  // haptic helper removed (unused)

  // 뷰포트 인덱스(실수) -> 시간 보간 (X축 기반 날짜 스트립에 사용)
  DateTime _timeForIndex(double idx) {
    if (widget.points.isEmpty) return DateTime.now();
    final int n = widget.points.length;
    if (idx <= 0) return widget.points.first.time;
    if (idx >= n - 1) return widget.points.last.time;
    final int i0 = idx.floor();
    final int i1 = idx.ceil();
    final DateTime t0 = widget.points[i0].time;
    final DateTime t1 = widget.points[i1].time;
    final int m0 = t0.millisecondsSinceEpoch;
    final int m1 = t1.millisecondsSinceEpoch;
    final double r = idx - i0;
    final int mi = (m0 + (m1 - m0) * r).round();
    return DateTime.fromMillisecondsSinceEpoch(mi);
  }

  int _indexForTime(DateTime t) {
    int best = 0;
    int bestDelta = 1 << 30;
    for (int i = 0; i < widget.points.length; i++) {
      final int delta = (widget.points[i].time.millisecondsSinceEpoch - t.millisecondsSinceEpoch).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  // nearest-event hit test removed (unused)

}

class _DaySeg {
  _DaySeg(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class _SingleChildAtOffsetDelegate extends MultiChildLayoutDelegate {
  _SingleChildAtOffsetDelegate(this.offset);
  final Offset offset;

  @override
  void performLayout(Size size) {
    if (hasChild('circle')) {
      final BoxConstraints tight = const BoxConstraints.tightFor(width: 24, height: 24);
      layoutChild('circle', tight);
      positionChild('circle', Offset(offset.dx - 12, offset.dy - 12));
    }
  }

  @override
  bool shouldRelayout(covariant _SingleChildAtOffsetDelegate oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
