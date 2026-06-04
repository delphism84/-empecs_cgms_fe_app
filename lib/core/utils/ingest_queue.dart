import 'dart:async';
import 'dart:collection';

import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/sensor_warmup_service.dart';
import 'package:helpcare/core/utils/background_sync_gate.dart';
import 'package:helpcare/core/utils/api_sync_log.dart';

/// 로컬 SQLite 우선 → UI 즉시 반영 → trid 워터마크 기준 백그라운드 단건 POST.
class IngestQueueService {
  IngestQueueService._internal();
  static final IngestQueueService _instance = IngestQueueService._internal();
  factory IngestQueueService() => _instance;

  static const String _kLastServerUploadedTrid = 'lastServerUploadedTrid';

  final Queue<Map<String, dynamic>> _queue = Queue();
  bool _uploadRunning = false;
  bool _started = false;
  Timer? _retryTimer;

  static String? _cachedEqsn;
  static String? _lastUserIdCache;

  /// SettingsStorage eqsn/userId snapshot (main + login paths).
  static Future<void> warmCache() async {
    try {
      final s = await SettingsStorage.load();
      final String eq = (s['eqsn'] as String? ?? '').trim();
      _cachedEqsn = eq.isEmpty ? null : eq;
      final String uid = (s['lastUserId'] as String? ?? '').trim();
      _lastUserIdCache = uid.isEmpty ? null : uid;
    } catch (_) {}
  }

  /// 앱 기동 후: DB 미전송분 복구 + 주기적 재시도(실패분은 다음 차수에 누적).
  void startBackgroundUpload({Duration retryInterval = const Duration(minutes: 1)}) {
    if (_started) return;
    _started = true;
    unawaited(_rebuildQueueFromLocal());
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(retryInterval, (_) => kickUpload());
  }

  void kickUpload() {
    unawaited(_processUploadQueue());
  }

  void enqueueGlucose(DateTime time, num value, {int? trid, String? eqsn, String? userId, bool silent = false}) {
    unawaited(_enqueueGlucoseImpl(
      time: time,
      value: value,
      trid: trid,
      eqsn: eqsn,
      userId: userId,
      silent: silent,
    ));
  }

  Future<void> _enqueueGlucoseImpl({
    required DateTime time,
    required num value,
    int? trid,
    String? eqsn,
    String? userId,
    required bool silent,
  }) async {
    final String resolvedEqsn = (eqsn != null && eqsn.isNotEmpty) ? eqsn : _inferEqsn();
    final String? resolvedUser = (userId != null && userId.isNotEmpty) ? userId : _inferUserIdOrNull();

    await GlucoseLocalRepo().addPoint(
      time: time,
      value: value.toDouble(),
      trid: trid,
      eqsn: resolvedEqsn,
      userId: resolvedUser,
    );

    if (!silent) {
      DataSyncBus().emitGlucosePoint(time: time, value: value.toDouble());
      unawaited(_pushLockScreenBanner(time, value.toDouble()));
    }

    final int? tid = trid;
    if (tid != null && tid > 0) {
      final int lastUp = await _readLastServerUploadedTrid();
      if (tid <= lastUp) return;
      _offerQueueItem({
        'type': 'glucose',
        'time': time,
        'value': value,
        'trid': tid,
        'eqsn': resolvedEqsn,
        if (resolvedUser != null) 'userId': resolvedUser,
      });
    } else {
      _offerQueueItem({
        'type': 'glucose',
        'time': time,
        'value': value,
        'trid': tid,
        'eqsn': resolvedEqsn,
        if (resolvedUser != null) 'userId': resolvedUser,
      });
    }

    kickUpload();
  }

  void _offerQueueItem(Map<String, dynamic> item) {
    final int? tr = item['trid'] as int?;
    if (tr != null && tr > 0) {
      if (_queue.any((e) => (e['trid'] as int?) == tr)) return;
    } else {
      final DateTime t = item['time'] as DateTime;
      final double v = (item['value'] as num).toDouble();
      if (_queue.any((e) {
        return (e['time'] as DateTime) == t && ((e['value'] as num).toDouble() - v).abs() < 0.001;
      })) {
        return;
      }
    }
    _queue.add(item);
  }

