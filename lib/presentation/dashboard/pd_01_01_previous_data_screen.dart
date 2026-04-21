import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/presentation/dashboard/pd_previous_period_chart_screen.dart';
import 'package:helpcare/presentation/dashboard/pd_previous_routes.dart';

/// Previous data view screen (ppt slide 2)
///
/// - 메인 화면 우하단 버튼 → "View Previous Data" 팝업
/// - 서버에 저장된 이전 기록 다운로드 → 디바이스에 저장(오프라인 조회)
/// - 기간(센서별) 선택 시 해당 기간의 그래프를 표시
///
/// 구현 범위(현 단계):
/// - 로컬 DB에 저장된 `eqsn`별 기간 목록을 보여줌
/// - (에뮬레이션) emu 엔드포인트가 이전 센서 데이터를 로컬 DB에 시드
class Pd0101PreviousDataScreen extends StatefulWidget {
  const Pd0101PreviousDataScreen({super.key});

  @override
  State<Pd0101PreviousDataScreen> createState() => _Pd0101PreviousDataScreenState();
}

class _Pd0101PreviousDataScreenState extends State<Pd0101PreviousDataScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _markViewed();
    _reload();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['pd0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  String _fmtRange(int fromMs, int toMs) {
    if (fromMs <= 0 || toMs <= 0) return '—';
    final a = DateTime.fromMillisecondsSinceEpoch(fromMs, isUtc: true).toLocal();
    final b = DateTime.fromMillisecondsSinceEpoch(toMs, isUtc: true).toLocal();
    String d(DateTime t) => '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
    return '${d(a)} ~ ${d(b)}';
  }

  Future<void> _downloadFromServer() async {
    try {
      final now = DateTime.now();
      final from = now.subtract(Duration(days: AppConstants.defaultSensorValidityDays * 3));
      await DataService().fetchGlucose(from: from, to: now, limit: 5000, skipLocalCache: true);
    } catch (_) {}
  }

  Future<void> _reload({bool fetchRemote = false}) async {
    setState(() => _loading = true);
    try {
      if (fetchRemote) {
        await _downloadFromServer();
      }
      final rows = await GlucoseLocalRepo().listEqsnRanges();
      _items = rows;
      try {
        final st = await SettingsStorage.load();
        st['pd0101ItemsCount'] = rows.length;
        st['pd0101RefreshedAt'] = DateTime.now().toUtc().toIso8601String();
        await SettingsStorage.save(st);
      } catch (_) {}
    } catch (_) {
      _items = const [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('pd0101_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'pd0101_refresh_tooltip'.tr(),
            onPressed: _loading ? null : () => _reload(fetchRemote: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'pd0101_list_intro'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Text(
              'pd0101_empty_hint'.tr(),
              style: const TextStyle(color: Colors.black54, height: 1.35),
            )
          else
            ..._items.map((m) {
              final String eqsn = (m['eqsn'] as String? ?? '').trim();
              final int fromMs = (m['fromMs'] as int?) ?? 0;
              final int toMs = (m['toMs'] as int?) ?? 0;
              final int count = (m['count'] as int?) ?? 0;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: ListTile(
                  title: Text(eqsn, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('pd0101_row_points'.tr(namedArgs: {
                    'range': _fmtRange(fromMs, toMs),
                    'n': '$count',
                  })),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: PdPreviousRoutes.chart),
                        builder: (_) => PdPreviousPeriodChartScreen(
                          eqsn: eqsn,
                          fromMs: fromMs,
                          toMs: toMs,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          const SizedBox(height: 10),
          Text(
            'pd0101_footer_help'.tr(),
            style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

