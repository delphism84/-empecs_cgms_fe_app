import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:helpcare/core/utils/settings_storage.dart';

/// 알람 전용 JSON 저장소 (`cgms.settings` 와 분리).
///
/// - SN별 `alarmsCacheBySn`, 현재 SN 리스트 `alarmsCache`, `alarmsCacheAt`
/// - 기존 settings blob 의 알람 키는 1회 이전 후 비우고 이후 무시
class AlarmsStorage {
  AlarmsStorage._();

  static const String storageKey = 'cgms.alarms.v1';
  static const String migratedFlagKey = 'cgms.alarms.legacyMigrated.v1';

  static const Set<String> legacySettingsAlarmKeys = <String>{
    'alarmsCacheBySn',
    'alarmsCache',
    'alarmsCacheAt',
  };

  static Future<void> _ioChain = Future<void>.value();
  static bool _initialized = false;
  static bool _purgeScheduled = false;

  static Future<T> _runSerialized<T>(Future<T> Function() fn) {
    final Completer<T> completer = Completer<T>();
    _ioChain = _ioChain.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Map<String, dynamic> _emptyDoc() {
    return <String, dynamic>{
      'alarmsCacheBySn': <String, dynamic>{},
      'alarmsCache': <Map<String, dynamic>>[],
      'alarmsCacheAt': '',
    };
  }

  static Map<String, dynamic> _readDocRaw(SharedPreferences prefs) {
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return _emptyDoc();
    }
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return <String, dynamic>{
        'alarmsCacheBySn': data['alarmsCacheBySn'] is Map
            ? (data['alarmsCacheBySn'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
        'alarmsCache': data['alarmsCache'] is List ? data['alarmsCache'] : <dynamic>[],
        'alarmsCacheAt': (data['alarmsCacheAt'] as String? ?? '').toString(),
      };
    } catch (_) {
      return _emptyDoc();
    }
  }

  static Future<void> _writeDoc(SharedPreferences prefs, Map<String, dynamic> doc) async {
    await prefs.setString(storageKey, jsonEncode(doc));
  }

  static bool _docHasData(Map<String, dynamic> doc) {
    final Map<String, dynamic> bySn = _bySnFromDoc(doc);
    if (bySn.isNotEmpty) return true;
    final List<dynamic> flat = doc['alarmsCache'] is List ? doc['alarmsCache'] as List : const [];
    return flat.isNotEmpty;
  }

  static Map<String, dynamic> _bySnFromDoc(Map<String, dynamic> doc) {
    final dynamic raw = doc['alarmsCacheBySn'];
    if (raw is! Map) return <String, dynamic>{};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  static Map<String, dynamic> _legacyAlarmSlice(Map<String, dynamic> settings) {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String k in legacySettingsAlarmKeys) {
      if (settings.containsKey(k)) {
        out[k] = settings[k];
      }
    }
    return out;
  }

  static bool _legacyHasData(Map<String, dynamic> legacy) {
    final dynamic bySn = legacy['alarmsCacheBySn'];
    if (bySn is Map && bySn.isNotEmpty) return true;
    final dynamic flat = legacy['alarmsCache'];
    if (flat is List && flat.isNotEmpty) return true;
    return false;
  }

  static Map<String, dynamic> _docFromLegacy(Map<String, dynamic> legacy) {
    return <String, dynamic>{
      'alarmsCacheBySn': legacy['alarmsCacheBySn'] is Map
          ? (legacy['alarmsCacheBySn'] as Map).map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{},
      'alarmsCache': legacy['alarmsCache'] is List ? legacy['alarmsCache'] : <dynamic>[],
      'alarmsCacheAt': (legacy['alarmsCacheAt'] as String? ?? '').toString(),
    };
  }

  static Future<void> _purgeLegacyFromSettingsBlob() async {
    await SettingsStorage.save(<String, dynamic>{
      'alarmsCacheBySn': <String, dynamic>{},
      'alarmsCache': <Map<String, dynamic>>[],
      'alarmsCacheAt': '',
    });
  }

  static Future<void> _migrateIfNeeded(SharedPreferences prefs) async {
    if (_initialized) return;

    Map<String, dynamic> doc = _readDocRaw(prefs);
    final bool migrated = prefs.getBool(migratedFlagKey) == true;

    if (!migrated || !_docHasData(doc)) {
      final Map<String, dynamic> settings = await SettingsStorage.load();
      final Map<String, dynamic> legacy = _legacyAlarmSlice(settings);
      if (_legacyHasData(legacy)) {
        doc = _docFromLegacy(legacy);
        await _writeDoc(prefs, doc);
        log('[AlarmsStorage] migrated legacy alarm data from settings blob', name: 'qa');
      }
      await prefs.setBool(migratedFlagKey, true);
    }

    _initialized = true;

    if (!_purgeScheduled) {
      _purgeScheduled = true;
      unawaited(_purgeLegacyFromSettingsBlob());
    }
  }

  /// settings blob ? ??? ?? ??? ??? (1? ?? + legacy purge).
  static Future<void> ensureInitialized() {
    return _runSerialized(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _migrateIfNeeded(prefs);
    });
  }

  static Future<Map<String, dynamic>> loadBySn() {
    return _runSerialized(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _migrateIfNeeded(prefs);
      return _bySnFromDoc(_readDocRaw(prefs));
    });
  }

  static Future<List<Map<String, dynamic>>> loadFlatCache() {
    return _runSerialized(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _migrateIfNeeded(prefs);
      final dynamic raw = _readDocRaw(prefs)['alarmsCache'];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
          .toList();
    });
  }

  static Future<void> save({
    required Map<String, dynamic> bySn,
    required List<Map<String, dynamic>> currentSnList,
  }) {
    return _runSerialized(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _migrateIfNeeded(prefs);

      int? thOf(String type) {
        final Iterable<Map<String, dynamic>> r =
            currentSnList.where((e) => (e['type'] ?? '').toString() == type);
        if (r.isEmpty) return null;
        final dynamic v = r.first['threshold'];
        return v is num ? v.toInt() : null;
      }

      log(
        '[AlarmsStorage.save] snBuckets=${bySn.length} rows=${currentSnList.length} '
        'high(th=${thOf('high')}) low(th=${thOf('low')}) very_low(th=${thOf('very_low')})',
        name: 'qa',
      );

      await _writeDoc(prefs, <String, dynamic>{
        'alarmsCacheBySn': bySn,
        'alarmsCache': currentSnList,
        'alarmsCacheAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }
}