  Future<void> _rebuildQueueFromLocal() async {
    try {
      final int after = await _readLastServerUploadedTrid();
      String? eqsn = _cachedEqsn;
      if (eqsn == null || eqsn.isEmpty) {
        final st = await SettingsStorage.load();
        final String q = (st['eqsn'] as String? ?? '').trim();
        eqsn = q.isEmpty ? null : q;
      }
      final rows = await GlucoseLocalRepo().rowsAfterTrid(afterTrid: after, limit: 500, eqsn: eqsn);
      for (final r in rows) {
        final int? tr = (r['trid'] as int?);
        final int ms = (r['time_ms'] as int?) ?? 0;
        if (tr == null || tr <= after) continue;
        _offerQueueItem({
          'type': 'glucose',
          'time': DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
          'value': (r['value'] as num?) ?? 0,
          'trid': tr,
          'eqsn': eqsn ?? _inferEqsn(),
        });
      }
    } catch (_) {}
  }

  Future<void> _processUploadQueue() async {
    if (_uploadRunning) return;
    if (BackgroundSyncGate.blocksHeavySync) {
      BackgroundSyncGate.runWhenUnblocked(_processUploadQueue, dedupeKey: 'ingestUpload');
      return;
    }
    if (_queue.isEmpty) {
      await _rebuildQueueFromLocal();
      if (_queue.isEmpty) return;
    }

    _uploadRunning = true;
    final DataService ds = DataService();
    try {
      while (_queue.isNotEmpty) {
        final Map<String, dynamic> item = _queue.first;
        final DateTime time = item['time'] as DateTime;
        final num value = item['value'] as num;
        final int? tr = item['trid'] as int?;

        if (tr != null && tr > 0) {
          final int lastUp = await _readLastServerUploadedTrid();
          if (tr <= lastUp) {
            _queue.removeFirst();
            continue;
          }
        }

        await BackgroundSyncGate.yieldToUi(milliseconds: 8);

        final Stopwatch sw = Stopwatch()..start();
        final bool ok = await ds.postGlucose(time: time, value: value, trid: tr);
        sw.stop();
        apiSyncLog('ingest glucose post trid=${tr ?? '—'} ok=$ok ${sw.elapsedMilliseconds}ms');

        if (!ok) break;

        if (tr != null && tr > 0) {
          await _markServerUploadedTrid(tr);
        }
        _queue.removeFirst();
      }
    } catch (_) {
      // 큐 유지 → 다음 kick/주기 타이머에서 재시도(2건 이상 누적 가능)
    } finally {
      _uploadRunning = false;
    }
  }

  static Future<int> readLastServerUploadedTrid() => _readLastServerUploadedTrid();

  static Future<void> markServerUploadedTrid(int trid) => _markServerUploadedTrid(trid);

  static Future<int> _readLastServerUploadedTrid() async {
    try {
      final st = await SettingsStorage.load();
      return ((st[_kLastServerUploadedTrid] as num?) ?? 0).toInt();
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _markServerUploadedTrid(int trid) async {
    if (trid <= 0) return;
    try {
      final st = await SettingsStorage.load();
      final int prev = ((st[_kLastServerUploadedTrid] as num?) ?? 0).toInt();
      if (trid > prev) {
        st[_kLastServerUploadedTrid] = trid;
        await SettingsStorage.save(st);
      }
    } catch (_) {}
  }

  void clear() {
    _queue.clear();
    unawaited(() async {
      try {
        final st = await SettingsStorage.load();
        st[_kLastServerUploadedTrid] = 0;
        await SettingsStorage.save(st);
      } catch (_) {}
    }());
  }

  Future<void> _pushLockScreenBanner(DateTime time, double value) async {
    if (SensorWarmupService.shouldSuppressAlarmPipeline) return;
    try {
      final st = await SettingsStorage.load();
      final String u = (st['glucoseUnit'] as String? ?? 'mgdl') == 'mmol' ? 'mmol/L' : 'mg/dL';
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
    final String? c = _cachedEqsn;
    if (c != null && c.isNotEmpty) return c;
    unawaited(warmCache());
    return 'LOCAL';
  }

  String? _inferUserIdOrNull() {
    final String? c = _lastUserIdCache;
    if (c != null && c.isNotEmpty) return c;
    unawaited(warmCache());
    return null;
  }
}
