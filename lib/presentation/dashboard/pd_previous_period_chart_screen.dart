import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/dashboard/pd_previous_routes.dart';

/// 센서(eqsn)별 기간의 로컬 혈당을 **일자별 24h(00:00~24:00)** 겹침 그래프로 표시 (PD_01_01).
class PdPreviousPeriodChartScreen extends StatefulWidget {
  const PdPreviousPeriodChartScreen({
    super.key,
    required this.eqsn,
    required this.fromMs,
    required this.toMs,
  });

  final String eqsn;
  final int fromMs;
  final int toMs;

  @override
  State<PdPreviousPeriodChartScreen> createState() => _PdPreviousPeriodChartScreenState();
}

class _PdPreviousPeriodChartScreenState extends State<PdPreviousPeriodChartScreen> {
  bool _loading = true;

  /// 착용 시작일~종료일까지의 각 날(로컬 자정 기준), 오름차순.
  List<DateTime> _wearDays = const [];

  /// `_wearDays[index]` 에 해당하는 FlSpot 목록 (x: 시간(0~24), y: 표시 단위 혈당).
  List<List<FlSpot>> _spotsByDayIndex = const [];

  String _unit = 'mg/dL';
  double _unitFactor = 1.0;
  static const double _mmolFactor = 18.02;

  /// 선택된 날 인덱스 (`_wearDays` 기준).
  final Set<int> _selectedDayIndices = <int>{};

