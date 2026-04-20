import 'dart:async';
import 'dart:math' as math;
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
    bool online = false;
    try {
      final api = ApiClient();
      await api.loadToken();
      final r = await api.get('/api/settings/app');
      online = (r.statusCode == 200);
    } catch (_) {
      online = false;
    }
    try {
      final s = await SettingsStorage.load();
      s['offlineMode'] = !online;
      // keep eventsSync off by default; only SN change will perform pulls
      await SettingsStorage.save(s);
    } catch (_) {}

    if (online && !_prevOnline) {
      unawaited(_pushBacklog());
      unawaited(_showPostOnlineSyncUi());
    }
    _prevOnline = online;
  }

  /// req 2-1: 온라인 전환 직후 로컬→서버 동기화 UX — 애니메이션 후 업로드 동기화 실패 표시(현행 스텁).
  Future<void> _showPostOnlineSyncUi() async {
    final BuildContext? ctx = AppNav.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    try {
      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dCtx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Syncing with server...')),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      final NavigatorState? nav = AppNav.navigatorKey.currentState;
      if (nav != null && nav.canPop()) nav.pop();
      final BuildContext? ctx2 = AppNav.navigatorKey.currentContext;
      if (ctx2 != null && ctx2.mounted) {
        ScaffoldMessenger.of(ctx2).showSnackBar(
          const SnackBar(content: Text('Upload sync failed')),
        );
      }
    } catch (_) {}
  }

  Future<void> _pushBacklog() async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '');
      final String userId = (st['lastUserId'] as String? ?? '');
      final DateTime now = DateTime.now();
      DateTime fromG = _parseIsoOrDefault(st['lastPushAtGlucose'] as String?, now.subtract(const Duration(hours: 2)));
      DateTime fromE = _parseIsoOrDefault(st['lastPushAtEvents'] as String?, now.subtract(const Duration(hours: 2)));

      // push glucose in chunks
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
          await ds.postGlucoseBatch(t: t, v: v, tr: tr);
          i = end;
        }
        st['lastPushAtGlucose'] = now.toUtc().toIso8601String();
        await SettingsStorage.save(st);
      }

      // push events individually
      final repoE = EventLocalRepo();
      final List<Map<String, dynamic>> eRows = await repoE.range(from: fromE, to: now, limit: 10000, eqsn: eqsn, userId: userId);
      if (eRows.isNotEmpty) {
        final ds = DataService();
        for (final m in eRows) {
          final String type = (m['type'] as String?) ?? 'memo';
          final DateTime tm = DateTime.fromMillisecondsSinceEpoch((m['time_ms'] as num).toInt()).toLocal();
          final String? memo = (m['memo'] as String?);
          try { await ds.postEvent(type: type, time: tm, memo: memo); } catch (_) {}
        }
        st['lastPushAtEvents'] = now.toUtc().toIso8601String();
        await SettingsStorage.save(st);
      }

      // process queued deletions
      try {
        final List<dynamic> box = (st['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        if (box.isNotEmpty) {
          final ds = DataService();
          final List<String> remain = <String>[];
          for (final e in box) {
            final String id = e.toString();
            bool delOk = false;
            try { delOk = await ds.deleteEvent(id); } catch (_) { delOk = false; }
            if (!delOk) remain.add(id);
          }
          st['eventDeleteOutbox'] = remain;
          await SettingsStorage.save(st);
        }
      } catch (_) {}

      // broadcast to refresh UI if needed
      try { DataSyncBus().emitGlucoseBulk(count: 0); } catch (_) {}
    } catch (_) {}
  }

  DateTime _parseIsoOrDefault(String? iso, DateTime dflt) {
    if (iso == null || iso.isEmpty) return dflt;
    try { return DateTime.parse(iso).toLocal(); } catch (_) { return dflt; }
  }
}
