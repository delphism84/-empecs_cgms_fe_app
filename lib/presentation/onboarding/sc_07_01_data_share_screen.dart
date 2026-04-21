import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/color_constant.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:easy_localization/easy_localization.dart';

class Sc0701DataShareScreen extends StatefulWidget {
  const Sc0701DataShareScreen({super.key});

  @override
  State<Sc0701DataShareScreen> createState() => _Sc0701DataShareScreenState();
}

class _Sc0701DataShareScreenState extends State<Sc0701DataShareScreen> {
  bool enable = true;
  String preset = 'Custom'; // 1D/7D/30D/Custom
  DateTimeRange? customRange;

  bool shareGlucoseSummary = true;
  bool shareGlucoseDistribution = true;
  bool shareGlucoseGraph = true;
  bool shareUserProfile = false;

  String exportFormat = 'PDF'; // CSV/PDF
  bool revokeAnytime = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _markViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRendered());
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0701ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _markRendered() async {
    try {
      final st = await SettingsStorage.load();
      st['sc0701RenderedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  DateTimeRange _default7d() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 6));
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _loadPrefs() async {
    try {
      final st = await SettingsStorage.load();
      final bool vEnable = st['sc0701Enabled'] != false;
      final String vPreset = (st['sc0701Preset'] as String? ?? 'Custom').trim();
      final String vFrom = (st['sc0701From'] as String? ?? '').trim();
      final String vTo = (st['sc0701To'] as String? ?? '').trim();

      DateTimeRange r = _default7d();
      final DateTime? from = vFrom.isEmpty ? null : DateTime.tryParse(vFrom);
      final DateTime? to = vTo.isEmpty ? null : DateTime.tryParse(vTo);
      if (from != null && to != null) {
        r = DateTimeRange(
          start: DateTime(from.year, from.month, from.day),
          end: DateTime(to.year, to.month, to.day),
        );
      }

      if (!mounted) return;
      setState(() {
        enable = vEnable;
        preset = vPreset.isEmpty ? 'Custom' : vPreset;
        customRange = r;
        shareGlucoseSummary = st['sc0701ItemSummary'] != false;
        shareGlucoseDistribution = st['sc0701ItemDistribution'] != false;
        shareGlucoseGraph = st['sc0701ItemGraph'] != false;
        shareUserProfile = st['sc0701ItemUserProfile'] == true;
        final String fmt = (st['sc0701Format'] as String? ?? 'PDF').trim();
        exportFormat = fmt.isEmpty ? 'PDF' : fmt;
        revokeAnytime = st['sc0701Revocable'] != false;
      });
    } catch (_) {}
  }

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  /// 로컬 자정~종료일 23:59:59.999 (DB time_ms와 동일 기준으로 하루 전체 포함)
  (DateTime, DateTime) _rangeToLocalBounds(DateTimeRange r) {
    final DateTime start = DateTime(r.start.year, r.start.month, r.start.day);
    final DateTime end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
    return (start, end);
  }

  Future<List<Map<String, dynamic>>> _loadGlucoseRowsForRange(DateTimeRange r) async {
    final (DateTime from, DateTime to) = _rangeToLocalBounds(r);
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String eqsn = (st['eqsn'] as String? ?? '').trim();
    final String userId = (st['lastUserId'] as String? ?? '').trim();
    List<Map<String, dynamic>> rows = await GlucoseLocalRepo().range(
      from: from,
      to: to,
      limit: 200000,
      eqsn: eqsn.isEmpty ? null : eqsn,
      userId: userId,
    );
    // Ingest/BLE가 eqsn을 'LOCAL'·NULL·빈 문자열로 남기고 설정만 실제 SN인 경우 1차 조회가 0건이 됨.
    if (rows.isEmpty && eqsn.isNotEmpty) {
      final List<Map<String, dynamic>> loose = await GlucoseLocalRepo().range(
        from: from,
        to: to,
        limit: 200000,
        eqsn: null,
        userId: userId,
      );
      if (loose.isNotEmpty) rows = loose;
    }
    return rows;
  }

  Map<String, int> _distributionCounts(Iterable<Map<String, dynamic>> rows) {
    int veryLow = 0, low = 0, inRange = 0, high = 0;
    for (final Map<String, dynamic> row in rows) {
      final double v = ((row['value'] as num?) ?? 0).toDouble();
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
    return {'veryLow': veryLow, 'low': low, 'inRange': inRange, 'high': high};
  }

  String _rangeLabel(DateTimeRange r) {
    final int days = r.end.difference(r.start).inDays + 1;
    return '${_fmtDate(r.start)} ~ ${_fmtDate(r.end)} (${'sensor_share_days_count'.tr(namedArgs: {'n': '$days'})})';
  }

  void _applyPreset(String p) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    int days = 7;
    if (p == '1D') days = 1;
    if (p == '7D') days = 7;
    if (p == '30D') days = 30;
    final start = end.subtract(Duration(days: days - 1));
    setState(() {
      preset = p;
      customRange = DateTimeRange(start: start, end: end);
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = customRange ?? _default7d();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: init,
      helpText: 'sensor_share_date_picker_help'.tr(),
    );
    if (picked == null) return;
    setState(() {
      preset = 'Custom';
      customRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  Future<void> _saveEvidence({required bool shared}) async {
    final r = customRange ?? _default7d();
    final int days = r.end.difference(r.start).inDays + 1;
    final String note = days == 1
        ? 'sensor_share_evidence_1day'.tr()
        : 'sensor_share_evidence_ndays'.tr(namedArgs: {'n': '$days'});
    final st = await SettingsStorage.load();

    // legacy (호환)
    st['shareConsent'] = enable;
    st['shareRange'] = days.toString();
    st['shareFrom'] = r.start.toIso8601String();
    st['shareTo'] = r.end.toIso8601String();

    // SC_07_01 evidence
    st['sc0701ViewedAt'] = DateTime.now().toUtc().toIso8601String();
    st['sc0701Enabled'] = enable;
    st['sc0701Preset'] = preset;
    st['sc0701From'] = r.start.toIso8601String();
    st['sc0701To'] = r.end.toIso8601String();
    st['sc0701ItemSummary'] = shareGlucoseSummary;
    st['sc0701ItemDistribution'] = shareGlucoseDistribution;
    st['sc0701ItemGraph'] = shareGlucoseGraph;
    st['sc0701ItemUserProfile'] = shareUserProfile;
    st['sc0701Format'] = exportFormat;
    st['sc0701Revocable'] = revokeAnytime;
    if (shared) {
      st['sc0701LastSharedAt'] = DateTime.now().toUtc().toIso8601String();
      st['sc0701LastSharedOk'] = true;
      st['sc0701LastNote'] = note;
    }
    await SettingsStorage.save(st);
  }

  Future<void> _share() async {
    if (!enable) return;
    if (customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sensor_share_select_range_snack'.tr())));
      return;
    }
    if (!shareGlucoseSummary && !shareGlucoseDistribution && !shareGlucoseGraph && !shareUserProfile) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sensor_share_select_item_snack'.tr())));
      return;
    }
    await _saveEvidence(shared: true);

    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String ext = exportFormat.toLowerCase();
      final String ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '');
      final File file = File('${dir.path}/cgms-share-$ts.$ext');
      final DateTimeRange r = customRange ?? _default7d();
      final bool wantGlucose = shareGlucoseSummary || shareGlucoseDistribution || shareGlucoseGraph;
      final (DateTime gFrom, DateTime gTo) = _rangeToLocalBounds(r);
      if (wantGlucose) {
        try {
          await DataService().fetchGlucose(from: gFrom, to: gTo, limit: 200000, skipLocalCache: true);
        } catch (_) {}
      }
      final List<Map<String, dynamic>> glucoseRows = wantGlucose ? await _loadGlucoseRowsForRange(r) : <Map<String, dynamic>>[];

      if (exportFormat.toUpperCase() == 'PDF') {
        final Map<String, dynamic> st0 = await SettingsStorage.load();
        final String profileName = (st0['displayName'] as String? ?? '').trim();
        final String profileId = (st0['lastUserId'] as String? ?? '').trim();

        final pw.Document doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            build: (pw.Context ctx) {
              final List<pw.Widget> children = <pw.Widget>[
                pw.Text('sensor_share_pdf_title'.tr(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('${'sensor_share_date_range'.tr()}: ${_rangeLabel(r)}'),
                pw.SizedBox(height: 8),
                pw.Text(
                  '${'sensor_share_glucose_summary'.tr()}: $shareGlucoseSummary · ${'sensor_share_glucose_dist'.tr()}: $shareGlucoseDistribution · '
                  '${'sensor_share_glucose_graph'.tr()}: $shareGlucoseGraph · ${'sensor_share_user_profile'.tr()}: $shareUserProfile',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 12),
              ];

              if (shareUserProfile) {
                children.add(pw.Text('${'sensor_share_user_profile'.tr()}:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
                if (profileName.isNotEmpty) {
                  children.add(pw.Text('${'common_name'.tr()}: $profileName'));
                }
                if (profileId.isNotEmpty) {
                  children.add(pw.Text('${'common_email'.tr()}: $profileId'));
                }
                children.add(pw.SizedBox(height: 12));
              }

              if (wantGlucose) {
                if (glucoseRows.isEmpty) {
                  children.add(pw.Text('sensor_share_no_glucose_in_range'.tr(), style: pw.TextStyle(color: PdfColors.grey700)));
                } else {
                  if (shareGlucoseSummary) {
                    double sum = 0;
                    double minV = double.infinity;
                    double maxV = -double.infinity;
                    for (final Map<String, dynamic> row in glucoseRows) {
                      final double v = ((row['value'] as num?) ?? 0).toDouble();
                      sum += v;
                      if (v < minV) minV = v;
                      if (v > maxV) maxV = v;
                    }
                    final double avg = sum / glucoseRows.length;
                    children.add(pw.Text(
                      'sensor_share_points_count'.tr(namedArgs: {'n': '${glucoseRows.length}'}),
                    ));
                    children.add(pw.Text(
                      'sensor_share_summary_stats'.tr(namedArgs: {
                        'avg': avg.toStringAsFixed(1),
                        'min': minV.toStringAsFixed(1),
                        'max': maxV.toStringAsFixed(1),
                      }),
                    ));
                    children.add(pw.SizedBox(height: 8));
                  }
                  if (shareGlucoseDistribution) {
                    final Map<String, int> d = _distributionCounts(glucoseRows);
                    children.add(pw.Text('sensor_share_distribution'.tr(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
                    children.add(pw.Text('<54: ${d['veryLow']} · 54–69: ${d['low']} · 70–180: ${d['inRange']} · >180: ${d['high']}'));
                    children.add(pw.SizedBox(height: 8));
                  }
                  if (shareGlucoseGraph || shareGlucoseSummary || shareGlucoseDistribution) {
                    const int maxRows = 80;
                    final int n = glucoseRows.length > maxRows ? maxRows : glucoseRows.length;
                    final List<List<String>> data = <List<String>>[];
                    for (int i = 0; i < n; i++) {
                      final Map<String, dynamic> row = glucoseRows[i];
                      final int ms = (row['time_ms'] as int?) ?? 0;
                      final String iso = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
                      final String v = ((row['value'] as num?) ?? 0).toString();
                      final Object? tr = row['trid'];
                      data.add(<String>[iso, v, '$tr']);
                    }
                    children.add(pw.Text('sensor_share_section_glucose'.tr(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
                    children.add(
                      pw.Table.fromTextArray(
                        headers: <String>['UTC ISO', 'mg/dL', 'trid'],
                        data: data,
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                        cellStyle: const pw.TextStyle(fontSize: 8),
                        cellAlignment: pw.Alignment.centerLeft,
                      ),
                    );
                    if (glucoseRows.length > maxRows) {
                      children.add(pw.SizedBox(height: 6));
                      children.add(pw.Text(
                        'sensor_share_truncated_note'.tr(namedArgs: {'n': '$maxRows'}),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ));
                    }
                  }
                }
              }

              children.add(pw.SizedBox(height: 16));
              children.add(pw.Text(
                'Generated (UTC): ${DateTime.now().toUtc().toIso8601String()}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ));
              return children;
            },
          ),
        );
        await file.writeAsBytes(await doc.save());
      } else {
        final StringBuffer buf = StringBuffer();
        buf.writeln('# CGMS Data Share (SC_07_01)');
        buf.writeln('# range=${_rangeLabel(r)}');
        buf.writeln('# generatedAt=${DateTime.now().toUtc().toIso8601String()}');
        if (shareUserProfile) {
          final Map<String, dynamic> st = await SettingsStorage.load();
          buf.writeln('# profile.displayName=${st['displayName']}');
          buf.writeln('# profile.userId=${st['lastUserId']}');
        }
        if (wantGlucose) {
          buf.writeln('time_utc_iso,value_mg_dl,trid');
          for (final Map<String, dynamic> row in glucoseRows) {
            final int ms = (row['time_ms'] as int?) ?? 0;
            final String iso = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
            final String v = ((row['value'] as num?) ?? 0).toString();
            final Object? tr = row['trid'];
            buf.writeln('$iso,$v,$tr');
          }
          if (glucoseRows.isEmpty) {
            buf.writeln('# sensor_share_no_glucose_in_range');
          }
        }
        await file.writeAsString(buf.toString());
      }
      final Map<String, dynamic> st = await SettingsStorage.load();
      st['sc0701LastFilePath'] = file.path;
      await SettingsStorage.save(st);
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: '${'sensor_share_pdf_title'.tr()} - ${_rangeLabel(r)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('sensor_share_done_snack'.tr(namedArgs: {'format': exportFormat}))),
        );
      }
      return;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sensor_share_prepared_snack'.tr(namedArgs: {'format': exportFormat}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = customRange ?? _default7d();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('sensor_share_appbar'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'sensor_share_subtitle'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _panel(
                title: 'sensor_share_basic'.tr(),
                child: Column(
                  children: [
                    _rowSwitch(
                      label: 'sensor_share_enable'.tr(),
                      value: enable,
                      onChanged: (v) => setState(() => enable = v),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: _presetBtn('7D', label: 'sensor_share_preset_7d'.tr())),
                        const SizedBox(width: 8),
                        Expanded(child: _presetBtn('Custom', label: 'sensor_preset_custom'.tr(), onTap: enable ? _pickRange : null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? ColorConstant.bluegray902 : ColorConstant.bluegray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      child: Text(
                        _rangeLabel(r),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _panel(
                title: 'sensor_share_items'.tr(),
                child: Column(
                  children: [
                    _rowSwitch(
                      label: 'sensor_share_glucose_data'.tr(),
                      value: shareGlucoseSummary || shareGlucoseDistribution || shareGlucoseGraph,
                      onChanged: enable
                          ? (v) => setState(() {
                                shareGlucoseSummary = v;
                                shareGlucoseDistribution = v;
                                shareGlucoseGraph = v;
                              })
                          : null,
                    ),
                    _rowSwitch(
                      label: 'sensor_share_user_profile'.tr(),
                      value: shareUserProfile,
                      onChanged: enable ? (v) => setState(() => shareUserProfile = v) : null,
                    ),
                  ],
                ),
              ),
              _panel(
                title: 'sensor_share_export_group'.tr(),
                child: Row(
                  children: [
                    Expanded(child: _formatBtn('PDF')),
                    const SizedBox(width: 8),
                    Expanded(child: _formatBtn('CSV')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: enable ? _share : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConstant.loginGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('sensor_share_upper_share'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _saveEvidence(shared: false);
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConstant.baseColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: ColorConstant.baseColor, width: 1),
                        ),
                      ),
                      child: Text('sensor_save_upper'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? ColorConstant.darkTextField : Colors.white;
    final Color border = isDark ? Colors.white24 : Colors.black12;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _rowSwitch({required String label, required bool value, required ValueChanged<bool>? onChanged}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.bluegray902 : ColorConstant.bluegray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _presetBtn(String p, {String? label, VoidCallback? onTap}) {
    final selected = preset == p;
    final VoidCallback? handler = onTap ?? (enable ? () => _applyPreset(p) : null);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color border = isDark ? Colors.white24 : Colors.black12;
    final Color selectedBg = isDark ? ColorConstant.loginGreen : ColorConstant.loginGreen;
    final Color selectedFg = Colors.white;
    final Color unselectedBg = isDark ? ColorConstant.bluegray902 : Colors.white;
    final Color unselectedFg = isDark ? Colors.white : Colors.black87;
    return InkWell(
      onTap: handler,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ColorConstant.loginGreen.withOpacity(0.9) : border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label ?? p,
          style: TextStyle(
            color: selected ? selectedFg : unselectedFg,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _formatBtn(String fmt) {
    final selected = exportFormat == fmt;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color border = isDark ? Colors.white24 : Colors.black12;
    final Color selectedBg = isDark ? ColorConstant.baseColor : ColorConstant.baseColor;
    final Color selectedFg = Colors.white;
    final Color unselectedBg = isDark ? ColorConstant.bluegray902 : Colors.white;
    final Color unselectedFg = isDark ? Colors.white : Colors.black87;
    return InkWell(
      onTap: enable ? () => setState(() => exportFormat = fmt) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ColorConstant.baseColor.withOpacity(0.9) : border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          fmt,
          style: TextStyle(
            color: selected ? selectedFg : unselectedFg,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

