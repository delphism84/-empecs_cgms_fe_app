import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:helpcare/core/utils/debug_config.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/global_loading.dart';
// no widget import needed here

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static String? _baseOverride;
  static bool _baseLoaded = false;

  String get base => _baseOverride ?? DebugConfig.apiBase;
  Duration get timeout => Duration(milliseconds: DebugConfig.apiTimeoutMs);
  String? _token;

  static void invalidateBaseCache() {
    _baseLoaded = false;
  }

  Future<void> _ensureBaseLoaded() async {
    if (_baseLoaded) return;
    try {
      final s = await SettingsStorage.load();
      final String v = (s['apiBaseUrl'] as String? ?? '').trim();
      _baseOverride = v.isEmpty ? null : v;
    } catch (_) {
      _baseOverride = null;
    } finally {
      _baseLoaded = true;
    }
  }

  Future<void> loadToken() async {
    final s = await SettingsStorage.load();
    _token = (s['authToken'] ?? '') as String;
  }

  Future<void> saveToken(String token) async {
    final s = await SettingsStorage.load();
    s['authToken'] = token;
    await SettingsStorage.save(s);
    _token = token;
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    final h = <String, String>{};
    if (jsonBody) h['Content-Type'] = 'application/json';
    if (_token != null && _token!.isNotEmpty) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    await _ensureBaseLoaded();
    final uri = Uri.parse('$base$path');
    GlobalLoading.begin();
    try {
      return await http
          .put(uri, headers: _headers(), body: jsonEncode(body ?? {}))
          .timeout(timeout);
    } finally {
      GlobalLoading.end();
    }
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    await _ensureBaseLoaded();
    final uri = Uri.parse('$base$path');
    GlobalLoading.begin();
    try {
      return await http
          .post(uri, headers: _headers(), body: jsonEncode(body ?? {}))
          .timeout(timeout);
    } finally {
      GlobalLoading.end();
    }
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async {
    await _ensureBaseLoaded();
    final uri = Uri.parse('$base$path').replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));
    GlobalLoading.begin();
    try {
      return await http.get(uri, headers: _headers(jsonBody: false)).timeout(timeout);
    } finally {
      GlobalLoading.end();
    }
  }

  Future<http.Response> delete(String path) async {
    await _ensureBaseLoaded();
    final uri = Uri.parse('$base$path');
    GlobalLoading.begin();
    try {
      return await http.delete(uri, headers: _headers(jsonBody: false)).timeout(timeout);
    } finally {
      GlobalLoading.end();
    }
  }
}

