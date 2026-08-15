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
      // 서버 델타 커서는 **서버에서 받아 캐시한 행**의 최대 trid 여야 한다.
      // 기기 실측 trid(앱이 만든 카운터)를 커서로 쓰면 서버가 아직 모르는 번호를
      // 요청하게 되어 이후 델타가 영구히 비어 돌아온다.
      final int fromTrid = await repo.maxTrid(eqsn: eqsn, userId: userId, src: GlucoseSrc.server);
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
      // 서버 행은 어느 센서 것인지 응답에 없다. 현재 eqsn 으로 stamped 저장하면
      // 과거 센서의 trid 가 현재 센서 공간을 점거해 신규 판독을 전부 밀어낸다.
      // → 출처를 'srv' 로 표시해 워터마크·업로드 백로그 계산에서 배제한다.
      await repo.addPointsBatch(
        times: times,
        values: values,
        trids: trids,
        eqsn: eqsn,
        userId: userId,
        src: GlucoseSrc.server,
      );
      // 한 번만 브로드캐스트
      DataSyncBus().emitGlucoseBulk(count: values.length);
    } catch (_) {
      // ignore
    }
  }
}


