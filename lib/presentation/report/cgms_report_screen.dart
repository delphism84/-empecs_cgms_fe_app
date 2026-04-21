import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/report/_report_widgets.dart';
import 'package:helpcare/presentation/settings_page/user_detail_page.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/debug_badge.dart';
import 'package:helpcare/widgets/spacing.dart';
import 'package:easy_localization/easy_localization.dart';

class CgmsReportScreen extends StatefulWidget {
  const CgmsReportScreen({super.key});

  @override
  State<CgmsReportScreen> createState() => _CgmsReportScreenState();
}

class _CgmsReportScreenState extends State<CgmsReportScreen> {
  String period = '7d';
  bool _loading = false;
  List<double> _values = const [];

  String displayName = '';
  String email = '';
  DateTime sensorStart = DateTime.now().subtract(const Duration(days: 3));
  int lifeDays = AppConstants.defaultSensorValidityDays;

  static String _storageString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _markViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRendered());
    _loadUser();
    AppSettingsBus.changed.addListener(_onAppSettingsChanged);
    _reload();
  }

  @override
  void dispose() {
    try {
      AppSettingsBus.changed.removeListener(_onAppSettingsChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onAppSettingsChanged() {
    unawaited(_loadUser());
  }

  Future<void> _loadUser() async {
    try {
      await ProfileSyncService.ensureLocalUserFromJwt();
      final local = await SettingsStorage.load();
      if (!mounted) return;
      setState(() {
        email = _storageString(local['lastUserId']);
        displayName = _storageString(local['displayName']);
        if (displayName.isEmpty && email.isNotEmpty) displayName = email;
        lifeDays = AppConstants.defaultSensorValidityDays;
        final String ssRaw = _storageString(local['sensorStartAt']);
        if (ssRaw.isNotEmpty) {
          final DateTime? p = DateTime.tryParse(ssRaw);
          if (p != null) sensorStart = p.toLocal();
        }
      });
      unawaited(ProfileSyncService.refreshFromServer());
    } catch (_) {}
  }

  /// Settings 상단 사용자 카드와 동일 패턴
  Widget _buildReportUserCard(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime start = sensorStart;
    final int total = lifeDays;
    final Duration used = DateTime.now().difference(start);
    final int remain = (total - used.inDays).clamp(0, total);
    final String name = displayName.trim().isEmpty ? 'common_guest'.tr() : displayName.trim();
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
                Expanded(
                  child: Text(
                    'report_remaining_days'.tr(namedArgs: {'remain': '$remain', 'total': '$total'}),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
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
            ReportCard(
              title: 'report_profile_title'.tr(),
              subtitle: 'report_profile_subtitle'.tr(),
              trailing: const Icon(Icons.person, color: Colors.black54),
              child: _buildReportUserCard(context),
            ),
            VerticalSpace(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'report_share'.tr(),
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
                    text: 'report_export'.tr(),
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
                title: 'report_summary_title'.tr(),
                subtitle: 'report_summary_subtitle'.tr(),
                trailing: const Icon(Icons.analytics, color: Colors.black54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: _kpiTile('chart_time_in_range'.tr(), _tirPct().toStringAsFixed(0) + '%')),
                      HorizontalSpace(width: 8),
                      Expanded(child: _kpiTile('report_kpi_average'.tr(), _avgGlucose().toStringAsFixed(0))),
                    ]),
                    VerticalSpace(height: 8),
                    Row(children: [
                      Expanded(child: _kpiTile('report_kpi_std_cv'.tr(), _stdDevCv())),
                      HorizontalSpace(width: 8),
                      Expanded(child: _kpiTile('report_kpi_hypo_hyper'.tr(), _hypoHyper())),
                    ]),
                    VerticalSpace(height: 8),
                    Row(children: [
                      Expanded(child: _kpiTile('report_kpi_gmi'.tr(), '${_gmi(_avgGlucose()).toStringAsFixed(1)}%')),
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
              title: 'report_range_dist_title'.tr(),
              subtitle: 'report_range_dist_subtitle'.tr(),
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
        final String label = d == 1 ? 'report_period_1_day'.tr() : 'report_period_n_days'.tr(namedArgs: {'n': '$d'});
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
          _PieLegendDot(color: Colors.orange, label: 'chart_legend_high'.tr(namedArgs: {'p': high.toStringAsFixed(0)})),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.green, label: 'chart_legend_in_range'.tr(namedArgs: {'p': inRange.toStringAsFixed(0)})),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.pink, label: 'chart_legend_low'.tr(namedArgs: {'p': low.toStringAsFixed(0)})),
          const SizedBox(height: 6),
          _PieLegendDot(color: Colors.red, label: 'chart_legend_very_low'.tr(namedArgs: {'p': veryLow.toStringAsFixed(0)})),
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
                        return Text('report_bar_label_high'.tr());
                      case 1:
                        return Text('report_bar_label_in_range'.tr());
                      case 2:
                        return Text('report_bar_label_low'.tr());
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
              Text('report_avg_mgdl'.tr(namedArgs: {'v': _avgGlucose().toStringAsFixed(0)})),
              Text('report_gmi_pct'.tr(namedArgs: {'v': _gmi(_avgGlucose()).toStringAsFixed(1)})),
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


