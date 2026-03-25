import 'dart:async';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';

class DbSyncService {
  DbSyncService._internal();
  static final DbSyncService _instance = DbSyncService._internal();
  factory DbSyncService() => _instance;

  Timer? _timer;
  DateTime? _last;

  void start({Duration interval = const Duration(minutes: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final ds = DataService();
      final DateTime now = DateTime.now();
      final DateTime from = _last ?? now.subtract(const Duration(minutes: 30));
      final pts = await ds.fetchGlucose(from: from, to: now, limit: 500);
      if (pts.isNotEmpty) {
        for (final m in pts) {
          final DateTime t = DateTime.parse((m['time'] as String)).toLocal();
          final double v = ((m['value'] as num?) ?? 0).toDouble();
          DataSyncBus().emitGlucosePoint(time: t, value: v);
        }
        final lastTime = DateTime.parse((pts.last['time'] as String)).toLocal();
        _last = lastTime;
      }
    } catch (_) {}
  }
}


