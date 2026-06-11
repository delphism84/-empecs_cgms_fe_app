import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/sensor_usage.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/background_sync_gate.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _onlineSyncLog(String message) {
  final String line = '[OnlineSync] $message';
  developer.log(line, name: 'OnlineSync');
  debugPrint(line);
}

class OnlineMonitor {
  OnlineMonitor._internal();
  static final OnlineMonitor _instance = OnlineMonitor._internal();
  factory OnlineMonitor() => _instance;

  Timer? _timer;
  bool _prevOnline = false;
  bool _tickRunning = false;

  /// 동기화 작업 직렬화(온라인 전환·백그라운드 이어하기 동시 진입 방지)
  Future<void> _backlogChain = Future<void>.value();

  /// 증가 시 진행 중 [_pushBacklog] 루프가 즉시 중단(타임아웃·새 세션)
  int _backlogRunId = 0;

  bool _onlineSyncInFlight = false;

  /// 웜업 중 오프라인→온라인 전환 시 백로그를 한 번 미룬다.
  bool _deferredOnlineBacklog = false;

  /// 백그라운드 백로그 1회 시도 예산 — 초과·실패 시 이어하기 없이 skip
  static const Duration _backgroundSyncBudget = Duration(seconds: 5);

  /// 웜업 종료·홈 진입 후: 온라인이면 백로그를 UI 블로킹 없이 재시도.
  void schedulePostWarmupSync() {
    BackgroundSyncGate.runWhenUnblocked(() async {
      await BackgroundSyncGate.yieldToUi(milliseconds: 500);
      await kickDeferredOnlineSync();
    }, dedupeKey: 'onlinePostWarmup');
  }

  /// 웜업으로 미뤄 둔 동기화 또는 즉시 1회 백로그(사용자 주도, 예산 확대).
  Future<void> kickDeferredOnlineSync() async {
    if (BackgroundSyncGate.blocksHeavySync) {
      _deferredOnlineBacklog = true;
      return;
    }
    bool online = false;
    try {
      final api = ApiClient();
      await api.loadToken();
      final r = await api.get('/api/settings/app', withGlobalLoading: false);
      online = (r.statusCode == 200);
    } catch (_) {
      online = false;
    }
    if (!online) return;
    _deferredOnlineBacklog = false;
    _prevOnline = true;
    await _onBecameOnline(budget: const Duration(seconds: 12));
  }

  static bool _pastDeadline(DateTime? deadline) =>
      deadline != null && !DateTime.now().isBefore(deadline);

  void start({Duration interval = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_tickRunning) return;
    _tickRunning = true;
    try {
      bool online = false;
      try {
        final api = ApiClient();
        await api.loadToken();
        _onlineSyncLog('GET /api/settings/app … (timeout=${api.timeout.inMilliseconds}ms)');
        final r = await api.get('/api/settings/app', withGlobalLoading: false);
        online = (r.statusCode == 200);
        _onlineSyncLog('GET /api/settings/app → ${r.statusCode} online=$online');
      } catch (e, st) {
        online = false;
        _onlineSyncLog('GET /api/settings/app FAILED: $e\n$st');
      }
      try {
        final s = await SettingsStorage.load();
        s['offlineMode'] = !online;
        await SettingsStorage.save(s);
      } catch (_) {}

      if (online && !_prevOnline) {
        if (BackgroundSyncGate.blocksHeavySync) {
          _deferredOnlineBacklog = true;
          _onlineSyncLog('offline→online: deferred (warmup active)');
        } else {
          _onlineSyncLog('offline→online: background backlog (no dialog)');
          unawaited(_onBecameOnline());
        }
      }
      if (!online) {
        _deferredOnlineBacklog = false;
      }
      _prevOnline = online;
      if (online && _deferredOnlineBacklog && !BackgroundSyncGate.blocksHeavySync) {
        _deferredOnlineBacklog = false;
        _onlineSyncLog('warmup ended: flushing deferred backlog');
        unawaited(_onBecameOnline());
      }
    } finally {
      _tickRunning = false;
    }
  }

  void _abortActiveBacklog() {
    _backlogRunId++;
    _onlineSyncLog('backlog aborted (runId=$_backlogRunId)');
  }

