import 'dart:async';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';

class LocalSyncService {
  LocalSyncService._internal();
  static final LocalSyncService _instance = LocalSyncService._internal();
  factory LocalSyncService() => _instance;

  Timer? _timer;

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
    // kick immediately
    unawaited(_poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final repo = GlucoseLocalRepo();
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final int fromTrid = await repo.maxTrid(eqsn: eqsn, userId: userId);
      final ds = DataService();
      final List<Map<String, dynamic>> delta = await ds.fetchGlucoseDelta(fromTrid: fromTrid, limit: 1000);
      if (delta.isEmpty) return;
      final List<DateTime> times = [];
      final List<double> values = [];
      final List<int?> trids = [];
      for (final m in delta) {
        final DateTime t = DateTime.parse((m['time'] as String)).toLocal();
        final double v = ((m['value'] as num?) ?? 0).toDouble();
        final int? trid = (m['trid'] as num?)?.toInt();
        times.add(t); values.add(v); trids.add(trid);
      }
      await repo.addPointsBatch(times: times, values: values, trids: trids, eqsn: eqsn, userId: userId);
      // 한 번만 브로드캐스트
      DataSyncBus().emitGlucoseBulk(count: values.length);
    } catch (_) {
      // ignore
    }
  }
}


