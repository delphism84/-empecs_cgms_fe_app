import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  SettingsStorage._();

  static const String storageKey = 'cgms.settings';

  static const Set<String> _alarmPatchKeys = <String>{
    'alarmsCacheBySn',
    'alarmsCache',
    'alarmsCacheAt',
  };

  /// load() 직후 오래된 스냅샷으로 save(전체 map) 할 때 덮어쓰면 안 되는 사용자 설정 키.
  static const Set<String> _userPrefPatchKeys = <String>{
    'language',
    'region',
    'autoRegion',
    'guestMode',
    'glucoseUnit',
    'timeFormat',
    'accHighContrast',
    'accLargerFont',
    'accColorblind',
    'notificationsEnabled',
    'darkMode',
    'alarmsMuteAll',
  };

  /// 센서/온보딩/동기화 메타만 건드리는 저장인데 patch 에 사용자 설정이 끼어 있으면 stale.
  static bool _patchTouchesIncidentalMetadata(Map<String, dynamic> patch) {
    for (final String k in patch.keys) {
      // 주의: QA 화면 텔레메트리 키(`gu0101*`, `sc0101*`, `me0101*` …)만 매칭해야 한다.
      // `startsWith('gu')` 처럼 느슨하면 `guestMode` 같은 사용자 설정 키를 오탐해,
      // 설정 저장 시 glucoseUnit/language 등 user pref가 통째로 stripped 되어 저장 안 됨.
      if (k == 'eqsn' ||
          k == 'lastTrid' ||
          k == 'lastEvid' ||
          k == 'lastServerUploadedTrid' ||
          k.startsWith('sc0') ||
          k.startsWith('lo0') ||
          k.startsWith('gu0') ||
          k.startsWith('tg0') ||
          k.startsWith('rp0') ||
          k.startsWith('pd0') ||
          k.startsWith('me0') ||
          k.startsWith('ar01') ||
          k.startsWith('lastPush') ||
          k.startsWith('offline')) {
        return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> _sanitizeSettingsPatch(Map<String, dynamic> patch) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(patch);
    for (final String k in _alarmPatchKeys) {
      out.remove(k);
    }
    if (_patchTouchesIncidentalMetadata(out)) {
      for (final String k in _userPrefPatchKeys) {
        out.remove(k);
      }
    }
    return out;
  }

  static void _stripAlarmKeysFromSettingsMap(Map<String, dynamic> data) {
    data['alarmsCache'] = <Map<String, dynamic>>[];
    data['alarmsCacheBySn'] = <String, dynamic>{};
    data['alarmsCacheAt'] = '';
  }

  static Future<void> _ioChain = Future<void>.value();

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

  static const Map<String, dynamic> defaultSettings = {
    'language': 'en',
    'region': 'KR',
    'autoRegion': true,
    'guestMode': false,
    'glucoseUnit': 'mgdl',
    'timeFormat': '24h',
    'shareConsent': false,
    'shareRange': '7',
    'shareFrom': '',
    'shareTo': '',
    'shareFamily': false,
    'shareHealth': false,
    'accHighContrast': false,
    'accLargerFont': false,
    'accColorblind': false,
    'authToken': '',
    'lastUserId': '',
    'savedLoginEmail': '',
    'savedLoginPassword': '',
    'offlineLastLoginEmail': '',
    'offlinePwSaltHex': '',
    'offlinePwHashHex': '',
    'displayName': '',
    'eqsn': '',
    'sensorWarmupStartBySn': <String, dynamic>{},
    'sensorWarmupDurationSec': 30 * 60,
    'notificationsEnabled': true,
    'alarmsMuteAll': false,
    'registeredDevices': <Map<String, dynamic>>[],
    'lastTrid': 0,
    'lastServerUploadedTrid': 0,
    'lastEvid': 0,
    'chartDotSize': 2,
    'eventsSync': false,
    'offlineMode': true,
    'lastPushAtGlucose': '',
    'lastPushAtEvents': '',
    'offlineUploadPending': false,
    'offlineUploadFromGlucose': '',
    'offlineUploadFromEvents': '',
    'eventDeleteOutbox': <String>[],
    'apiBaseUrl': '',
    'lastAlert': <String, dynamic>{},
    'lastLogTxAt': '',
    'lastLogTxOk': false,
    'ar0108Enabled': true,
    'ar0108UpdatedAt': '',
    'lastLockScreenAt': '',
    'lastLockScreenOk': false,
    'lastLockScreenValue': null,
    'lastLockScreenTrend': '',
    'lo0101ViewedAt': '',
    'lo0101AutoOpenEasyLoginSheet': false,
    'lo0101SheetOpenedAt': '',
    'lo0101LastProvider': '',
    'lo0101LastProviderAt': '',
    'lo0102ViewedAt': '',
    'lo0103ViewedAt': '',
    'lo0104ViewedAt': '',
    'lo0108EnteredAt': '',
    'lo0201ViewedAt': '',
    'lo0201Choice': '',
    'lo0202ViewedAt': '',
    'lo0202AgreedAt': '',
    'lo0203ViewedAt': '',
    'lo0203Phone': '',
    'lo0203VerifiedAt': '',
    'lo0204ViewedAt': '',
    'lo0205ViewedAt': '',
    'passcodeEnabled': false,
    'passcodeHash': '',
    'biometricEnabled': false,
    'biometricDebugBypass': false,
    'sc0101Consent': false,
    'sc0101Low': 70,
    'sc0101High': 180,
    'um0101ViewedAt': '',
    'lo0107ViewedAt': '',
    'sc0104ViewedAt': '',
    'sc0105ManualSnAt': '',
    'sc0105ManualSnValue': '',
    'lastScannedQrRaw': '',
    'lastScannedQrFullSn': '',
    'lastScannedQrSerial': '',
    'lastScannedQrAt': '',
    'lastScannedQrRegistered': false,
    'sc0106WarmupStartAt': '',
    'sc0106WarmupEndsAt': '',
    'sc0106WarmupActive': false,
    'sc0106WarmupDoneAt': '',
    'sc0103ViewedAt': '',
    'sc0602ViewedAt': '',
    'sc0602Reason': '',
    'sc0701ViewedAt': '',
    'sc0701Enabled': true,
    'sc0701Preset': 'Custom',
    'sc0701From': '',
    'sc0701To': '',
    'sc0701ItemSummary': true,
    'sc0701ItemDistribution': true,
    'sc0701ItemGraph': true,
    'sc0701ItemUserProfile': false,
    'sc0701MethodEmail': true,
    'sc0701MethodSms': false,
    'sc0701Format': 'PDF',
    'sc0701Revocable': true,
    'sc0701LastSharedAt': '',
    'sc0701LastSharedOk': false,
    'sc0701LastNote': '',
    'sc0701RenderedAt': '',
    'sc0201ViewedAt': '',
    'sc0201RenderedAt': '',
    'sc0301ViewedAt': '',
    'sc0401ViewedAt': '',
    'sc0501ViewedAt': '',
    'sc0601ViewedAt': '',
    'sc0801ViewedAt': '',
    'gu0101RenderedAt': '',
    'gu0101Value': null,
    'gu0102Trend': '',
    'gu0103Color': '',
    'tg0101ViewedAt': '',
    'tg0102ViewedAt': '',
    'rp0101ViewedAt': '',
    'rp0101RenderedAt': '',
    'pd0101ViewedAt': '',
    'pd0101RefreshedAt': '',
    'pd0101ItemsCount': 0,
    'me0101ViewedAt': '',
    'me0101SavedAt': '',
    'me0101SavedType': '',
    'me0101FoodShotAt': '',
    'me0101FoodShotAsset': '',
    'alarmsCache': <Map<String, dynamic>>[],
    'alarmsCacheBySn': <String, dynamic>{},
    'alarmsCacheAt': '',
    'sensorsCache': <Map<String, dynamic>>[],
    'sensorsCacheAt': '',
  };

  static Future<Map<String, dynamic>> _readRaw(SharedPreferences prefs) async {
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return Map<String, dynamic>.from(defaultSettings);
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final merged = {...defaultSettings, ...data};
      if (merged['language'] is! String) merged['language'] = 'en';
      if (merged['region'] is! String) merged['region'] = 'KR';
      if (merged['autoRegion'] is! bool) merged['autoRegion'] = true;
      if (merged['glucoseUnit'] is! String) merged['glucoseUnit'] = 'mgdl';
      if (merged['timeFormat'] is! String) merged['timeFormat'] = '24h';
      _stripAlarmKeysFromSettingsMap(merged);
      return merged;
    } catch (_) {
      return Map<String, dynamic>.from(defaultSettings);
    }
  }

  static Future<void> _writeRaw(SharedPreferences prefs, Map<String, dynamic> data) async {
    await prefs.setString(storageKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>> load() {
    return _runSerialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final merged = await _readRaw(prefs);
      return Map<String, dynamic>.from(merged);
    });
  }

  /// load()→save(전체 map) 패턴에서 오래된 스냅샷이 되돌리면 안 되는 단조 증가 카운터.
  /// (BLE 인입이 디스크 값을 올린 사이, 낡은 _pushBacklog 스냅샷 저장이 워터마크를 후퇴시키는 것 방지)
  static const Set<String> _monotonicCounterKeys = <String>{
    'lastTrid',
    'lastServerUploadedTrid',
    'lastEvid',
  };

  static void _applyPatch(Map<String, dynamic> current, Map<String, dynamic> patch) {
    for (final MapEntry<String, dynamic> entry in patch.entries) {
      final String k = entry.key;
      final dynamic v = entry.value;
      if (k == 'sensorWarmupStartBySn' && v is Map) {
        final Map<String, dynamic> existing = current[k] is Map
            ? (current[k] as Map).map((key, val) => MapEntry(key.toString(), val))
            : <String, dynamic>{};
        for (final MapEntry<dynamic, dynamic> sn in v.entries) {
          existing[sn.key.toString()] = sn.value;
        }
        current[k] = existing;
      } else if (_monotonicCounterKeys.contains(k)) {
        // 0(의도적 리셋)은 허용, 그 외에는 디스크 현재값보다 클 때만 전진(후퇴 차단).
        final num newV = (v is num) ? v : (num.tryParse('$v') ?? 0);
        final num curV = (current[k] is num) ? (current[k] as num) : 0;
        if (newV == 0 || newV > curV) {
          current[k] = v;
        }
      } else {
        current[k] = v;
      }
    }
  }

  /// 단조 가드를 **의도적으로 우회**해 카운터를 되돌린다(워터마크 복구 전용).
  /// 일반 저장 경로(`save`)로는 후퇴가 차단되므로, DB 실측값과 재동기할 때만 쓴다.
  static Future<void> rewindCounter(String key, int value) {
    if (!_monotonicCounterKeys.contains(key)) {
      throw ArgumentError('rewindCounter is only for monotonic counters: $key');
    }
    return _runSerialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = await _readRaw(prefs);
      current[key] = value;
      await _writeRaw(prefs, current);
    });
  }

  /// [patch] keys are merged into the latest on-disk settings (serialized, SN buckets deep-merged).
  static Future<void> save(Map<String, dynamic> patch) {
    // Avoid too much noise: only log keys relevant to the issues (alarms/language/notifications).
    final List<String> keys = patch.keys.toList()..sort();
    final bool shouldLog = keys.any((k) => k == 'alarmsCacheBySn' || k == 'language' || k == 'notificationsEnabled');
    if (shouldLog) {
      // Example: [SettingsStorage.save] keys=[language] patch=...
      log('[SettingsStorage.save] keys=$keys', name: 'qa');
    }
    return _runSerialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = await _readRaw(prefs);
      _applyPatch(current, _sanitizeSettingsPatch(patch));
      await _writeRaw(prefs, current);
    });
  }
}
