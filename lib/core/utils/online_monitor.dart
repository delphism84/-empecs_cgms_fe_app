import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';

class OnlineMonitor {
  OnlineMonitor._internal();
  static final OnlineMonitor _instance = OnlineMonitor._internal();
  factory OnlineMonitor() => _instance;

  Timer? _timer;
  bool _prevOnline = false;
  bool _tickRunning = false;

  /// 동기화 작업 직렬화(온라인 전환·백그라운드 이어하기 동시 진입 방지)
  Future<void> _backlogChain = Future<void>.value();

  static const Duration _uiSyncBudget = Duration(seconds: 12);

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
        final r = await api.get('/api/settings/app', withGlobalLoading: false);
        online = (r.statusCode == 200);
      } catch (_) {
        online = false;
      }
      try {
        final s = await SettingsStorage.load();
        s['offlineMode'] = !online;
        await SettingsStorage.save(s);
      } catch (_) {}

      if (online && !_prevOnline) {
        unawaited(_onBecameOnline());
      }
      _prevOnline = online;
    } finally {
      _tickRunning = false;
    }
  }

  /// 오프라인→온라인 직후: 짧은 시간만 블로킹 다이얼로그, 남은 백로그는 백그라운드에서 이어감.
  Future<void> _onBecameOnline() async {
    final BuildContext? ctx0 = AppNav.navigatorKey.currentContext;
    var shown = false;
    NavigatorState? dialogNav;
    if (ctx0 != null && ctx0.mounted) {
      try {
        dialogNav = Navigator.of(ctx0, rootNavigator: true);
        showDialog<void>(
          context: ctx0,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text('online_sync_title'.tr())),
              ],
            ),
          ),
        );
        shown = true;
      } catch (_) {
        dialogNav = null;
      }
    }
    final DateTime uiDeadline = DateTime.now().add(_uiSyncBudget);
    late final ({bool complete, bool failed}) outcome;
    try {
      outcome = await _enqueueBacklog(deadline: uiDeadline);
    } catch (_) {
      outcome = (complete: false, failed: true);
    } finally {
      if (shown) {
        try {
          dialogNav?.pop();
        } catch (_) {
          final NavigatorState? nav = AppNav.navigatorKey.currentState;
          if (nav != null && nav.canPop()) nav.pop();
        }
      }
    }
    if (!outcome.complete && !outcome.failed) {
      unawaited(_enqueueBacklog(deadline: null).then((r) {
        if (!r.complete && r.failed) {
          final BuildContext? c = AppNav.navigatorKey.currentContext;
          if (c != null && c.mounted) {
            ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('online_sync_failed'.tr())));
          }
        }
      }));
    }
    final BuildContext? ctx2 = AppNav.navigatorKey.currentContext;
    if (ctx2 != null && ctx2.mounted && outcome.failed) {
      ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('online_sync_failed'.tr())));
    }
  }

  /// [deadline]이 지나면 체크포인트만 저장하고 중단한다. complete=false·failed=false면 이어하기 필요.
  Future<({bool complete, bool failed})> _enqueueBacklog({DateTime? deadline}) {
    final Future<({bool complete, bool failed})> next =
        _backlogChain.then((_) => _pushBacklog(deadline: deadline));
    _backlogChain = next.then((_) {}).catchError((_) {});
    return next;
  }

  /// Returns complete=true when glucose·이벤트·삭제 outbox까지 모두 처리됨. failed=true면 API 실패.
  Future<({bool complete, bool failed})> _pushBacklog({DateTime? deadline}) async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '');
      final String userId = (st['lastUserId'] as String? ?? '');
      final DateTime now = DateTime.now();
      var pending = st['offlineUploadPending'] == true;
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
        await Future<void>.delayed(Duration.zero);
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

      while (true) {
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
          if (_pastDeadline(deadline)) {
            abortedByDeadline = true;
            glucoseAllOk = false;
            break;
          }
          final int end = math.min(i + 500, gRows.length);
          final List<int> t = [];
          final List<num> v = [];
          final List<int?> tr = [];
          for (int j = i; j < end; j++) {
            t.add((gRows[j]['time_ms'] as num).toInt());
            v.add(((gRows[j]['value'] as num?) ?? 0));
            tr.add((gRows[j]['trid'] as num?)?.toInt());
          }
          final bool batchOk = await ds.postGlucoseBatch(t: t, v: v, tr: tr);
          if (!batchOk) {
            glucoseAllOk = false;
            break;
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
        await markPendingIfChunked();
        try {
          DataSyncBus().emitGlucoseBulk(count: 0);
        } catch (_) {}
        return (complete: false, failed: false);
      }

      final repoE = EventLocalRepo();
      DateTime eCursor = fromE;
      const int eChunkLimit = 400;
      int idx = 0;
      DateTime? lastUploadedEventAt;

      while (true) {
        if (_pastDeadline(deadline)) {
          abortedByDeadline = true;
          eventsAllOk = false;
          break;
        }
        await yieldUi();
        final List<Map<String, dynamic>> eRows =
            await repoE.range(from: eCursor, to: now, limit: eChunkLimit, eqsn: eqsn, userId: userId);
        if (eRows.isEmpty) break;

        for (final m in eRows) {
          if (_pastDeadline(deadline)) {
            abortedByDeadline = true;
            eventsAllOk = false;
            break;
          }
          final String type = (m['type'] as String?) ?? 'memo';
          final DateTime tm = DateTime.fromMillisecondsSinceEpoch((m['time_ms'] as num).toInt()).toLocal();
          final String? memo = (m['memo'] as String?);
          try {
            final bool postOk = await ds.postEvent(type: type, time: tm, memo: memo);
            if (!postOk) {
              eventsAllOk = false;
              break;
            }
            idx++;
            lastUploadedEventAt = tm;
            if (idx % 25 == 0) {
              st['offlineUploadFromEvents'] = tm.toUtc().toIso8601String();
              await SettingsStorage.save(st);
            }
            if (idx % 10 == 0) await yieldUi();
          } catch (_) {
            eventsAllOk = false;
            break;
          }
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
        await markPendingIfChunked();
        try {
          DataSyncBus().emitGlucoseBulk(count: 0);
        } catch (_) {}
        return (complete: false, failed: false);
      }

      try {
        final List<dynamic> box = (st['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        if (box.isNotEmpty) {
          final List<String> remain = <String>[];
          int delIdx = 0;
          for (final e in box) {
            if (_pastDeadline(deadline)) {
              abortedByDeadline = true;
              deletesOk = false;
              break;
            }
            final String id = e.toString();
            var delOk = false;
            try {
              delOk = await ds.deleteEvent(id);
            } catch (_) {
              delOk = false;
            }
            if (!delOk) {
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
        await markPendingIfChunked();
        try {
          DataSyncBus().emitGlucoseBulk(count: 0);
        } catch (_) {}
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

      try {
        DataSyncBus().emitGlucoseBulk(count: 0);
      } catch (_) {}
      final bool complete = glucoseAllOk && eventsAllOk && deletesOk;
      return (complete: complete, failed: !complete);
    } catch (_) {
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
