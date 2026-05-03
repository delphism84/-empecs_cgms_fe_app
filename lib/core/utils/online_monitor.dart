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

  /// 오프라인→온라인 직후: 업로드 백로그를 끝낼 때까지 동기 표시(닫기는 finally에서 보장) 후, 실패 시에만 스낵바.
  Future<void> _onBecameOnline() async {
    final BuildContext? ctx0 = AppNav.navigatorKey.currentContext;
    var shown = false;
    if (ctx0 != null && ctx0.mounted) {
      try {
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
      } catch (_) {}
    }
    var ok = false;
    try {
      ok = await _pushBacklog();
    } catch (_) {
      ok = false;
    } finally {
      if (shown) {
        final NavigatorState? nav = AppNav.navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      }
    }
    final BuildContext? ctx2 = AppNav.navigatorKey.currentContext;
    if (ctx2 != null && ctx2.mounted && !ok) {
      ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('online_sync_failed'.tr())));
    }
  }

  /// Returns true if glucose/events pushes and delete outbox had no failures (or nothing to do).
  Future<bool> _pushBacklog() async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '');
      final String userId = (st['lastUserId'] as String? ?? '');
      final DateTime now = DateTime.now();
      final bool pending = st['offlineUploadPending'] == true;
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

      final repoG = GlucoseLocalRepo();
      final List<Map<String, dynamic>> gRows = await repoG.range(from: fromG, to: now, limit: 50000, eqsn: eqsn, userId: userId);
      if (gRows.isNotEmpty) {
        final ds = DataService();
        int i = 0;
        while (i < gRows.length) {
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
            st['offlineUploadFromGlucose'] = DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true).toIso8601String();
            await SettingsStorage.save(st);
          }
          i = end;
        }
        if (glucoseAllOk) {
          st['lastPushAtGlucose'] = now.toUtc().toIso8601String();
          st['offlineUploadFromGlucose'] = now.toUtc().toIso8601String();
          await SettingsStorage.save(st);
        }
      }

      final repoE = EventLocalRepo();
      final List<Map<String, dynamic>> eRows = await repoE.range(from: fromE, to: now, limit: 10000, eqsn: eqsn, userId: userId);
      if (eRows.isNotEmpty) {
        final ds = DataService();
        for (final m in eRows) {
          final String type = (m['type'] as String?) ?? 'memo';
          final DateTime tm = DateTime.fromMillisecondsSinceEpoch((m['time_ms'] as num).toInt()).toLocal();
          final String? memo = (m['memo'] as String?);
          try {
            final bool postOk = await ds.postEvent(type: type, time: tm, memo: memo);
            if (!postOk) {
              eventsAllOk = false;
              break;
            }
            st['offlineUploadFromEvents'] = tm.toUtc().toIso8601String();
            await SettingsStorage.save(st);
          } catch (_) {
            eventsAllOk = false;
            break;
          }
        }
        if (eventsAllOk) {
          st['lastPushAtEvents'] = now.toUtc().toIso8601String();
          st['offlineUploadFromEvents'] = now.toUtc().toIso8601String();
          await SettingsStorage.save(st);
        }
      }

      try {
        final List<dynamic> box = (st['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        if (box.isNotEmpty) {
          final ds = DataService();
          final List<String> remain = <String>[];
          for (final e in box) {
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
          }
          st['eventDeleteOutbox'] = remain;
          await SettingsStorage.save(st);
          if (remain.isNotEmpty) {
            deletesOk = false;
          }
        }
      } catch (_) {
        deletesOk = false;
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
      return glucoseAllOk && eventsAllOk && deletesOk;
    } catch (_) {
      return false;
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
