import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';

class LocalDataPage extends StatefulWidget {
  const LocalDataPage({super.key});

  @override
  State<LocalDataPage> createState() => _LocalDataPageState();
}

class _LocalDataPageState extends State<LocalDataPage> {
  bool _loading = true;
  int _totalPoints = 0;
  List<Map<String, dynamic>> _days = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = GlucoseLocalRepo();
      final int total = await repo.count();
      final List<Map<String, dynamic>> days = await repo.listDayCountsDesc();
      if (!mounted) return;
      setState(() {
        _totalPoints = total;
        _days = days;
      });
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmtRange(int minMs, int maxMs) {
    if (minMs <= 0 || maxMs <= 0) return '';
    final a = DateTime.fromMillisecondsSinceEpoch(minMs, isUtc: true).toLocal();
    final b = DateTime.fromMillisecondsSinceEpoch(maxMs, isUtc: true).toLocal();
    String h(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${h(a)} ~ ${h(b)}';
  }

  Future<void> _resetLocalDb() async {
    try {
      await GlucoseLocalRepo().clear();
      await EventLocalRepo().clear();
      final st = await SettingsStorage.load();
      st['lastTrid'] = 0;
      st['lastEvid'] = 0;
      await SettingsStorage.save(st);
      try { DataSyncBus().emitGlucoseBulk(count: 0); } catch (_) {}
      try { DataSyncBus().emitEventBulk(count: 0); } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('local_data_reset_done'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('local_data_appbar'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.storage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'local_data_total_points'.tr(namedArgs: {'n': '$_totalPoints'}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _load,
                        child: Text('local_data_refresh'.tr()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _resetLocalDb,
                        child: Text('local_data_reset_db'.tr()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      if (!_loading && _days.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('local_data_no_days'.tr(), style: const TextStyle(color: Colors.grey)),
                        ),
                      if (!_loading && _days.isNotEmpty)
                        ..._days.map((d) {
                          final day = (d['day'] ?? '').toString();
                          final int c = (d['count'] as int?) ?? 0;
                          final int minMs = (d['minMs'] as int?) ?? 0;
                          final int maxMs = (d['maxMs'] as int?) ?? 0;
                          final range = _fmtRange(minMs, maxMs);
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: Text(day, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: range.isEmpty ? null : Text(range),
                              trailing: Text('$c', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

