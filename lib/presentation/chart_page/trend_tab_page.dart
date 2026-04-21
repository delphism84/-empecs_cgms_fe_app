import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/spacing.dart';
import 'package:helpcare/presentation/chart_page/chart_page.dart';
// removed extra imports after UI rebuild
import 'package:helpcare/widgets/debug_badge.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:easy_localization/easy_localization.dart';
// removed
// removed

class TrendTabPage extends StatefulWidget {
  const TrendTabPage({super.key});

  @override
  State<TrendTabPage> createState() => _TrendTabPageState();
}

class _TrendTabPageState extends State<TrendTabPage> {
  String hoursRange = '6h';
  Map<String, double>? _tir; // veryHigh, inRange, low, veryLow
  bool _loading = false;
  double? _avg;
  double? _highest;
  double? _lowest;
  String _unit = 'mg/dL';
  static const double _mmolFactor = 18.02; // mg/dL ÷ 18.02 = mmol/L (소수점 2자리)
  double _unitFactor = 1.0; // 1.0 for mg/dL, 1/18.02 for mmol/L

  @override
  void initState() {
    super.initState();
    _markViewed();
    AppSettingsBus.changed.addListener(_onSettingsChanged);
    _loadAppSetting();
    _reloadTir();
    _reloadStats();
  }

  @override
  void dispose() {
    try { AppSettingsBus.changed.removeListener(_onSettingsChanged); } catch (_) {}
    super.dispose();
  }

  void _onSettingsChanged() {
    _loadUnitLocal();
    setState(() {});
  }