  /// 서버 1회 POST 실패 시 1회만 재시도, 이후 false.
  Future<bool> _postOnceWithRetry(Future<bool> Function() post, {required bool Function() aborted}) async {
    if (aborted()) return false;
    try {
      if (await post()) return true;
    } catch (_) {}
    if (aborted()) return false;
    try {
      return await post();
    } catch (_) {
      return false;
    }
  }

  /// 오프라인→온라인 직후: UI 없이 백그라운드만. 예산 초과·서버 실패 시 skip(재시도·스낵바 없음).
  Future<void> _onBecameOnline({Duration? budget}) async {
    if (BackgroundSyncGate.blocksHeavySync) {
      _deferredOnlineBacklog = true;
      _onlineSyncLog('_onBecameOnline deferred (warmup)');
      return;
    }
    if (_onlineSyncInFlight) {
      _onlineSyncLog('_onBecameOnline skipped (already in flight)');
      return;
    }
    _onlineSyncInFlight = true;
    final Duration syncBudget = budget ?? _backgroundSyncBudget;
    try {
      _onlineSyncLog('_onBecameOnline background budget=${syncBudget.inSeconds}s');
      try {
        await SensorUsage.applyServerStartOverwrite().timeout(
          syncBudget,
          onTimeout: () {
            _onlineSyncLog('applyServerStartOverwrite timeout → skip backlog');
            return false;
          },
        );
      } catch (e, st) {
        _onlineSyncLog('applyServerStartOverwrite error (skip backlog): $e\n$st');
        return;
      }

      final int runId = _backlogRunId + 1;
      _backlogRunId = runId;
      final DateTime deadline = DateTime.now().add(syncBudget);
      final ({bool complete, bool failed}) outcome = await _enqueueBacklog(deadline: deadline, runId: runId).timeout(
        syncBudget,
        onTimeout: () {
          _abortActiveBacklog();
          _onlineSyncLog('backlog enqueue timeout → skip');
          return (complete: false, failed: true);
        },
      );
      if (outcome.complete) {
        _onlineSyncLog('background backlog complete');
      } else {
        _onlineSyncLog(
          'background backlog skipped complete=${outcome.complete} failed=${outcome.failed}',
        );
      }
    } catch (e, st) {
      _onlineSyncLog('background backlog EXCEPTION (skipped): $e\n$st');
    } finally {
      _onlineSyncInFlight = false;
    }
  }

  /// [deadline]이 지나면 체크포인트만 저장하고 중단한다. complete=false·failed=false면 이어하기 필요.
  Future<({bool complete, bool failed})> _enqueueBacklog({DateTime? deadline, required int runId}) {
    final Future<({bool complete, bool failed})> next =
        _backlogChain.then((_) => _pushBacklog(deadline: deadline, runId: runId));
    _backlogChain = next.then((_) {}).catchError((_) {});
    return next;
  }

