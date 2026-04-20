import 'dart:async';
import 'dart:collection';
import 'package:helpcare/core/utils/api_client.dart';
// import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
// removed: settings storage import; notification gating moved to NotificationService
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/notification_service.dart';

class IngestQueueService {
  IngestQueueService._internal();
  static final IngestQueueService _instance = IngestQueueService._internal();
  factory IngestQueueService() => _instance;

  final Queue<Map<String, dynamic>> _queue = Queue();
  bool _syncing = false;

  void enqueueGlucose(DateTime time, num value, {int? trid, String? eqsn, String? userId, bool silent = false}) {
    // 로컬 캐시 우선: 저장 후 즉시 UI 브로드캐스트/알림, 서버 동기는 비동기 처리
    GlucoseLocalRepo().addPoint(time: time, value: value.toDouble(), trid: trid, eqsn: eqsn ?? _inferEqsn(), userId: userId ?? _inferUserId());
    if (!silent) {
      DataSyncBus().emitGlucosePoint(time: time, value: value.toDouble());
      unawaited(_pushLockScreenBanner(time, value.toDouble()));
    }
    _queue.add({'type': 'glucose', 'time': time, 'value': value, if (trid != null) 'trid': trid, 'eqsn': eqsn ?? _inferEqsn(), 'userId': userId ?? _inferUserId()});
    _drain();
  }

  Future<void> _drain() async {
    if (_syncing) return;
    _syncing = true;
    final ds = DataService();
    try {
      while (_queue.isNotEmpty) {
        // 배치 구성 (최대 500개)
        final List<Map<String, dynamic>> batch = <Map<String, dynamic>>[];
        for (final it in _queue) {
          if (batch.length >= 500) break;
          if (it['type'] == 'glucose') batch.add(it);
        }
        if (batch.isEmpty) {
          // non-glucose 항목 제거
          _queue.removeWhere((e) => e['type'] != 'glucose');
          break;
        }
        final List<int> t = batch.map((e) => (e['time'] as DateTime).toUtc().millisecondsSinceEpoch).toList();
        final List<num> v = batch.map((e) => (e['value'] as num)).toList();
        final List<int?> tr = batch.map((e) => (e['trid'] as int?)).toList();
        final bool ok = await ds.postGlucoseBatch(t: t, v: v, tr: tr);
        if (!ok) break;
        // 성공 시 배치 수만큼 제거
        int removed = 0;
        while (removed < batch.length && _queue.isNotEmpty) {
          _queue.removeFirst();
          removed++;
        }
        // 업로드 성공 후에는 별도의 재브로드캐스트 불필요 (이미 enqueue 시 반영)
      }
    } catch (_) {
      // keep remaining items for retry
    } finally {
      _syncing = false;
    }
  }

  // optional: alerts are now handled by the UI layer or separate service when data sync bus fires

  void clear() {
    _queue.clear();
  }

  Future<void> _pushLockScreenBanner(DateTime time, double value) async {
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl') == 'mmol' ? 'mmol/L' : 'mg/dL';
      // eqsn 컬럼이 LOCAL/실SN 혼재될 수 있어, 추세는 사용자 단위 최근 2포인트로 통일
      final String trend = await GlucoseLocalRepo().lockScreenTrendArrow(eqsn: null);
      await NotificationService().showLockScreenGlucose(
        value: value,
        trend: trend,
        unit: u,
        measuredAt: time,
      );
    } catch (_) {}
  }

  String _inferEqsn() {
    // try registered device id/mac from settings; fallback to LOCAL
    try {
      // synchronous guess: not reading prefs here; keep simple
      return 'LOCAL';
    } catch (_) {
      return 'LOCAL';
    }
  }

  String _inferUserId() {
    try {
      // 로컬 캐시 우선, 없으면 SettingsStorage에서 로드하여 캐시한다.
      final cached = _lastUserIdCache;
      if (cached != null && cached.isNotEmpty) return cached;
      // 비동기 로드가 필요하지만, enqueue 경로에서 await를 피하기 위해 fire-and-forget으로 갱신한다.
      () async {
        try {
          final s = await SettingsStorage.load();
          final String uid = (s['lastUserId'] as String? ?? '').trim();
          if (uid.isNotEmpty) _lastUserIdCache = uid;
        } catch (_) {}
      }();
      return 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  static String? _lastUserIdCache;
}