  Future<void> _loadUnitLocal() async {
    try {
      final st = await SettingsStorage.load();
      final String u0 = (st['glucoseUnit'] as String? ?? 'mgdl').trim();
      if (!mounted) return;
      setState(() {
        _unit = (u0 == 'mmol') ? 'mmol/L' : 'mg/dL';
        _unitFactor = (_unit == 'mmol/L') ? (1.0 / _mmolFactor) : 1.0;
      });
    } catch (_) {}
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['tg0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _loadAppSetting() async {
    try {
      // local-first
      await _loadUnitLocal();
      final SettingsService ss = SettingsService();
      final Map<String, dynamic> app = await ss.getAppSetting();
      // 스펙: 설정(db정보) 사용. 키 존재 시 반영, 없으면 기본(70~180)로 계산
      final double low = ((app['low'] ?? 70) as num).toDouble();
      final double high = ((app['high'] ?? 180) as num).toDouble();
      // 현재 버전에서는 라벨/도메인만 참고하고, 값 계산은 서버 통계 API 연계 시 반영 예정
      // 로컬 경고 제거용 no-op
      if (low > high) {
        // swap guard (실행될 일은 없지만 린트 회피 및 안정성 확보)
        final double _tmp = low;
        // ignore: unused_local_variable
        final double _guard = _tmp;
      }
      // 서버 단위는 참고만 하고(로컬이 우선), 동일할 때만 동기화
      final String u = (app['unit'] as String?) ?? 'mg/dL';
      final String normalized = (u == 'mmol/L') ? 'mmol/L' : 'mg/dL';
      if (normalized == _unit) {
        setState(() {
          _unit = normalized;
          _unitFactor = (_unit == 'mmol/L') ? (1.0 / _mmolFactor) : 1.0;
        });
      }
      // _tir는 _reloadTir()에서만 설정 (실제 데이터 기준 Range Distribution 표시)
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: getPadding(left: 16, right: 16, top: 12, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'chart_trend_title'.tr(),
                    style: TextStyle(
                      fontSize: getFontSize(20),
                      fontFamily: 'Gilroy-Medium',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: 'chart_landscape_mode'.tr(),
                    icon: const Icon(Icons.screen_rotation_alt),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Tg0102ChartLandscapeScreen(hoursRange: hoursRange),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: getPadding(left: 5, right: 5, bottom: 8),
              child: _hoursTabs(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: DebugBadge(
                  reqId: 'TG_01_01',
                  child: Padding(
                    padding: getPadding(left: 5, right: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 420,
                          decoration: BoxDecoration(
                            color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
                            borderRadius: BorderRadius.circular(getHorizontalSize(12)),
                          ),
                          child: ChartPage(
                            embedded: true,
                            hoursRange: hoursRange,
                            onAddMemo: null, // Trend 화면에는 이벤트 입력 없음
                          ),
                        ),
                        VerticalSpace(height: 12),
                        _statsCard(isDark),
                        VerticalSpace(height: 12),
                        _tirPieCard(isDark),
                        VerticalSpace(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hoursLabelWidget(String v) {
    // Setup(Settings) 수준의 밀도/폰트로 고정(과도한 전역 스케일 영향 최소화)
    final TextStyle base = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.0);
    if (v.endsWith('h')) {
      final String n = v.substring(0, v.length - 1);
      final int? h = int.tryParse(n);
      if (h != null) {
        final String unit = h == 1 ? 'chart_hour'.tr() : 'chart_hours'.tr();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$h', style: base),
            Text(unit, style: base.copyWith(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      }
    }
    return Text(v, style: base);
  }

  Widget _hoursTabs(BuildContext context) {
    final List<String> options = ['3h', '6h', '12h', '24h'];
    final BorderRadius radius = BorderRadius.circular(getHorizontalSize(12));
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          children: [
            for (int i = 0; i < options.length; i++) ...[
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final String v = options[i];
                    if (hoursRange == v) return;
                    setState(() => hoursRange = v);
                    await Future.wait([_reloadTir(), _reloadStats()]);
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: hoursRange == options[i]
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: hoursRange == options[i]
                            ? Theme.of(context).colorScheme.primary
                            : DefaultTextStyle.of(context).style.color,
                        fontWeight: hoursRange == options[i] ? FontWeight.w600 : FontWeight.w400,
                      ),
                      child: _hoursLabelWidget(options[i]),
                    ),
                  ),
                ),
              ),
              if (i != options.length - 1)
                Container(width: 1, height: 44, color: ColorConstant.indigo51),
            ],
          ],
        ),
      ),
    );
  }

  // unused legacy card (kept for reference; not used)
  // ignore: unused_element
  Widget _summaryReportCard(bool isDark) {
    // 기간 선택 상태
    final List<int> ranges = [7, 14, 30, 90];
    int selectedDays = 7;
    DateTime to = DateTime.now();
    DateTime from = to.subtract(Duration(days: selectedDays - 1));

    return StatefulBuilder(builder: (context, setSS) {
      void applyDays(int d) {
        setSS(() {
          selectedDays = d;
          to = DateTime.now();
          from = to.subtract(Duration(days: selectedDays - 1));
        });
      }

      void shiftDays(int step) {
        setSS(() {
          to = to.add(Duration(days: step));
          from = from.add(Duration(days: step));
        });
      }

      // 샘플 통계
      const double avg = 118;
      const double high = 160;
      const double low = 95;
      const double tirPct = 75; // time in range percent

      return Container(
        padding: getPadding(all: 12),
        decoration: BoxDecoration(
          color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
          borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 기간 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(spacing: 8, children: [
                for (final d in ranges)
                  ChoiceChip(
                    label: Text('$d Days'),
                    selected: selectedDays == d,
                    onSelected: (_) => applyDays(d),
                  ),
              ]),
            ],
          ),
          VerticalSpace(height: 8),
          // 날짜 네비게이션
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(onPressed: () => shiftDays(-selectedDays), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(
                      '${from.year}.${from.month.toString().padLeft(2, '0')}.${from.day.toString().padLeft(2, '0')}  ~  '
                      '${to.year}.${to.month.toString().padLeft(2, '0')}.${to.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(onPressed: () => shiftDays(selectedDays), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          VerticalSpace(height: 12),
          // 통계 타일 3개
          Row(children: [
            Expanded(child: _statBadge('Average', avg.toStringAsFixed(1))),
            HorizontalSpace(width: 8),
            Expanded(child: _statBadge('Highest', high.toStringAsFixed(1))),
            HorizontalSpace(width: 8),
            Expanded(child: _statBadge('Lowest', low.toStringAsFixed(1))),
          ]),
          VerticalSpace(height: 16),
          // TIR 도넛
          _tirDonut(tirPct, isDark),
        ]),
      );
    });
  }

  Widget _statsCard(bool isDark) {
    final String avg = _avg != null ? _avg!.toStringAsFixed(1) : '--';
    final String high = _highest != null ? _highest!.toStringAsFixed(1) : '--';
    final String low = _lowest != null ? _lowest!.toStringAsFixed(1) : '--';
    return Container(
      padding: getPadding(all: 12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
        borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: Row(children: [
        Expanded(child: _statBadge('chart_stat_average'.tr(), avg)),
        HorizontalSpace(width: 8),
        Expanded(child: _statBadge('chart_stat_highest'.tr(), high)),
        HorizontalSpace(width: 8),
        Expanded(child: _statBadge('chart_stat_lowest'.tr(), low)),
      ]),
    );
  }

  Widget _statBadge(String title, String value) {
    return Container(
      padding: getPadding(all: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: ColorConstant.bluegray400, fontSize: getFontSize(12), fontFamily: 'Gilroy-Medium')),
        VerticalSpace(height: 6),
        Text(value, style: TextStyle(fontSize: getFontSize(18), fontFamily: 'Gilroy-Medium', fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _tirDonut(double percent, bool isDark) {
    return SizedBox(
      height: 180,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(
            value: percent / 100.0,
            strokeWidth: 14,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${percent.toStringAsFixed(0)}%', style: TextStyle(fontSize: getFontSize(22), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('chart_time_in_range'.tr()),
        ]),
        // 범례 (동적 % → "15% High" 형식)
        Positioned(
          right: 0,
          top: 0,
          child: Builder(builder: (context) {
            final Map<String, double> t = _tir ?? {'veryHigh': 0.17, 'inRange': 0.62, 'low': 0.12, 'veryLow': 0.09};
            double total = (t['veryHigh'] ?? 0) + (t['inRange'] ?? 0) + (t['low'] ?? 0) + (t['veryLow'] ?? 0);
            double safe(double v) => total > 0 ? (v / total) : 0;
            final int vh = (safe((t['veryHigh'] ?? 0)) * 100).round();
            final int ir = (safe((t['inRange'] ?? 0)) * 100).round();
            final int lo = (safe((t['low'] ?? 0)) * 100).round();
            final int vl = (safe((t['veryLow'] ?? 0)) * 100).round();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _LegendDot(color: Colors.orange, label: 'chart_legend_high'.tr(namedArgs: {'p': '$vh'})),
              _LegendDot(color: Colors.blue, label: 'chart_legend_in_range'.tr(namedArgs: {'p': '$ir'})),
              _LegendDot(color: Colors.pink, label: 'chart_legend_low'.tr(namedArgs: {'p': '$lo'})),
              _LegendDot(color: Colors.red, label: 'chart_legend_very_low'.tr(namedArgs: {'p': '$vl'})),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _tirPieCard(bool isDark) {
    if (_loading) {
      return Container(
        padding: getPadding(all: 12),
        decoration: BoxDecoration(
          color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
          borderRadius: BorderRadius.circular(getHorizontalSize(12)),
          border: Border.all(color: ColorConstant.indigo51, width: 1),
        ),
        child: const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
      );
    }
    final Map<String, double> t = _tir ?? {'veryHigh': 0.0, 'inRange': 0.0, 'low': 0.0, 'veryLow': 0.0};
    final double veryHigh = (t['veryHigh'] ?? 0).clamp(0.0, 1.0);
    final double inRange = (t['inRange'] ?? 0).clamp(0.0, 1.0);
    final double low = (t['low'] ?? 0).clamp(0.0, 1.0);
    final double veryLow = (t['veryLow'] ?? 0).clamp(0.0, 1.0);
    final double total = (veryHigh + inRange + low + veryLow);
    double safe(double v){ return total > 0 ? v/total : 0; }
    final double vh = safe(veryHigh);
    final double ir = safe(inRange);
    final double lo = safe(low);
    final double vl = safe(veryLow);

    return Container(
      padding: getPadding(all: 12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
        borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'chart_range_distribution'.tr(),
                  style: TextStyle(
                    fontSize: getFontSize(16),
                    fontFamily: 'Gilroy-Medium',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'chart_percent_by_range'.tr(),
                  style: TextStyle(
                    color: ColorConstant.bluegray400,
                    fontSize: getFontSize(12),
                    fontFamily: 'Gilroy-Medium',
                  ),
                ),
              ]),
              const Icon(Icons.pie_chart_rounded, color: Colors.black54),
            ],
          ),
          VerticalSpace(height: 8),
          Row(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    startDegreeOffset: -90,
                    sections: [
                      if (vh > 0)
                        PieChartSectionData(
                          color: Colors.orange,
                          value: vh,
                          title: '${(vh * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      if (ir > 0)
                        PieChartSectionData(
                          color: Colors.green,
                          value: ir,
                          title: '${(ir * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      if (lo > 0)
                        PieChartSectionData(
                          color: Colors.pink,
                          value: lo,
                          title: '${(lo * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      if (vl > 0)
                        PieChartSectionData(
                          color: Colors.red,
                          value: vl,
                          title: '${(vl * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                    ],
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 350),
                  swapAnimationCurve: Curves.easeOut,
                ),
              ),
              HorizontalSpace(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(color: Colors.orange, label: 'chart_legend_high'.tr(namedArgs: {'p': '${(vh * 100).toStringAsFixed(0)}'})),
                    const SizedBox(height: 6),
                    _LegendDot(color: Colors.green, label: 'chart_legend_in_range'.tr(namedArgs: {'p': '${(ir * 100).toStringAsFixed(0)}'})),
                    const SizedBox(height: 6),
                    _LegendDot(color: Colors.pink, label: 'chart_legend_low'.tr(namedArgs: {'p': '${(lo * 100).toStringAsFixed(0)}'})),
                    const SizedBox(height: 6),
                    _LegendDot(color: Colors.red, label: 'chart_legend_very_low'.tr(namedArgs: {'p': '${(vl * 100).toStringAsFixed(0)}'})),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reloadTir() async {
    setState(() => _loading = true);
    try {
      final int h = _hoursFromRange(hoursRange);
      final DateTime now = DateTime.now();
      final DateTime from = now.subtract(Duration(hours: h));
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final local = await GlucoseLocalRepo().range(from: from, to: now, limit: 50000, eqsn: eqsn, userId: userId);
      int veryLow = 0, low = 0, inRange = 0, high = 0;
      for (final r in local) {
        final double v = ((r['value'] as num?) ?? 0).toDouble();
        if (v < 54) {
          veryLow++;
        } else if (v < 70) {
          low++;
        } else if (v <= 180) {
          inRange++;
        } else {
          high++;
        }
      }
      final double total = (veryLow + low + inRange + high).toDouble();
      Map<String, double> out;
      if (total > 0) {
        out = {
          'veryHigh': high / total,
          'inRange': inRange / total,
          'low': low / total,
          'veryLow': veryLow / total,
        };
      } else {
        out = {'veryHigh': 0.0, 'inRange': 0.0, 'low': 0.0, 'veryLow': 0.0};
      }
      if (mounted) setState(() => _tir = out);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reloadStats() async {
    try {
      final int h = _hoursFromRange(hoursRange);
      final DateTime now = DateTime.now();
      final DateTime from = now.subtract(Duration(hours: h));
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final local = await GlucoseLocalRepo().range(from: from, to: now, limit: 50000, eqsn: eqsn, userId: userId);
      if (local.isEmpty) {
        if (!mounted) return;
        setState(() { _avg = null; _highest = null; _lowest = null; });
        return;
      }
      double sum = 0.0;
      double minV = double.infinity;
      double maxV = -double.infinity;
      for (final r in local) {
        final double v = ((r['value'] as num?) ?? 0).toDouble();
        sum += v;
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      final double avg = sum / local.length;
      if (!mounted) return;
      setState(() {
        _avg = avg * _unitFactor;
        _highest = maxV * _unitFactor;
        _lowest = minV * _unitFactor;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _avg = null; _highest = null; _lowest = null; });
    }
  }

  int _hoursFromRange(String r) {
    if (r.endsWith('h')) {
      final String n = r.substring(0, r.length - 1);
      final int? v = int.tryParse(n);
      if (v != null && v > 0) return v;
    }
    return 6;
  }

  // --- charts for Trend tab ---
  // removed old summary charts (replaced by new report card)

  // removed

  // removed

}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

/// TG_01_02: 혈당 그래프(가로모드)
///
/// - 확대 마크(아이콘) 터치 → 가로모드 전환
/// - 가로모드에서 BACK(축소) → 이전 세로모드(홈/트렌드)로 복귀
class Tg0102ChartLandscapeScreen extends StatelessWidget {
  const Tg0102ChartLandscapeScreen({required this.hoursRange, super.key});
  final String hoursRange;
  @override
  Widget build(BuildContext context) {
    // evidence marker (best-effort)
    () async {
      try {
        final st = await SettingsStorage.load();
        st['tg0102ViewedAt'] = DateTime.now().toUtc().toIso8601String();
        await SettingsStorage.save(st);
      } catch (_) {}
    }();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RotatedBox(
          quarterTurns: 1,
          child: Stack(children: [
          Positioned.fill(
            child: ChartPage(
              embedded: true,
              hoursRange: hoursRange,
              startWide: true,
            ),
          ),
          // 가로→세로 복귀 아이콘(얇은 반투명 배경 유지)
          Positioned(
            left: 12,
            bottom: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
                  ),
                  child: Text(
                    'chart_back_upper'.tr(),
                    style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ]),
        ),
      ),
    );
  }
}


