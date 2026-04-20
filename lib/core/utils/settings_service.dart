import 'dart:convert';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/event_local_repo.dart';
import 'package:helpcare/core/utils/local_db.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/local_sync_service.dart';
import 'package:helpcare/core/config/default_dev_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 저장 정책: 모든 설정 기본 로컬 저장. BE는 로컬 성공 후 업로드용. BE 실패 시 폴백 없음.
class SettingsService {
  final ApiClient _api = ApiClient();

  static List<Map<String, dynamic>> _defaultAlarms() => [
        {'_id': 'local:very_low', 'type': 'very_low', 'enabled': true, 'threshold': 55, 'overrideDnd': true, 'sound': true, 'vibrate': true, 'repeatMin': 1},
        {'_id': 'local:low', 'type': 'low', 'enabled': true, 'threshold': 70, 'sound': true, 'vibrate': true, 'repeatMin': 5},
        {'_id': 'local:high', 'type': 'high', 'enabled': true, 'threshold': 180, 'sound': true, 'vibrate': true, 'repeatMin': 5},
        {'_id': 'local:rate', 'type': 'rate', 'enabled': true, 'threshold': 2, 'sound': true, 'vibrate': true, 'repeatMin': 10},
        {'_id': 'local:system', 'type': 'system', 'enabled': true, 'threshold': -88, 'sound': true, 'vibrate': true, 'repeatMin': 10, 'quietFrom': '22:00', 'quietTo': '07:00'},
      ];

  // sensors — 로컬만 읽기. 저장 시 로컬 성공 후 BE 업로드, 실패 시 폴백 없음.
  Future<List<Map<String, dynamic>>> listSensors() async {
    final st = await SettingsStorage.load();
    final v = st['sensorsCache'];
    if (v is! List || v.isEmpty) return [];
    return v.cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList();
  }