  static const List<Color> _kDayColors15 = <Color>[
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFB8C00),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFFDD835),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF00897B),
    Color(0xFFF4511E),
    Color(0xFF7CB342),
    Color(0xFF5E35B1),
    Color(0xFF039BE5),
  ];

  Color _lineColorForDayIndex(int dayIndex) => _kDayColors15[dayIndex % _kDayColors15.length];

  static DateTime _dateOnlyLocal(DateTime t) => DateTime(t.year, t.month, t.day);

  static int _daysBetweenInclusive(DateTime a, DateTime b) {
    final DateTime da = _dateOnlyLocal(a);
    final DateTime db = _dateOnlyLocal(b);
    return db.difference(da).inDays + 1;
  }

  static Iterable<DateTime> _eachCalendarDay(DateTime from, DateTime to) sync* {
    DateTime d = _dateOnlyLocal(from);
    final DateTime last = _dateOnlyLocal(to);
    while (!d.isAfter(last)) {
      yield d;
      d = d.add(const Duration(days: 1));
    }
  }

  double get _chartMinY => 0;
  double get _chartMaxY => _unit == 'mmol/L' ? 25.0 : 450.0;

  double get _gridYInterval => _unit == 'mmol/L' ? 5.0 : 90.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl').trim();
      _unit = (u == 'mmol') ? 'mmol/L' : 'mg/dL';
      _unitFactor = (_unit == 'mmol/L') ? (1.0 / _mmolFactor) : 1.0;

      final DateTime rangeFrom = DateTime.fromMillisecondsSinceEpoch(widget.fromMs, isUtc: true).toLocal();
      final DateTime rangeTo = DateTime.fromMillisecondsSinceEpoch(widget.toMs, isUtc: true).toLocal();

      final List<DateTime> wearDays = _eachCalendarDay(rangeFrom, rangeTo).toList();
      final Map<DateTime, List<FlSpot>> bucket = <DateTime, List<FlSpot>>{
        for (final DateTime d in wearDays) d: <FlSpot>[],
      };

      final rows = await GlucoseLocalRepo().range(
        from: rangeFrom,
        to: rangeTo,
        limit: 10000,
        eqsn: widget.eqsn,
      );

      for (int i = 0; i < rows.length; i++) {
        final int tms = (rows[i]['time_ms'] as int?) ?? 0;
        final DateTime tLocal = DateTime.fromMillisecondsSinceEpoch(tms, isUtc: true).toLocal();
        final DateTime day = _dateOnlyLocal(tLocal);
        if (!bucket.containsKey(day)) continue;
        final DateTime nextMidnight = day.add(const Duration(days: 1));
        if (!tLocal.isBefore(nextMidnight)) continue;

        final double raw = ((rows[i]['value'] as num?) ?? 0).toDouble();
        final double y = (raw * _unitFactor).clamp(_chartMinY, _chartMaxY);
        final double hours = tLocal.difference(day).inMicroseconds / 3600000000.0;
        final double x = hours.clamp(0.0, 24.0);
        bucket[day]!.add(FlSpot(x, y));
      }

      for (final List<FlSpot> list in bucket.values) {
        list.sort((a, b) => a.x.compareTo(b.x));
      }

      final List<List<FlSpot>> byIndex = <List<FlSpot>>[];
      for (final DateTime d in wearDays) {
        byIndex.add(bucket[d] ?? const <FlSpot>[]);
      }

      _wearDays = wearDays;
      _spotsByDayIndex = byIndex;
      _selectedDayIndices
        ..clear()
        ..addAll(List<int>.generate(_wearDays.length, (i) => i));
    } catch (_) {
      _wearDays = const [];
      _spotsByDayIndex = const [];
      _selectedDayIndices.clear();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _fmtRange() {
    if (widget.fromMs <= 0 || widget.toMs <= 0) return '—';
    String d(DateTime t) => '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
    final a = DateTime.fromMillisecondsSinceEpoch(widget.fromMs, isUtc: true).toLocal();
    final b = DateTime.fromMillisecondsSinceEpoch(widget.toMs, isUtc: true).toLocal();
    return '${d(a)} ~ ${d(b)}';
  }

  String _fmtChipDay(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTooltipDay(DateTime d) => '${d.month}/${d.day}';

  String _fmtVal(double v) => _unit == 'mmol/L' ? v.toStringAsFixed(1) : v.toStringAsFixed(0);

  bool get _allSelected =>
      _wearDays.isNotEmpty && _selectedDayIndices.length == _wearDays.length;

  void _setSelectAll(bool? v) {
    setState(() {
      if (v == true) {
        _selectedDayIndices
          ..clear()
          ..addAll(List<int>.generate(_wearDays.length, (i) => i));
      } else {
        _selectedDayIndices.clear();
      }
    });
  }

  void _toggleDay(int index) {
    setState(() {
      if (_selectedDayIndices.contains(index)) {
        _selectedDayIndices.remove(index);
      } else {
        _selectedDayIndices.add(index);
      }
    });
  }

  void _closeToMainChart() {
    Navigator.of(context).popUntil(
      (route) {
        final Object? n = route.settings.name;
        return n != PdPreviousRoutes.chart && n != PdPreviousRoutes.stack;
      },
    );
  }

  Color _onChipColor(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.light ? Colors.black87 : Colors.white;

  List<LineChartBarData> _visibleLineBars() {
    final List<int> order = _selectedDayIndices.toList()..sort();
    final List<LineChartBarData> bars = <LineChartBarData>[];
    for (final int idx in order) {
      if (idx < 0 || idx >= _spotsByDayIndex.length) continue;
      final List<FlSpot> spots = _spotsByDayIndex[idx];
      if (spots.isEmpty) continue;
      final Color c = _lineColorForDayIndex(idx);
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: c,
          barWidth: 1.2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    return bars;
  }

  /// `lineBarsData` 순서와 동일: 선택된 날 인덱스.
  List<int> _visibleWearIndices() {
    final List<int> order = _selectedDayIndices.toList()..sort();
    return order.where((int idx) {
      if (idx < 0 || idx >= _spotsByDayIndex.length) return false;
      return _spotsByDayIndex[idx].isNotEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _closeToMainChart,
          tooltip: 'Close',
        ),
        title: Text(
          _fmtRange(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sensor SN: ${widget.eqsn}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unit: $_unit',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_wearDays.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No day range for this sensor.\n'
                      'Use Refresh / download on the main screen, then try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.35),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  flex: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Glucose Trending',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _unit,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final List<LineChartBarData> bars = _visibleLineBars();
                            final List<int> barWearIdx = _visibleWearIndices();
                            if (bars.isEmpty) {
                              return Center(
                                child: Text(
                                  _selectedDayIndices.isEmpty
                                      ? 'Select one or more dates below.'
                                      : 'No data for the selected day(s).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                                ),
                              );
                            }
                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: 24,
                                  minY: _chartMinY,
                                  maxY: _chartMaxY,
                                  clipData: const FlClipData.all(),
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: true,
                                    horizontalInterval: _gridYInterval,
                                    verticalInterval: 4,
                                    getDrawingHorizontalLine: (v) => FlLine(
                                      color: const Color(0xFFE0E0E0),
                                      strokeWidth: 1,
                                      dashArray: const [4, 4],
                                    ),
                                    getDrawingVerticalLine: (v) => FlLine(
                                      color: const Color(0xFFE0E0E0),
                                      strokeWidth: 1,
                                      dashArray: const [4, 4],
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        interval: _gridYInterval,
                                        getTitlesWidget: (v, m) {
                                          if (v > _chartMaxY + 0.01) return const SizedBox.shrink();
                                          return Text(
                                            _fmtVal(v),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 26,
                                        interval: 4,
                                        getTitlesWidget: (v, m) {
                                          String label;
                                          if (v >= 23.99) {
                                            label = '24:00';
                                          } else {
                                            final int h = v.floor().clamp(0, 23);
                                            label = '${h.toString().padLeft(2, '0')}:00';
                                          }
                                          return SideTitleWidget(
                                            meta: m,
                                            space: 4,
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.white60 : Colors.black54,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    handleBuiltInTouches: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (_) =>
                                          isDark ? const Color(0xFF2D2D2D) : Colors.white,
                                      tooltipBorder: BorderSide(
                                        color: isDark ? Colors.white24 : const Color(0xFFE0E0E0),
                                      ),
                                      getTooltipItems: (List<LineBarSpot> touched) {
                                        return touched.map((LineBarSpot s) {
                                          final int bi = s.barIndex;
                                          final int wearIdx =
                                              (bi >= 0 && bi < barWearIdx.length) ? barWearIdx[bi] : 0;
                                          final DateTime day = _wearDays[wearIdx];
                                          final Color lineC = _lineColorForDayIndex(wearIdx);
                                          return LineTooltipItem(
                                            '${_fmtTooltipDay(day)}  ${_hourLabel(s.x)}  ${_fmtVal(s.y)} $_unit',
                                            TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: lineC,
                                              height: 1.2,
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                  lineBarsData: bars,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select two or more dates to compare.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            height: 32,
                            child: Checkbox(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              value: _allSelected,
                              tristate: false,
                              onChanged: (bool? v) => _setSelectAll(v),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _setSelectAll(!_allSelected),
                            child: Text(
                              'Select All',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_daysBetweenInclusive(_wearDays.first, _wearDays.last)} days',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: _wearDays.length > 12,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 8),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              alignment: WrapAlignment.start,
                              children: List<Widget>.generate(_wearDays.length, (int i) {
                                final DateTime d = _wearDays[i];
                                final Color lineC = _lineColorForDayIndex(i);
                                final bool sel = _selectedDayIndices.contains(i);
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _toggleDay(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sel ? lineC : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: lineC,
                                          width: sel ? 0 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        _fmtChipDay(d),
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.0,
                                          letterSpacing: -0.2,
                                          fontWeight: FontWeight.w600,
                                          color: sel ? _onChipColor(lineC) : lineC,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _hourLabel(double xHours) {
    final double xf = xHours.clamp(0.0, 24.0);
    final int totalMin = (xf * 60).round();
    final int h = totalMin ~/ 60;
    final int m = totalMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