class DataService {
  final ApiClient _api = ApiClient();
  Future<bool> _canUpload() async {
    try {
      final s = await SettingsStorage.load();
      final String eqsn = (s['eqsn'] as String? ?? '').trim();
      final String startAt = (s['sensorStartAt'] as String? ?? '').trim();
      if (eqsn.isEmpty) return false;
      if (startAt.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
  Future<void> _markOnline() async {
    try {
      final s = await SettingsStorage.load();
      s['eventsSync'] = true; // 서버 동기화 사용
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchEvents({DateTime? from, DateTime? to, int limit = 1000, bool sync = true}) async {
    await _api.loadToken();
    // 1) local-first
    if (from != null && to != null) {
      try {
        String eqsn = '';
        String userId = '';
        try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
        final rows = await EventLocalRepo().range(from: from, to: to, limit: limit, eqsn: eqsn, userId: userId);
        if (rows.isNotEmpty || !sync) {
          return rows.map<Map<String, dynamic>>((r) => {
            '_id': ((r['sid'] as String?) ?? ((r['evid'] as int?)?.toString() ?? '')),
            'type': (r['type'] as String?) ?? 'memo',
            'time': DateTime.fromMillisecondsSinceEpoch((r['time_ms'] as num).toInt(), isUtc: true).toUtc().toIso8601String(),
            if (r['memo'] != null) 'memo': (r['memo'] as String),
            if (r['evid'] != null) 'evid': (r['evid'] as int?),
          }).toList();
        }
      } catch (_) {}
    }

    // 2) fetch remote, cache locally, return
    if (!sync) return [];
    final resp = await _api.get('/api/data/events', query: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      'limit': limit,
      'compact': 1,
    });
    if (resp.statusCode != 200) return [];
    await _markOnline();
    final String body = resp.body.trim();
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map && decoded.containsKey('t') && decoded.containsKey('ty')) {
        final List t = (decoded['t'] as List? ?? const []);
        final List ty = (decoded['ty'] as List? ?? const []);
        final List m = (decoded['m'] as List? ?? const []);
        final List id = (decoded['id'] as List? ?? const []);
        final int n = t.length;
        final List<Map<String, dynamic>> out = [];
        for (int i = 0; i < n; i++) {
          final DateTime tt = DateTime.fromMillisecondsSinceEpoch((t[i] as num).toInt(), isUtc: true).toLocal();
          final String tyStr = (i < ty.length ? ty[i] : 'memo')?.toString() ?? 'memo';
          final String? memo = (i < m.length && m[i] != null) ? m[i]?.toString() : null;
          final String? sid = (i < id.length ? id[i] : null)?.toString();
          // cache
        try {
          String eqsn = '';
          String userId = '';
          try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
          await EventLocalRepo().addOrUpdate(time: tt, type: tyStr, memo: memo, sid: sid, eqsn: eqsn, userId: userId);
        } catch (_) {}
          out.add({ '_id': sid ?? '', 'type': tyStr, 'time': tt.toUtc().toIso8601String(), if (memo != null) 'memo': memo });
        }
        return out;
      }
      if (decoded is List) {
        final List<Map<String, dynamic>> list = decoded.cast<Map<String, dynamic>>();
        for (final e in list) {
          try {
            final DateTime tt = DateTime.parse((e['time'] as String)).toLocal();
            final String tyStr = (e['type'] as String?) ?? 'memo';
            final String? memo = e['memo'] as String?;
            final String? sid = (e['_id'] as String?);
            try {
              String eqsn = '';
              String userId = '';
              try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
              await EventLocalRepo().addOrUpdate(time: tt, type: tyStr, memo: memo, sid: sid, eqsn: eqsn, userId: userId);
            } catch (_) {}
          } catch (_) {}
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchGlucose({DateTime? from, DateTime? to, int limit = 2000}) async {
    await _api.loadToken();
    // 1) 로컬 캐시 최우선 (오프라인/비행기모드에서도 즉시 응답)
    if (from != null && to != null) {
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final rows = await GlucoseLocalRepo().range(from: from, to: to, limit: limit, eqsn: eqsn, userId: userId);
      if (rows.isNotEmpty) {
        return rows.map<Map<String, dynamic>>((r) => {
          'time': DateTime.fromMillisecondsSinceEpoch((r['time_ms'] as num).toInt(), isUtc: true).toUtc().toIso8601String(),
          'value': ((r['value'] as num?) ?? 0).toDouble(),
          if (r['trid'] != null) 'trid': (r['trid'] as num).toInt(),
        }).toList();
      }
    }

    // 2) 로컬에 없을 때만 서버 조회 → 성공 시 로컬에 캐시 후 반환
    try {
      final resp = await _api.get('/api/data/glucose', query: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        'limit': limit,
        'compact': 1,
      });
      if (resp.statusCode != 200) return [];
      await _markOnline();
      final dynamic decoded = jsonDecode(resp.body);
      List<Map<String, dynamic>> listOut = [];
      if (decoded is Map && decoded.containsKey('t') && decoded.containsKey('v')) {
        final List t = decoded['t'] as List? ?? const [];
        final List v = decoded['v'] as List? ?? const [];
        final List tr = decoded['tr'] as List? ?? const [];
        final int n = t.length;
        // batch insert to local
        final List<DateTime> times = [];
        final List<double> values = [];
        final List<int?> trids = [];
        for (int i = 0; i < n; i++) {
          final DateTime time = DateTime.fromMillisecondsSinceEpoch((t[i] as num).toInt(), isUtc: true).toLocal();
          final double val = (i < v.length ? (v[i] as num).toDouble() : 0.0);
          final int? trid = (i < tr.length && tr[i] != null) ? (tr[i] as num).toInt() : null;
          times.add(time);
          values.add(val);
          trids.add(trid);
          listOut.add({ 'time': time.toUtc().toIso8601String(), 'value': val, if (trid != null) 'trid': trid });
        }
        try {
          String eqsn = '';
          String userId = '';
          try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
          await GlucoseLocalRepo().addPointsBatch(times: times, values: values, trids: trids, eqsn: eqsn, userId: userId);
        } catch (_) {}
        return listOut;
      }
      if (decoded is List) {
        listOut = decoded.cast<Map<String, dynamic>>();
        try {
          final List<DateTime> times = [];
          final List<double> values = [];
          final List<int?> trids = [];
          for (final m in listOut) {
            final DateTime tLoc = DateTime.parse((m['time'] as String)).toLocal();
            final double vLoc = ((m['value'] as num?) ?? 0).toDouble();
            final int? tridLoc = (m['trid'] as num?)?.toInt();
            times.add(tLoc); values.add(vLoc); trids.add(tridLoc);
          }
          String eqsn = '';
          String userId = '';
          try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
          await GlucoseLocalRepo().addPointsBatch(times: times, values: values, trids: trids, eqsn: eqsn, userId: userId);
        } catch (_) {}
        return listOut;
      }
      return [];
    } catch (_) {
      // 오프라인/타임아웃 등 → 로컬 재조회로 폴백
      if (from != null && to != null) {
        String eqsn = '';
        String userId = '';
        try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
        final rows = await GlucoseLocalRepo().range(from: from, to: to, limit: limit, eqsn: eqsn, userId: userId);
        if (rows.isNotEmpty) {
          return rows.map<Map<String, dynamic>>((r) => {
            'time': DateTime.fromMillisecondsSinceEpoch((r['time_ms'] as num).toInt(), isUtc: true).toUtc().toIso8601String(),
            'value': ((r['value'] as num?) ?? 0).toDouble(),
            if (r['trid'] != null) 'trid': (r['trid'] as num).toInt(),
          }).toList();
        }
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchGlucoseDelta({required int fromTrid, int limit = 2000}) async {
    await _api.loadToken();
    final resp = await _api.get('/api/data/glucose', query: {
      'fromTrid': fromTrid,
      'limit': limit,
    });
    if (resp.statusCode != 200) return [];
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<bool> postGlucose({required DateTime time, required num value, int? trid}) async {
    if (!await _canUpload()) return false;
    await _api.loadToken();
    try {
      String eqsn = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); } catch (_) {}
      final r = await _api.post('/api/data/glucose', body: {
        'time': time.toUtc().toIso8601String(),
        'value': value,
        if (trid != null) 'trid': trid,
        if (eqsn.isNotEmpty) 'eqsn': eqsn,
      });
      if (r.statusCode == 200) { await _markOnline(); return true; }
    } catch (_) {}
    // fallback: local cache only
    try {
      final s = await SettingsStorage.load();
      final String eqsn = (s['eqsn'] as String? ?? '');
      final String userId = (s['lastUserId'] as String? ?? '');
      await GlucoseLocalRepo().addPoint(time: time, value: value.toDouble(), trid: trid, eqsn: eqsn, userId: userId);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> postGlucoseBatch({required List<int> t, required List<num> v, required List<int?> tr}) async {
    if (!await _canUpload()) return false;
    await _api.loadToken();
    // try server first
    try {
      String eqsn = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); } catch (_) {}
      final r = await _api.post('/api/data/glucose/batch', body: {
        't': t,
        'v': v,
        'tr': tr,
        if (eqsn.isNotEmpty) 'eqsn': eqsn,
      });
      if (r.statusCode == 200) { await _markOnline(); return true; }
    } catch (_) {}
    // fallback: write to local cache only
    try {
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      final int n = math.min(t.length, math.min(v.length, tr.length));
      for (int i = 0; i < n; i++) {
        final DateTime time = DateTime.fromMillisecondsSinceEpoch(t[i], isUtc: true).toLocal();
        await GlucoseLocalRepo().addPoint(time: time, value: v[i].toDouble(), trid: tr[i], eqsn: eqsn, userId: userId);
      }
      return true;
    } catch (_) { return false; }
  }

  Future<bool> postEvent({required String type, required DateTime time, String? memo}) async {
    await _api.loadToken();
    bool ok = false;
    try {
      String eqsn = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); } catch (_) {}
      final r = await _api.post('/api/data/events', body: {
        'type': type,
        'time': time.toUtc().toIso8601String(),
        if (memo != null) 'memo': memo,
        if (eqsn.isNotEmpty) 'eqsn': eqsn,
      });
      ok = r.statusCode == 200;
      if (ok) { await _markOnline(); }
    } catch (_) {}
    // always write to local for immediate UX
    try {
      String eqsn = '';
      String userId = '';
      try { final s = await SettingsStorage.load(); eqsn = (s['eqsn'] as String? ?? ''); userId = (s['lastUserId'] as String? ?? ''); } catch (_) {}
      await EventLocalRepo().addOrUpdate(time: time.toLocal(), type: type, memo: memo, eqsn: eqsn, userId: userId);
    } catch (_) {}
    DataSyncBus().emitEventItem({'_op': 'create', 'type': type, 'time': time.toLocal().toIso8601String(), if (memo != null) 'memo': memo});
    return ok;
  }

  Future<bool> deleteEvent(String id) async {
    final String trimmed = id.trim();
    bool ok = true;
    bool localOk = false;
    // 서버 id는 Mongo ObjectId(24자리 hex)만 유효 → 그 외는 서버 호출 생략
    final bool looksLikeObjectId = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(trimmed);
    if (trimmed.isNotEmpty && looksLikeObjectId) {
    await _api.loadToken();
      final resp = await _api.delete('/api/data/events/$trimmed');
      ok = resp.statusCode == 200;
    }
    // 항상 로컬에서도 삭제 시도 (오프라인/서버 실패 시에도 정리)
    try { await EventLocalRepo().deleteByAny(trimmed.isNotEmpty ? trimmed : id); localOk = true; } catch (_) {}
    // 서버 삭제 실패 시, 삭제 outbox에 큐잉하여 다음 온라인 전환 시 재시도
    try {
      if (looksLikeObjectId && !ok) {
        final s = await SettingsStorage.load();
        final List<dynamic> box = (s['eventDeleteOutbox'] as List<dynamic>? ?? <dynamic>[]);
        final List<String> out = box.map((e) => e.toString()).toList();
        if (!out.contains(trimmed)) {
          out.add(trimmed);
          s['eventDeleteOutbox'] = out;
          await SettingsStorage.save(s);
        }
      }
    } catch (_) {}
    // 로컬 반영 즉시 렌더링 갱신
    DataSyncBus().emitEventItem({'_op': 'delete', 'id': trimmed.isNotEmpty ? trimmed : id});
    return ok || localOk;
  }

  // developer helpers under data service
  Future<bool> clearGlucose() async {
    await _api.loadToken();
    final resp = await _api.delete('/api/data/glucose/clear');
    return resp.statusCode == 200;
  }

  Future<bool> clearEvents() async {
    await _api.loadToken();
    final resp = await _api.delete('/api/data/events/clear');
    return resp.statusCode == 200;
  }

  Future<bool> seedGlucoseDay() async {
    await _api.loadToken();
    try {
      final resp = await _api.post('/api/data/glucose/seed-day');
      if (resp.statusCode == 200) return true;
      // 401 등 실패 시 로컬 시드로 폴백
      await _seedLocalDays(1);
      return true;
    } catch (_) {
      await _seedLocalDays(1);
      return true;
    }
  }

  Future<bool> seedGlucoseDays(int days) async {
    await _api.loadToken();
    try {
      final resp = await _api.post('/api/data/glucose/seed-days', body: { 'days': days });
      if (resp.statusCode == 200) return true;
      // 401 등 실패 시 로컬 시드로 폴백
      await _seedLocalDays(days);
      return true;
    } catch (_) {
      await _seedLocalDays(days);
      return true;
    }
  }

  Future<void> _seedLocalDays(int days) async {
    // generate synthetic data locally for demo/offline modes
    try {
      final DateTime now = DateTime.now();
      final int totalDays = days.clamp(1, 30);
      final Duration step = const Duration(minutes: 15);
      final int stepsPerDay = (const Duration(days: 1).inMinutes / step.inMinutes).round();
      // attach eqsn and validate exists
      String eqsn = '';
      try {
        final s = await SettingsStorage.load();
        eqsn = (s['eqsn'] as String? ?? '').trim();
      } catch (_) {}
      if (eqsn.isEmpty) {
        // no SN configured -> skip seeding to keep data consistent
        return;
      }
      String userId = '';
      try { final s2 = await SettingsStorage.load(); userId = (s2['lastUserId'] as String? ?? ''); } catch (_) {}
      for (int d = 0; d < totalDays; d++) {
        final DateTime base = now.subtract(Duration(days: d));
        for (int i = 0; i < stepsPerDay; i++) {
          final DateTime t = base.subtract(Duration(minutes: i * step.inMinutes));
          // simple waveform + noise around 120 mg/dL
          final double wave = 120 + 35 * math.sin((i / stepsPerDay) * 6.28318 * 2);
          final double jitter = (i % 7) - 3; // -3..+3
          final double v = (wave + jitter).clamp(50.0, 250.0);
          await GlucoseLocalRepo().addPoint(time: t, value: v, trid: null, eqsn: eqsn, userId: userId);
        }
      }
    } catch (_) {}
  }
}