  Future<Map<String, dynamic>?> createSensor(Map<String, dynamic> body) async {
    final st = await SettingsStorage.load();
    final list = (st['sensorsCache'] is List)
        ? (st['sensorsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    final localId = 'local:sensor_${DateTime.now().millisecondsSinceEpoch}';
    final one = {...body, '_id': localId};
    list.add(one);
    st['sensorsCache'] = list;
    st['sensorsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    try {
      await _api.loadToken();
      final r = await _api.post('/api/settings/sensors', body: body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        final created = jsonDecode(r.body) as Map<String, dynamic>;
        final sid = (created['_id'] ?? '').toString();
        if (sid.isNotEmpty) {
          final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == localId);
          if (idx >= 0) {
            list[idx] = {...list[idx], '_id': sid};
            st['sensorsCache'] = list;
            await SettingsStorage.save(st);
          }
        }
        return created;
      }
    } catch (_) {}
    return one;
  }

  Future<Map<String, dynamic>?> updateSensor(String id, Map<String, dynamic> body) async {
    final st = await SettingsStorage.load();
    final list = (st['sensorsCache'] is List)
        ? (st['sensorsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == id);
    if (idx < 0) return null;
    list[idx] = {...list[idx], ...body};
    st['sensorsCache'] = list;
    st['sensorsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    if (!id.startsWith('local:')) {
      try {
        await _api.loadToken();
        final r = await _api.put('/api/settings/sensors/$id', body: body);
        if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return list[idx];
  }

  Future<bool> deleteSensor(String id) async {
    final st = await SettingsStorage.load();
    final list = (st['sensorsCache'] is List)
        ? (st['sensorsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == id);
    if (idx < 0) return true;
    list.removeAt(idx);
    st['sensorsCache'] = list;
    st['sensorsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    if (!id.startsWith('local:')) {
      try {
        await _api.loadToken();
        final r = await _api.delete('/api/settings/sensors/$id');
        if (r.statusCode == 200) return true;
      } catch (_) {}
    }
    return true;
  }

  // alarms — 로컬만 읽기. 비어 있으면 기본 알람 시드 후 반환. 저장 시 로컬 성공 후 BE 업로드, 실패 시 폴백 없음.
  /// 서버/JSON에서 repeatMin이 int·double·문자열로 올 수 있음 — 알람 간격 계산에 공통 사용.
  static int parseAlarmRepeatMinutes(dynamic v, {int fallback = 10}) {
    final int fb = fallback.clamp(1, 120);
    if (v == null) return fb;
    if (v is int) return v.clamp(1, 120);
    if (v is num) return v.toInt().clamp(1, 120);
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n != null) return n.clamp(1, 120);
    }
    return fb;
  }

  Future<List<Map<String, dynamic>>> listAlarms() async {
    final st = await SettingsStorage.load();
    List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
        ? (st['alarmsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    if (list.isEmpty) {
      list = _defaultAlarms();
      st['alarmsCache'] = list;
      st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    }
    return list;
  }

  Future<Map<String, dynamic>?> createAlarm(Map<String, dynamic> body) async {
    final st = await SettingsStorage.load();
    List<Map<String, dynamic>> list = (st['alarmsCache'] is List)
        ? (st['alarmsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    if (list.isEmpty) list = _defaultAlarms();
    final ty = (body['type'] ?? 'high').toString();
    final localId = 'local:$ty';
    final one = {...body, '_id': localId, 'type': ty};
    list.add(one);
    st['alarmsCache'] = list;
    st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    try {
      await _api.loadToken();
      final r = await _api.post('/api/settings/alarms', body: body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        final created = jsonDecode(r.body) as Map<String, dynamic>;
        final sid = (created['_id'] ?? '').toString();
        if (sid.isNotEmpty) {
          final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == localId);
          if (idx >= 0) {
            list[idx] = {...list[idx], '_id': sid};
            st['alarmsCache'] = list;
            await SettingsStorage.save(st);
          }
        }
        return created;
      }
    } catch (_) {}
    return one;
  }

  Future<Map<String, dynamic>?> updateAlarm(String id, Map<String, dynamic> body) async {
    final st = await SettingsStorage.load();
    final list = (st['alarmsCache'] is List)
        ? (st['alarmsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == id);
    if (idx < 0) return null;
    list[idx] = {...list[idx], ...body};
    st['alarmsCache'] = list;
    st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    if (!id.startsWith('local:')) {
      try {
        await _api.loadToken();
        final r = await _api.put('/api/settings/alarms/$id', body: body);
        if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return list[idx];
  }

  Future<bool> deleteAlarm(String id) async {
    final st = await SettingsStorage.load();
    final list = (st['alarmsCache'] is List)
        ? (st['alarmsCache'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>())).toList()
        : <Map<String, dynamic>>[];
    final idx = list.indexWhere((e) => (e['_id'] ?? '').toString() == id);
    if (idx < 0) return true;
    list.removeAt(idx);
    st['alarmsCache'] = list;
    st['alarmsCacheAt'] = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(st);
    if (!id.startsWith('local:')) {
      try {
        await _api.loadToken();
        final r = await _api.delete('/api/settings/alarms/$id');
        if (r.statusCode == 200) return true;
      } catch (_) {}
    }
    return true;
  }

  // eq list (device registry) — BE 전용(조회/등록). 로컬 캐시 없음.
  Future<Map<String, dynamic>> getEqBySerial(String serial) async {
    try {
      await _api.loadToken();
      final r = await _api.get('/api/settings/eq-list/${Uri.encodeComponent(serial)}');
      if (r.statusCode != 200) return {};
      return (jsonDecode(r.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// BLE MAC 정규화(대문자, 구분자 제거). 서버 `bleMac` 쿼리와 맞춤.
  static String normalizeBleMac(String? raw) {
    if (raw == null) return '';
    return raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  }

  /// 동일 센서 식별: **serial 또는 bleMac** 중 하나가 서버 등록과 일치하면 해당 행 반환(req 1-7).
  /// BE에 `/api/settings/eq-list/resolve`가 없으면 [getEqBySerial]로 폴백.
  Future<Map<String, dynamic>> resolveEqRegistration({String? serial, String? bleMac}) async {
    final String s = (serial ?? '').trim();
    final String mac = normalizeBleMac(bleMac);
    if (s.isEmpty && mac.isEmpty) return {};
    try {
      await _api.loadToken();
      final Map<String, dynamic> q = <String, dynamic>{};
      if (s.isNotEmpty) q['serial'] = s;
      if (mac.isNotEmpty) q['bleMac'] = mac;
      final r = await _api.get('/api/settings/eq-list/resolve', query: q);
      if (r.statusCode == 200) {
        final dynamic j = jsonDecode(r.body);
        if (j is Map && j.isNotEmpty) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(j.cast<String, dynamic>());
          if ((m['startAt'] ?? '').toString().trim().isNotEmpty ||
              (m['matchedBy'] ?? '').toString().trim().isNotEmpty ||
              (m['_id'] ?? '').toString().trim().isNotEmpty ||
              (m['serial'] ?? '').toString().trim().isNotEmpty) {
            return m;
          }
        }
      }
    } catch (_) {}
    if (s.isNotEmpty) return getEqBySerial(s);
    return {};
  }

  Future<bool> upsertEqStart({required String serial, DateTime? startAt}) async {
    try {
      await _api.loadToken();
      final body = <String, dynamic>{'serial': serial, if (startAt != null) 'startAt': startAt.toUtc().toIso8601String()};
      final r = await _api.post('/api/settings/eq-list', body: body);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // app settings — 로컬만 읽기. 저장 시 로컬 먼저, 그 다음 BE 업로드(실패 시 폴백 없음).
  Future<Map<String, dynamic>> getAppSetting() async {
    final st = await SettingsStorage.load();
    final unit = (st['glucoseUnit'] ?? 'mgdl').toString();
    return {
      'unit': unit == 'mmol' ? 'mmol/L' : 'mg/dL',
      'notifications': st['notificationsEnabled'] == true,
      'darkMode': st['darkMode'] == true,
      'timeFormat': (st['timeFormat'] ?? '24h').toString(),
      'alarmsMuteAll': st['alarmsMuteAll'] == true,
      'preferences': {
        'language': st['language'] ?? 'en',
        'region': st['region'] ?? 'KR',
        'autoRegion': st['autoRegion'] == true,
        'guestMode': st['guestMode'] == true,
        'timeFormat': st['timeFormat'] ?? '24h',
        'accHighContrast': st['accHighContrast'] == true,
        'accLargerFont': st['accLargerFont'] == true,
        'accColorblind': st['accColorblind'] == true,
        'notificationsEnabled': st['notificationsEnabled'] == true,
      },
    };
  }

  Future<Map<String, dynamic>?> updateAppSetting(Map<String, dynamic> body) async {
    final st = await SettingsStorage.load();
    if (body['unit'] != null) {
      final u = body['unit'].toString();
      st['glucoseUnit'] = (u == 'mmol/L' || u == 'mmol') ? 'mmol' : 'mgdl';
    }
    if (body['notifications'] != null) st['notificationsEnabled'] = body['notifications'] == true;
    if (body['darkMode'] != null) st['darkMode'] = body['darkMode'] == true;
    if (body['timeFormat'] != null) st['timeFormat'] = body['timeFormat'].toString();
    if (body['alarmsMuteAll'] != null) st['alarmsMuteAll'] = body['alarmsMuteAll'] == true;
    final prefs = body['preferences'] as Map<String, dynamic>?;
    if (prefs != null) {
      if (prefs['language'] != null) st['language'] = prefs['language'].toString();
      if (prefs['region'] != null) st['region'] = prefs['region'].toString();
      if (prefs['autoRegion'] != null) st['autoRegion'] = prefs['autoRegion'] == true;
      if (prefs['guestMode'] != null) st['guestMode'] = prefs['guestMode'] == true;
      if (prefs['timeFormat'] != null) st['timeFormat'] = prefs['timeFormat'].toString();
      if (prefs['accHighContrast'] != null) st['accHighContrast'] = prefs['accHighContrast'] == true;
      if (prefs['accLargerFont'] != null) st['accLargerFont'] = prefs['accLargerFont'] == true;
      if (prefs['accColorblind'] != null) st['accColorblind'] = prefs['accColorblind'] == true;
      if (prefs['notificationsEnabled'] != null) st['notificationsEnabled'] = prefs['notificationsEnabled'] == true;
    }
    await SettingsStorage.save(st);
    try {
      await _api.loadToken();
      final r = await _api.put('/api/settings/app', body: body);
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return st;
  }

  // developer helpers -> proxy to data endpoints
  Future<bool> clearGlucose() async {
    return DataService().clearGlucose();
  }

  Future<bool> clearEvents() async {
    final ok = await DataService().clearEvents();
    try { DataSyncBus().emitEventBulk(count: 0); } catch (_) {}
    return ok;
  }

  Future<bool> clearAllData() async {
    // avoid race: stop background local sync while clearing
    try { LocalSyncService().stop(); } catch (_) {}
    // ensure auth (dev fallback: DefaultDevAccount — POST /api/auth/login)
    try {
      final api = ApiClient();
      await api.loadToken();
      // load raw token from storage
      final s = await SettingsStorage.load();
      final String token = (s['authToken'] ?? '') as String;
      if (token.isEmpty) {
        final resp = await api.post('/api/auth/login', body: {
          'email': DefaultDevAccount.email,
          'password': DefaultDevAccount.password,
        });
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
          final String? t = data['token'] as String?;
          if (t != null && t.isNotEmpty) {
            await api.saveToken(t);
          }
        }
      }
    } catch (_) {}

    bool a = false;
    bool b = false;
    // 서버 통신 실패/오프라인이어도 로컬 삭제는 반드시 진행
    try { a = await clearGlucose(); } catch (_) { a = false; }
    try { b = await clearEvents(); } catch (_) { b = false; }
    bool localOk = true;
    // local wipe (always attempt; not fatal if fails)
    try {
      await GlucoseLocalRepo().clear();
    } catch (_) { localOk = false; }
    try {
      await EventLocalRepo().clear();
    } catch (_) { localOk = false; }
    try {
      await LocalDb().wipe();
    } catch (_) { localOk = false; }
    try {
      IngestQueueService().clear();
    } catch (_) {}
    try {
      await BleLogService().clear();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cgms.last_mac');
      final s = await SettingsStorage.load();
      s['lastTrid'] = 0;
      await SettingsStorage.save(s);
    } catch (_) {}
    // restart background sync
    try { LocalSyncService().start(); } catch (_) {}
    // notify UI to reload points and events immediately
    try { DataSyncBus().emitGlucoseBulk(count: 0); } catch (_) {}
    try { DataSyncBus().emitEventBulk(count: 0); } catch (_) {}
    // Return true if server cleared, or local cleared successfully
    return (a && b) || localOk;
  }

  Future<bool> seedGlucoseDay() async {
    return DataService().seedGlucoseDay();
  }

  Future<bool> seedGlucoseDays(int days) async {
    return DataService().seedGlucoseDays(days);
  }

  /// PD_01_01 View Previous Data 화면에서 기간 목록·그래프가 보이도록 로컬 시드
  Future<bool> seedPd0101PreviousData() async {
    return DataService().seedPd0101PreviousDataLocal();
  }
}


