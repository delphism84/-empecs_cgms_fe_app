import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

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

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
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
        title: const Text('View Previous Data (PD_01_01)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Previous sensor periods (offline)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Text('No previous data found. (Seed via /emu/app/pd0101)', style: TextStyle(color: Colors.black54))
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
                    // scope: in this iteration we only show list (selection → detailed graph screen TBD)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected $eqsn')));
                  },
                ),
              );
            }),
          const SizedBox(height: 10),
          const Text(
            'Note: This screen is seeded by the QA emulator for verification.\n'
            'In production, tapping refresh would download records from server and cache locally.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

