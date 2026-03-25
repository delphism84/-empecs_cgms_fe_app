import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/spacing.dart';
import 'package:helpcare/widgets/debug_badge.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/presentation/report/_report_widgets.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class CgmsReportScreen extends StatefulWidget {
  const CgmsReportScreen({super.key});

  @override
  State<CgmsReportScreen> createState() => _CgmsReportScreenState();
}

class _CgmsReportScreenState extends State<CgmsReportScreen> {
  String period = '7d';
  bool _loading = false;
  List<double> _values = const [];

  @override
  void initState() {
    super.initState();
    _markViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRendered());
    _reload();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['rp0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _markRendered() async {
    try {
      final st = await SettingsStorage.load();
      st['rp0101RenderedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: getPadding(left: 16, right: 16, top: 16, bottom: 16),
          children: [
            // header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Glucose Report (RP_01_01)',
                  style: TextStyle(
                    fontSize: getFontSize(20),
                    fontFamily: 'Gilroy-Medium',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 8),
            // 기간 선택: 가로 탭 버튼 (1 Day, 7 Days, 30 Days, 90 Days)
            // 글로벌 텍스트 스케일(접근성) 영향 제거하여 탭 글자 크기 고정
            MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: _periodTabs(context),
            ),
            if (_loading) const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 3),
            ),
            VerticalSpace(height: 12),
            // Profile Card (under header)
            ReportCard(
              title: 'Profile',
              subtitle: 'User information',
              trailing: const Icon(Icons.person, color: Colors.black54),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: ColorConstant.green500.withOpacity(0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.account_circle, color: Colors.black54, size: 32),
                  ),
                  HorizontalSpace(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // username: black bold
                      Text('username', style: TextStyle(fontSize: getFontSize(16), fontWeight: FontWeight.w700, color: Colors.black)),
                      VerticalSpace(height: 6),
                      Wrap(spacing: 14, runSpacing: 6, children: [
                        _infoRow(Icons.email, 'email@example.com'),
                        _infoRow(Icons.phone, '+82-10-0000-0000'),
                        _infoRow(Icons.cake, 'Age 35'),
                        _infoRow(Icons.male, 'Male'),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            VerticalSpace(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Share',
                    padding: ButtonPadding.PaddingAll12,
                    variant: ButtonVariant.FillWhiteA700,
                    fontStyle: ButtonFontStyle.GilroyMedium16IndigoA700,
                    onTap: () {
                      Navigator.of(context).pushNamed('/sc/07/01');
                    },
                  ),
                ),
                HorizontalSpace(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'Export',
                    padding: ButtonPadding.PaddingAll12,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            VerticalSpace(height: 12),
            // KPI panel
            DebugBadge(
              reqId: 'RP_01_01',
              child: ReportCard(
                title: 'Summary',
                subtitle: 'Key Metrics',
                trailing: const Icon(Icons.analytics, color: Colors.black54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: _kpiTile('Time in Range', _tirPct().toStringAsFixed(0) + '%')),
                      HorizontalSpace(width: 8),
                      Expanded(child: _kpiTile('Average', _avgGlucose().toStringAsFixed(0))),
                    ]),
                    VerticalSpace(height: 8),
                    Row(children: [
                      Expanded(child: _kpiTile('StdDev / CV', _stdDevCv())),
                      HorizontalSpace(width: 8),
                      Expanded(child: _kpiTile('Hypo/Hyper', _hypoHyper())),
                    ]),
                    VerticalSpace(height: 8),
                    Row(children: [
                      Expanded(child: _kpiTile('GMI', '${_gmi(_avgGlucose()).toStringAsFixed(1)}%')),
                      HorizontalSpace(width: 8),
                      const Expanded(child: SizedBox()),
                    ]),
                  ],
                ),
              ),
            ),
            VerticalSpace(height: 12),
            // chart section 1: Range distribution (bars)
            ReportCard(
              title: 'Range Distribution',
              subtitle: 'Percent by range',
              trailing: const Icon(Icons.pie_chart_rounded, color: Colors.black54),
              child: _rangePieChart(context),
            ),
            VerticalSpace(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _kpiTile(String title, String value) {
    return Container(
      padding: getPadding(all: 12),
      decoration: BoxDecoration(
        color: ColorConstant.whiteA700,
        borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: ColorConstant.bluegray400, fontSize: getFontSize(12), fontFamily: 'Gilroy-Medium')),
          VerticalSpace(height: 6),
          Text(value, style: TextStyle(fontSize: getFontSize(18), fontFamily: 'Gilroy-Medium', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.black54),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.black87)),
    ]);
  }

  // sample metrics
  double _avgGlucose() {
    if (_values.isEmpty) return 118;
    double sum = 0;
    for (final v in _values) sum += v;
    return sum / _values.length;
  }

  double _tirPct() {
    if (_values.isEmpty) return 0;
    int inRange = 0;
    for (final v in _values) {
      if (v >= 70 && v <= 180) inRange++;
    }
    return (inRange * 100.0 / _values.length);
  }

  String _stdDevCv() {
    if (_values.length < 2) return '0 / 0%';
    final double avg = _avgGlucose();
    double acc = 0;
    for (final v in _values) {
      final double d = v - avg;
      acc += d * d;
    }
    final double variance = (acc / (_values.length - 1));
    final double std = variance <= 0 ? 0 : MathHelper.sqrt(variance);
    final double cv = avg != 0 ? (std * 100.0 / avg) : 0;
    return '${std.toStringAsFixed(0)} / ${cv.toStringAsFixed(0)}%';
  }

  String _hypoHyper() {
    if (_values.isEmpty) return '0 / 0';
    int hypo = 0, hyper = 0;
    for (final v in _values) {
      if (v < 70) hypo++;
      if (v > 180) hyper++;
    }
    return '$hypo / $hyper';
  }

  double _gmi(double avgMgdl) {
    // ADA: GMI = 3.31 + 0.02392 × mean glucose (mg/dL)
    return 3.31 + 0.02392 * avgMgdl;
  }

  (double high, double inRange, double low) _rangePercents() {
    if (_values.isNotEmpty) {
      int veryLow = 0, low = 0, inRange = 0, high = 0;
      for (final v in _values) {
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
      final int n = _values.length;
      return (high * 100.0 / n, inRange * 100.0 / n, (veryLow + low) * 100.0 / n);
    }
    return (0, 0, 0);
  }

  Widget _periodLabelWidget(String v) {
    const double fs = 12.0;
    final TextStyle style = TextStyle(fontSize: fs, height: 1.2, fontWeight: FontWeight.w500);
    if (v.endsWith('d')) {
      final String n = v.substring(0, v.length - 1);
      final int? d = int.tryParse(n);
      if (d != null) {
        final String label = d == 1 ? '1 day' : '$d days';
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        );
      }
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(v, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    );
  }

  Widget _periodTabs(BuildContext context) {
    final List<String> options = ['1d', '7d', '30d', '90d'];
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
                    if (period == v) return;
                    setState(() => period = v);
                    await _reload();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: period == options[i]
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: period == options[i]
                            ? Theme.of(context).colorScheme.primary
                            : DefaultTextStyle.of(context).style.color ?? Colors.black87,
                        fontWeight: period == options[i] ? FontWeight.w600 : FontWeight.w500,
                      ),
                      child: _periodLabelWidget(options[i]),
                    ),
                  ),
                ),
              ),
              if (i != options.length - 1)
                Container(width: 1, height: 32, color: ColorConstant.indigo51),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangePieChart(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: getVerticalSize(220),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final (double high, double inRange, double low) = _rangePercents();
    final double veryLow = (100 - high - inRange - low).clamp(0, 100);
    final List<PieChartSectionData> sections = [
      PieChartSectionData(
        value: high,
        color: Colors.orange,
        title: '${high.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      PieChartSectionData(
        value: inRange,
        color: Colors.green,
        title: '${inRange.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      PieChartSectionData(
        value: low,
        color: Colors.pink,
        title: '${low.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      PieChartSectionData(
        value: veryLow,
        color: Colors.red,
        title: veryLow > 0 ? '${veryLow.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    ];

    return SizedBox(
      height: getVerticalSize(220),
      child: Row(children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: sections,
              startDegreeOffset: -90,
            ),
            swapAnimationDuration: const Duration(milliseconds: 350),
            swapAnimationCurve: Curves.easeOut,
          ),
        ),
        const SizedBox(width: 12),
        // legend with percent prefix
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          _PieLegendDot(color: Colors.orange, label: '${high.toStringAsFixed(0)}% High'),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.green, label: '${inRange.toStringAsFixed(0)}% In Range'),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.pink, label: '${low.toStringAsFixed(0)}% Low'),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.red, label: '${veryLow.toStringAsFixed(0)}% Very Low'),
        ]),
      ]),
    );
  }

  // ignore: unused_element
  Widget _summaryBarChart(BuildContext context) {
    final (double high, double inRange, double low) = _rangePercents();
    // replicate as a compact variant with different widths
    final List<BarChartGroupData> groups = [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: high, color: Colors.amber, width: 16, borderRadius: BorderRadius.circular(5))]),
      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: inRange, color: Colors.green, width: 16, borderRadius: BorderRadius.circular(5))]),
      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: low, color: Colors.redAccent, width: 16, borderRadius: BorderRadius.circular(5))]),
    ];

    return SizedBox(
      height: getVerticalSize(160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: 100,
                minY: 0,
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 20, getTitlesWidget: (v, m) => Text('${v.toInt()}%'))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    switch (v.toInt()) {
                      case 0:
                        return const Text('High');
                      case 1:
                        return const Text('In Range');
                      case 2:
                        return const Text('Low');
                    }
                    return const SizedBox.shrink();
                  }))),
                barGroups: groups,
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
              swapAnimationCurve: Curves.easeOut,
            ),
          ),
          VerticalSpace(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Avg: ${_avgGlucose().toStringAsFixed(0)} mg/dL'),
              Text('GMI: ${_gmi(_avgGlucose()).toStringAsFixed(1)}%'),
            ],
          )
        ],
      ),
    );
  }

  Duration _periodDuration() {
    switch (period) {
      case '1d':
        return const Duration(days: 1);
      case '7d':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
      case '90d':
        return const Duration(days: 90);
      default:
        return const Duration(days: 7);
    }
  }

  Future<void> _reload() async {
    final started = DateTime.now();
    setState(() => _loading = true);
    try {
      final DateTime now = DateTime.now();
      final DateTime from = now.subtract(_periodDuration());
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final local = await GlucoseLocalRepo().range(from: from, to: now, limit: 50000, eqsn: eqsn, userId: userId);
      final List<double> vals = local.map((e) => ((e['value'] as num?) ?? 0).toDouble()).toList();
      setState(() => _values = vals);
    } catch (_) {
      // keep old values on failure
    } finally {
      final elapsed = DateTime.now().difference(started);
      final remain = const Duration(seconds: 1) - elapsed;
      if (remain > Duration.zero) {
        await Future.delayed(remain);
      }
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _PieLegendDot extends StatelessWidget {
  const _PieLegendDot({required this.color, required this.label});
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


