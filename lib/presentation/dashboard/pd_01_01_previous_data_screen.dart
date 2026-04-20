import 'package:flutter/material.dart';
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
        title: const Text('Previous data'),
        actions: [
          IconButton(
            tooltip: 'Refresh — download from server',
            onPressed: _loading ? null : () => _reload(fetchRemote: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sensor periods (newest first). Tap a row for the graph.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Text(
              'No previous sensor periods in local storage.\n'
              'On the main screen, open Previous data → Refresh / download to cache server data for offline use.',
              style: TextStyle(color: Colors.black54, height: 1.35),
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
                  subtitle: Text('${_fmtRange(fromMs, toMs)}  ·  points $count'),
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
          const Text(
            'Sensors are listed with the most recent period first. Tap a row to open the graph for that sensor and date range.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