  /// Returns complete=true when glucose·이벤트·삭제 outbox까지 모두 처리됨. failed=true면 API 실패.
  Future<({bool complete, bool failed})> _pushBacklog({DateTime? deadline, required int runId}) async {
    bool aborted() => runId != _backlogRunId;
    _onlineSyncLog(
      '_pushBacklog start runId=$runId deadline=${deadline?.toIso8601String() ?? 'none'}',
    );
    if (aborted()) {
      return (complete: false, failed: true);
    }
    try {
      final st = await SettingsStorage.load();
      String eqsn = (st['eqsn'] as String? ?? '').trim();
      final String userId = (st['lastUserId'] as String? ?? '');
      final DateTime now = DateTime.now();
      var pending = st['offlineUploadPending'] == true;

      // eqsn 없으면 postGlucoseBatch가 서버 호출 전 차단됨 — BLE MAC resolve로 보강
      if (eqsn.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final String? mac = prefs.getString('cgms.last_mac');
          if (mac != null && mac.trim().isNotEmpty) {
            final Map<String, dynamic> eq =
                await SettingsService().resolveEqRegistration(bleMac: mac.trim());
            final String sn = (eq['serial'] as String? ?? '').trim();
            if (sn.isNotEmpty) {
              st['eqsn'] = sn;
              await SettingsStorage.save(st);
              eqsn = sn;
              _onlineSyncLog('eqsn hydrated via resolve bleMac=$mac → $eqsn');
            }
          }
        } catch (e) {
          _onlineSyncLog('eqsn hydrate failed: $e');
        }
      }
      final String startAt = (st['sensorStartAt'] as String? ?? '').trim();
      if (eqsn.isNotEmpty && startAt.isEmpty) {
        try {
          await SensorUsage.syncStartAtWithServer();
          final st2 = await SettingsStorage.load();
          st['sensorStartAt'] = st2['sensorStartAt'];
          st['sensorStartAtEqsn'] = st2['sensorStartAtEqsn'];
        } catch (e) {
          _onlineSyncLog('sensorStartAt sync failed: $e');
        }
      }

      _onlineSyncLog(
        'eqsn=$eqsn startAt=${(st['sensorStartAt'] as String? ?? '').trim().isEmpty ? "—" : "set"} '
        'userIdLen=${userId.length} pending=$pending',
      );
      final DateTime fromG = _parseIsoOrDefault(
        pending ? (st['offlineUploadFromGlucose'] as String?) : (st['lastPushAtGlucose'] as String?),
        now.subtract(const Duration(hours: 2)),
      );
      final DateTime fromE = _parseIsoOrDefault(
        pending ? (st['offlineUploadFromEvents'] as String?) : (st['lastPushAtEvents'] as String?),
        now.subtract(const Duration(hours: 2)),
      );
      var glucoseAllOk = true;
      var eventsAllOk = true;
      var deletesOk = true;
      var abortedByDeadline = false;
      int batchIndex = 0;

      Future<void> yieldUi() async {
        await BackgroundSyncGate.yieldToUi();
      }

      Future<void> markPendingIfChunked() async {
        if (abortedByDeadline) {
          st['offlineUploadPending'] = true;
          await SettingsStorage.save(st);
          pending = true;
        }
      }

      final repoG = GlucoseLocalRepo();
      final ds = DataService();
      DateTime gCursor = fromG;
      const int gChunkLimit = 2500;
      const int flushEvery = 8;
      int flushCounter = 0;
      int lastUploadedMs = 0;

      final String uploadStartAt = (st['sensorStartAt'] as String? ?? '').trim();
      final bool skipGlucoseUpload = eqsn.isEmpty || uploadStartAt.isEmpty;
      if (skipGlucoseUpload) {
        _onlineSyncLog(
          'glucose upload skipped (preflight): eqsnEmpty=${eqsn.isEmpty} startAtEmpty=${uploadStartAt.isEmpty}',
        );
      }

      while (!skipGlucoseUpload) {
        if (aborted()) {
          _onlineSyncLog('glucose: aborted (superseded run)');
          glucoseAllOk = false;
          break;
        }
        if (_pastDeadline(deadline)) {
          abortedByDeadline = true;
          glucoseAllOk = false;
          break;
        }
        await yieldUi();
        final List<Map<String, dynamic>> gRows =
            await repoG.range(from: gCursor, to: now, limit: gChunkLimit, eqsn: eqsn, userId: userId);
        if (gRows.isEmpty) break;

        int i = 0;
        while (i < gRows.length) {
          if (aborted()) {
            _onlineSyncLog('glucose: aborted (superseded run, in batch)');
            glucoseAllOk = false;
            break;
          }
          if (_pastDeadline(deadline)) {
            abortedByDeadline = true;
            glucoseAllOk = false;
            _onlineSyncLog('glucose: aborted by deadline (before batch)');
            break;
          }
          final int end = math.min(i + 500, gRows.length);
          final int lastTrUp = await IngestQueueService.readLastServerUploadedTrid();
          final List<int> t = [];
          final List<num> v = [];
          final List<int?> tr = [];
          for (int j = i; j < end; j++) {
            final int? rowTr = (gRows[j]['trid'] as num?)?.toInt();
            if (rowTr != null && rowTr > 0 && rowTr <= lastTrUp) continue;
            t.add((gRows[j]['time_ms'] as num).toInt());
            v.add(((gRows[j]['value'] as num?) ?? 0));
            tr.add(rowTr);
          }
          if (t.isEmpty) {
            i = end;
            continue;
          }
          _onlineSyncLog('glucose batch POST n=${t.length} (batchIndex=$batchIndex)');
          Future<bool> postOnce() async {
            final r = await ds.postGlucoseBatchResult(t: t, v: v, tr: tr);
            if (!r.ok) {
              _onlineSyncLog(
                'glucose batch fail reason=${r.reason} status=${r.statusCode ?? "—"}',
              );
            }
            return r.ok;
          }
          final bool batchOk = await _postOnceWithRetry(postOnce, aborted: aborted);
          if (!batchOk) {
            glucoseAllOk = false;
            _onlineSyncLog('glucose batch POST failed after retry → close');
            break;
          }
          int maxTr = lastTrUp;
          for (final int? tid in tr) {
            if (tid != null && tid > maxTr) maxTr = tid;
          }
          if (maxTr > lastTrUp) {
            await IngestQueueService.markServerUploadedTrid(maxTr);
          }
          final int lastMs = t.isNotEmpty ? t.last : 0;
          if (lastMs > 0) {
            lastUploadedMs = lastMs;
            flushCounter++;
            if (flushCounter >= flushEvery) {
              st['offlineUploadFromGlucose'] =
                  DateTime.fromMillisecondsSinceEpoch(lastUploadedMs, isUtc: true).toIso8601String();
              await SettingsStorage.save(st);
              flushCounter = 0;
            }
          }
          i = end;
          batchIndex++;
          if (batchIndex % 2 == 0) await yieldUi();
        }

        if (!glucoseAllOk || abortedByDeadline) break;

        final int chunkLastMs = (gRows.last['time_ms'] as num).toInt();
        gCursor = DateTime.fromMillisecondsSinceEpoch(chunkLastMs + 1);
        if (gRows.length < gChunkLimit) break;
      }

      if (lastUploadedMs > 0 && (!glucoseAllOk || abortedByDeadline)) {
        st['offlineUploadFromGlucose'] =
            DateTime.fromMillisecondsSinceEpoch(lastUploadedMs, isUtc: true).toIso8601String();
        await SettingsStorage.save(st);
      }
      if (glucoseAllOk && !abortedByDeadline && lastUploadedMs > 0) {
        st['lastPushAtGlucose'] = now.toUtc().toIso8601String();
        st['offlineUploadFromGlucose'] = now.toUtc().toIso8601String();
        await SettingsStorage.save(st);
      }

      if (abortedByDeadline) {
        _onlineSyncLog('return partial (glucose phase): deadline, pending flagged');
        await markPendingIfChunked();
        return (complete: false, failed: false);
      }

      final repoE = EventLocalRepo();
      DateTime eCursor = fromE;
      const int eChunkLimit = 400;
      int idx = 0;
      DateTime? lastUploadedEventAt;

      while (true) {
        if (aborted()) {
          _onlineSyncLog('events: aborted (superseded run)');
          eventsAllOk = false;
          break;
        }
        if (_pastDeadline(deadline)) {
          abortedByDeadline = true;
          eventsAllOk = false;
          break;
        }
        await yieldUi();
        final List<Map<String, dynamic>> eRows =
            await repoE.range(from: eCursor, to: now, limit: eChunkLimit, eqsn: eqsn, userId: userId);
        if (eRows.isEmpty) break;

        /// BE `POST /api/data/events/batch` 최대 200건; 실패 시 1회 재시도 후 중단(단건 폴백 없음).
        const int kEventBatchMax = 200;
        int rowPos = 0;
        while (rowPos < eRows.length) {
          if (aborted()) {
            _onlineSyncLog('events: aborted (superseded run, in batch)');
            eventsAllOk = false;
            break;
          }
          if (_pastDeadline(deadline)) {
            abortedByDeadline = true;
            eventsAllOk = false;
            _onlineSyncLog('events: aborted by deadline (before batch)');
            break;
          }
          final int batchEnd = math.min(rowPos + kEventBatchMax, eRows.length);
          final List<Map<String, dynamic>> slice = eRows.sublist(rowPos, batchEnd);
          final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
          for (final Map<String, dynamic> m in slice) {
            final String type = (m['type'] as String?) ?? 'memo';
            final DateTime tm =
                DateTime.fromMillisecondsSinceEpoch((m['time_ms'] as num).toInt()).toLocal();
            final String? memo = m['memo'] as String?;
            final Map<String, dynamic> one = <String, dynamic>{
              'type': type,
              'time': tm.toUtc().toIso8601String(),
            };
            if (memo != null && memo.isNotEmpty) {
              one['memo'] = memo;
            }
            payload.add(one);
          }
          if (idx == 0) {
            _onlineSyncLog('events upload: try batch n=${payload.length}');
          }
          final bool batchOk = await _postOnceWithRetry(
            () => ds.postEventsBatch(events: payload),
            aborted: aborted,
          );
          if (!batchOk) {
            eventsAllOk = false;
            _onlineSyncLog('events batch POST failed after retry → close');
            break;
          }
          for (final Map<String, dynamic> m in slice) {
            idx++;
            final DateTime tm =
                DateTime.fromMillisecondsSinceEpoch((m['time_ms'] as num).toInt()).toLocal();
            lastUploadedEventAt = tm;
            if (idx % 25 == 0) {
              st['offlineUploadFromEvents'] = tm.toUtc().toIso8601String();
              await SettingsStorage.save(st);
            }
            if (idx % 10 == 0) await yieldUi();
          }
          rowPos = batchEnd;
        }

        if (!eventsAllOk || abortedByDeadline) break;

        final int eLastMs = (eRows.last['time_ms'] as num).toInt();
        eCursor = DateTime.fromMillisecondsSinceEpoch(eLastMs + 1);
        if (eRows.length < eChunkLimit) break;
      }

      if (lastUploadedEventAt != null && (!eventsAllOk || abortedByDeadline)) {
        st['offlineUploadFromEvents'] = lastUploadedEventAt.toUtc().toIso8601String();
        await SettingsStorage.save(st);
      }
      if (eventsAllOk && !abortedByDeadline && idx > 0) {
        st['lastPushAtEvents'] = now.toUtc().toIso8601String();
        st['offlineUploadFromEvents'] = now.toUtc().toIso8601String();
        await SettingsStorage.save(st);
      }

      if (abortedByDeadline) {
        _onlineSyncLog('return partial (events phase): deadline, pending flagged');
        await markPendingIfChunked();
        return (complete: false, failed: false);
      }

      try {
        final List<dynamic> box = (st['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        if (box.isNotEmpty) {
          _onlineSyncLog('delete outbox size=${box.length}');
          final List<String> remain = <String>[];
          int delIdx = 0;
          for (final e in box) {
            if (aborted()) {
              deletesOk = false;
              _onlineSyncLog('delete outbox: aborted (superseded run)');
              break;
            }
            if (_pastDeadline(deadline)) {
              abortedByDeadline = true;
              deletesOk = false;
              _onlineSyncLog('delete outbox: aborted by deadline');
              break;
            }
            final String id = e.toString();
            var delOk = false;
            try {
              delOk = await _postOnceWithRetry(() => ds.deleteEvent(id), aborted: aborted);
            } catch (_) {
              delOk = false;
            }
            if (!delOk) {
              _onlineSyncLog('deleteEvent failed id=$id');
              remain.add(id);
            }
            delIdx++;
            if (delIdx % 15 == 0) await yieldUi();
          }
          st['eventDeleteOutbox'] = remain;
          await SettingsStorage.save(st);
          if (remain.isNotEmpty && !abortedByDeadline) {
            deletesOk = false;
          }
        }
      } catch (_) {
        deletesOk = false;
      }

      if (abortedByDeadline) {
        _onlineSyncLog('return partial (delete phase): deadline, pending flagged');
        await markPendingIfChunked();
        return (complete: false, failed: false);
      }

      if (pending && glucoseAllOk && eventsAllOk) {
        final List<dynamic> remain = (st['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        if (remain.isEmpty) {
          st['offlineUploadPending'] = false;
          await SettingsStorage.save(st);
        } else {
          deletesOk = false;
        }
      }

      // count:0은 SN/DB 초기화 전용. 동기화 완료는 로컬 재로드만 알린다.
      try {
        DataSyncBus().emitGlucoseBulk(count: 1);
      } catch (_) {}
      final bool complete = glucoseAllOk && eventsAllOk && deletesOk;
      _onlineSyncLog(
        '_pushBacklog end glucoseOk=$glucoseAllOk eventsOk=$eventsAllOk deletesOk=$deletesOk → complete=$complete',
      );
      return (complete: complete, failed: !complete);
    } catch (e, st) {
      _onlineSyncLog('_pushBacklog EXCEPTION: $e\n$st');
      return (complete: false, failed: true);
    }
  }

  DateTime _parseIsoOrDefault(String? iso, DateTime dflt) {
    if (iso == null || iso.isEmpty) {
      return dflt;
    }
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return dflt;
    }
  }
}
