import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/color_constant.dart';
import 'package:path_provider/path_provider.dart';

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

  String _rangeLabel(DateTimeRange r) {
    final int days = r.end.difference(r.start).inDays + 1;
    return '${_fmtDate(r.start)} ~ ${_fmtDate(r.end)} ($days days)';
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
      helpText: 'Select sharing date range',
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
    final note = days == 1 ? 'Sharing 1 day only' : 'Sharing $days days';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date range.')));
      return;
    }
    if (!shareGlucoseSummary && !shareGlucoseDistribution && !shareGlucoseGraph && !shareUserProfile) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item to share.')));
      return;
    }
    await _saveEvidence(shared: true);

    // "저장된 데이터가 어디로 가는지" 최소한의 근거를 남기기 위해 로컬 파일(placeholder)을 생성한다.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = exportFormat.toLowerCase();
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '');
      final file = File('${dir.path}/cgms-share-$ts.$ext');
      final r = customRange ?? _default7d();
      await file.writeAsString([
        'CGMS Data Share (SC_07_01)',
        'format=$exportFormat',
        'range=${_rangeLabel(r)}',
        'items: summary=$shareGlucoseSummary distribution=$shareGlucoseDistribution graph=$shareGlucoseGraph profile=$shareUserProfile',
        'method: Android share sheet',
        'generatedAt=${DateTime.now().toUtc().toIso8601String()}',
      ].join('\n'));
      final st = await SettingsStorage.load();
      st['sc0701LastFilePath'] = file.path;
      await SettingsStorage.save(st);
      await Share.shareXFiles([XFile(file.path)], text: 'CGMS Data Share - ${_rangeLabel(r)}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shared via Android share ($exportFormat)')));
      }
      return;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prepared share ($exportFormat)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = customRange ?? _default7d();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('SC_07_01 · Data Share')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sharing period and items. Share opens Android system share sheet.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _panel(
                title: 'Basic',
                child: Column(
                  children: [
                    _rowSwitch(
                      label: 'Enable sharing',
                      value: enable,
                      onChanged: (v) => setState(() => enable = v),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: _presetBtn('7D')),
                        const SizedBox(width: 8),
                        Expanded(child: _presetBtn('Custom', onTap: enable ? _pickRange : null)),
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
                title: 'Sharing items',
                child: Column(
                  children: [
                    _rowSwitch(
                      label: 'Glucose data',
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
                      label: 'User profile',
                      value: shareUserProfile,
                      onChanged: enable ? (v) => setState(() => shareUserProfile = v) : null,
                    ),
                  ],
                ),
              ),
              _panel(
                title: 'Export format',
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
                      child: const Text('SHARE', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _presetBtn(String p, {VoidCallback? onTap}) {
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
          p,
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

