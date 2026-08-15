import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/config/test_account.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/ble_auto_pair_store.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/local_db.dart';
import 'package:helpcare/core/utils/sensor_expiry_service.dart';
import 'package:helpcare/core/utils/sensor_usage.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// QA 원격 명령 라우터 (**디버그 빌드 전용**).
///
/// 네이티브 [App] 의 BroadcastReceiver → MethodChannel `cgms/qa` 로 들어온다.
/// 실기기·에뮬레이터에서 앱을 손대지 않고 상태를 주입/조회하기 위한 통로다.
///
/// ```bash
/// # 잔여시간을 11시간 59분으로 만들고(=센서 시작시각 역산) 만료 파이프라인 재평가
/// adb shell am broadcast -a com.helpcare.app.QA --es cmd sensor.setRemaining --es args '{"minutes":719}'
/// # 현재 상태 덤프 (logcat -s CGMS_QA)
/// adb shell am broadcast -a com.helpcare.app.QA --es cmd dump
/// ```
class QaCommandChannel {
  QaCommandChannel._();

  static const MethodChannel _channel = MethodChannel('cgms/qa');
  static bool _installed = false;

  /// 마지막 명령 결과(웹/데스크톱 QA 화면에서도 확인할 수 있게 보관).
  static final ValueNotifier<String> lastResult = ValueNotifier<String>('');

  static void install() {
    if (_installed) return;
    if (kReleaseMode) return; // 릴리스 빌드에서는 라우터 자체를 달지 않는다.
    _installed = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      final String raw = (call.arguments is String) ? call.arguments as String : '';
      Map<String, dynamic> args = <String, dynamic>{};
      if (raw.trim().isNotEmpty) {
        try {
          final dynamic d = jsonDecode(raw);
          if (d is Map) args = Map<String, dynamic>.from(d);
        } catch (_) {
          return 'ERR bad args json: $raw';
        }
      }
      try {
        final String out = await _dispatch(call.method, args);
        lastResult.value = '${call.method}: $out';
        unawaited(BleLogService().add('QA', '${call.method} -> $out'));
        return out;
      } catch (e) {
        final String out = 'ERR $e';
        lastResult.value = '${call.method}: $out';
        unawaited(BleLogService().add('QA', '${call.method} -> $out'));
        return out;
      }
    });
  }

  static Future<String> _dispatch(String cmd, Map<String, dynamic> args) async {
    switch (cmd) {
      case 'ping':
        return 'pong';

      /// QA 빌드 여부·테스트 계정 활성 상태 확인.
      case 'qa.info':
        return jsonEncode(<String, dynamic>{
          'testAccountEnabled': TestAccount.enabled,
          'testAccountEmail': TestAccount.email,
          'releaseMode': kReleaseMode,
        });

      /// 센서 시작시각을 역산해 **잔여시간을 정확히 지정**한다.
      /// args: {"minutes": 719}  → 11시간 59분 남은 상태
      case 'sensor.setRemaining':
        return _setRemaining(Duration(minutes: _int(args['minutes'], 0)));

      /// 잔여시간을 초 단위로 지정(12시간 경계 통과 관찰용).
      /// args: {"seconds": 43205}
      case 'sensor.setRemainingSeconds':
        return _setRemaining(Duration(seconds: _int(args['seconds'], 0)));

      /// 즉시 만료 상태로 만든다.
      case 'sensor.expireNow':
        return _setRemaining(Duration.zero);

      /// 센서 시작시각을 ISO8601(UTC)로 직접 지정.
      /// args: {"startAtUtc":"2026-07-12T00:00:00Z","eqsn":"C21ZS00101"}
      case 'sensor.setStart':
        return _setStart(args);

      /// **QR 스캔 없이** 센서를 등록한다(QA 전용).
      /// QR 코드가 없고 BLE 기기만 있는 환경에서 `_canUpload()` 조건(eqsn + sensorStartAt)과
      /// 서버 EQ 행까지 한 번에 갖춘다.
      /// args: {"eqsn":"C21ZS00102", "startedMinutesAgo":120, "bleMac":"71:8F:10:3D:66:41"}
      case 'sensor.register':
        return _register(args);

      /// 만료 팝업 1회성 플래그(표시함/스누즈)를 지운다 → 다시 뜨게 만든다.
      case 'sensor.resetPrompts':
        await SensorExpiryService().resetPromptHistory();
        return 'ok';

      /// 만료 판정 즉시 재평가(타이머를 기다리지 않음).
      case 'sensor.evaluate':
        final SensorExpiryStatus? s = await SensorExpiryService().evaluate();
        return jsonEncode(SensorExpiryService().debugSnapshot()..['prompted'] = s != null);

      /// QA 전용 유효기간 축소(예: 16일 대신 20분짜리 세션으로 만료 관찰).
      /// args: {"minutes": 20} / {"minutes": 0} 이면 해제
      case 'sensor.validityOverride':
        final int m = _int(args['minutes'], 0);
        SensorExpiryService.qaValidityOverride =
            m <= 0 ? null : Duration(minutes: m);
        await SensorExpiryService().evaluate(silent: true);
        return m <= 0 ? 'cleared' : 'validity=${m}m';

      /// 전체 상태 덤프 — 만료/데이터/워터마크를 한 번에 본다.
      case 'dump':
        return jsonEncode(await _dump());

      /// PART1 진단 쿼리: eqsn 별 trid 범위·건수.
      case 'db.groups':
        return jsonEncode(await _dbGroups());

      /// PART1 회귀 검증: "측정값 미갱신"을 만들던 3가지 경로를 실제 DB로 재현한다.
      case 'db.selfTest':
        return jsonEncode(await _selfTest());

      /// 특정 센서(eqsn) 구간만 삭제 — 오염된 행 정리·센서 교체 시나리오 초기화용.
      /// args: {"eqsn":"C21Z00102"}
      case 'db.clearEqsn':
        final String eq = (args['eqsn'] ?? '').toString().trim();
        if (eq.isEmpty) return 'ERR eqsn required';
        final int before = await GlucoseLocalRepo().count();
        await GlucoseLocalRepo().clearForEqsn(eq);
        final int after = await GlucoseLocalRepo().count();
        return 'deleted ${before - after} rows for eqsn=$eq';

      /// 설정 키를 직접 패치(언어·단위 등 캡처 조건 맞추기). args: {"language":"ko"}
      case 'settings.patch':
        if (args.isEmpty) return 'ERR args required';
        await SettingsStorage.save(args);
        return 'patched ${args.keys.join(',')}';

      /// 현재 설정 스냅샷의 특정 키들만 조회. args: {"keys":["language","eqsn"]}
      case 'settings.get':
        final Map<String, dynamic> st = await SettingsStorage.load();
        final List<dynamic> keys = (args['keys'] as List<dynamic>?) ?? const <dynamic>[];
        if (keys.isEmpty) return jsonEncode(st.keys.toList()..sort());
        return jsonEncode(<String, dynamic>{
          for (final dynamic k in keys) '$k': st['$k'],
        });

      /// 현재 화면 라우트 이동 (캡처 자동화용). args: {"route":"/gu/01/01"}
      case 'nav':
        final String route = (args['route'] ?? '').toString();
        if (route.isEmpty) return 'ERR route required';
        final st = AppNav.navigatorKey.currentState;
        if (st == null) return 'ERR navigator not ready';
        unawaited(st.pushNamed(route));
        return 'pushed $route';

      default:
        return 'ERR unknown cmd: $cmd';
    }
  }

  static Future<String> _setRemaining(Duration remaining) async {
    final Duration validity = SensorExpiryService.qaValidityOverride ??
        AppConstants.sensorValidityDuration;
    if (remaining > validity) {
      return 'ERR remaining(${remaining.inMinutes}m) > validity(${validity.inMinutes}m)';
    }
    // 시작시각 = 지금 - (유효기간 - 남기고 싶은 시간)
    final DateTime start = DateTime.now().subtract(validity - remaining);
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String eqsn = (st['eqsn'] as String? ?? '').trim();
    await SettingsStorage.save(<String, dynamic>{
      'sensorStartAt': start.toUtc().toIso8601String(),
      if (eqsn.isNotEmpty) 'sensorStartAtEqsn': eqsn,
    });

    // 서버에 EQ 행이 있으면 그쪽이 권위를 가진다(`syncStartAtWithServer`).
    // 로컬만 바꾸면 수 초 안에 서버 값으로 되돌아가 시나리오가 성립하지 않는다.
    bool serverSynced = false;
    if (eqsn.isNotEmpty) {
      try {
        serverSynced = await SettingsService()
            .upsertEqStart(serial: eqsn, startAt: start.toUtc());
      } catch (_) {}
    }

    await SensorExpiryService().resetPromptHistory();
    final SensorExpiryStatus? s = await SensorExpiryService().evaluate();
    return jsonEncode(<String, dynamic>{
      'startAt': SensorUsage.formatStartLocal(start),
      'remain': SensorUsage.formatRemainHm(remaining),
      'state': s?.state.name ?? 'none',
      'expiresAt': s == null ? null : SensorUsage.formatExpiryAt(s.expiresAtLocal),
      'serverEqSynced': serverSynced,
    });
  }

  /// QR 스캔 경로가 하는 일을 명령으로 재현한다:
  /// eqsn 확정 → 시작시각 기록 → BLE MAC 페어링 저장 → 서버 EQ 행 upsert → 만료 상태 재평가.
  /// 단, 로컬 이력은 지우지 않는다(등록이 데이터 삭제를 동반해선 안 된다).
  static Future<String> _register(Map<String, dynamic> args) async {
    final String eqsn = (args['eqsn'] ?? '').toString().trim();
    if (eqsn.isEmpty) return 'ERR eqsn required';
    final int agoMin = _int(args['startedMinutesAgo'], 0);
    final DateTime start = DateTime.now().subtract(Duration(minutes: agoMin));
    final String mac = (args['bleMac'] ?? '').toString().trim();

    final String nowIso = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(<String, dynamic>{
      'eqsn': eqsn,
      'sensorStartAt': start.toUtc().toIso8601String(),
      'sensorStartAtEqsn': eqsn,
      'lastScannedQrFullSn': eqsn.toUpperCase(),
      'lastScannedQrSerial': eqsn.toUpperCase(),
      'lastScannedQrAt': nowIso,
      'lastScannedQrRegistered': true,
    });
    await IngestQueueService.warmCache();

    if (mac.isNotEmpty) {
      try { await BleAutoPairStore.save(mac); } catch (_) {}
    }

    // 서버 EQ 행 생성(없으면 업로드가 계속 막힌다). 실패해도 로컬 등록은 유지.
    bool uploaded = false;
    String serverNote = '';
    try {
      uploaded = await SettingsService().upsertEqStart(serial: eqsn, startAt: start.toUtc());
    } catch (e) {
      serverNote = '$e';
    }

    await SensorExpiryService().resetPromptHistory();
    final SensorExpiryStatus? s = await SensorExpiryService().evaluate();
    return jsonEncode(<String, dynamic>{
      'eqsn': eqsn,
      'startAt': SensorUsage.formatStartLocal(start),
      'serverEqUpserted': uploaded,
      if (serverNote.isNotEmpty) 'serverError': serverNote,
      'blePairSaved': mac.isNotEmpty,
      'expiryState': s?.state.name ?? 'none',
      'remain': s == null ? null : SensorUsage.formatRemainHm(s.remaining),
    });
  }

  static Future<String> _setStart(Map<String, dynamic> args) async {
    final String iso = (args['startAtUtc'] ?? '').toString();
    final DateTime? t = DateTime.tryParse(iso);
    if (t == null) return 'ERR bad startAtUtc: $iso';
    final String eqsn = (args['eqsn'] ?? '').toString();
    await SettingsStorage.save(<String, dynamic>{
      'sensorStartAt': t.toUtc().toIso8601String(),
      if (eqsn.isNotEmpty) 'eqsn': eqsn,
      if (eqsn.isNotEmpty) 'sensorStartAtEqsn': eqsn,
    });
    await SensorExpiryService().resetPromptHistory();
    await SensorExpiryService().evaluate();
    return jsonEncode(SensorExpiryService().debugSnapshot());
  }

  static Future<Map<String, dynamic>> _dump() async {
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String eqsn = (st['eqsn'] as String? ?? '');
    final GlucoseLocalRepo repo = GlucoseLocalRepo();
    return <String, dynamic>{
      'expiry': SensorExpiryService().debugSnapshot(),
      'eqsn': eqsn,
      'sensorStartAt': st['sensorStartAt'],
      'lastTrid': st['lastTrid'],
      'lastServerUploadedTrid': st['lastServerUploadedTrid'],
      'lastCgmOffsetMin': st['lastCgmOffsetMin'],
      'cgmSessionBaseMs': st['cgmSessionBaseMs'],
      'dbMaxTridBle': await repo.maxTrid(eqsn: eqsn, src: GlucoseSrc.ble),
      'dbMaxTridSrv': await repo.maxTrid(eqsn: eqsn, src: GlucoseSrc.server),
      'dbCount': await repo.count(),
      'droppedInserts': repo.droppedInserts,
      'lastDropInfo': repo.lastDropInfo,
      'migrationDroppedRows': lastMigrationDroppedRows,
      'uploadWatermark': await IngestQueueService.readLastServerUploadedTrid(),
      'validityDays': AppConstants.defaultSensorValidityDays,
    };
  }

  /// 고객 리포트("측정값이 갱신되지 않음")를 만들던 경로들을 실제 로컬 DB에 재현해
  /// 수정 후 동작을 확인한다. 각 항목은 `expect`(기대)와 `actual`(실측)을 함께 남긴다.
  static Future<Map<String, dynamic>> _selfTest() async {
    const String eqsn = 'QA_SELFTEST';
    final GlucoseLocalRepo repo = GlucoseLocalRepo();
    final int dropBefore = repo.droppedInserts;
    // 재실행 가능하도록 이전 회차 흔적 제거.
    await repo.clearForEqsn(eqsn);

    final DateTime t0 = DateTime.now().subtract(const Duration(minutes: 30));
    final DateTime t1 = t0.add(const Duration(minutes: 5));

    // ① 신규 판독은 저장된다.
    final bool first = await repo.addPoint(time: t0, value: 101, trid: 7, eqsn: eqsn);

    // ② 같은 (센서, 측정시각) 재수신은 중복 → 저장되지 않지만 **집계·로그로 드러난다**
    //    (예전에는 예외도 로그도 없이 사라져 "그냥 갱신 안 됨"으로만 보였다).
    final bool dup = await repo.addPoint(time: t0, value: 101, trid: 7, eqsn: eqsn);

    // ③ trid 가 겹쳐도 시각이 다르면 저장된다 — 이것이 고객 증상의 핵심 수정점.
    //    (구버전 UNIQUE(trid,eqsn) 에서는 trid 재사용 시 신규 판독이 영구 폐기됐다)
    final bool sameTridNewTime =
        await repo.addPoint(time: t1, value: 133, trid: 7, eqsn: eqsn);

    // ④ 서버에서 내려온 과거 행은 기기 워터마크를 밀어 올리지 않는다.
    final int bleMaxBefore = await repo.maxTrid(eqsn: eqsn, src: GlucoseSrc.ble);
    await repo.addPoint(
      time: t1.add(const Duration(minutes: 5)),
      value: 120,
      trid: 60000,
      eqsn: eqsn,
      src: GlucoseSrc.server,
    );
    final int bleMaxAfter = await repo.maxTrid(eqsn: eqsn, src: GlucoseSrc.ble);
    final int srvMax = await repo.maxTrid(eqsn: eqsn, src: GlucoseSrc.server);

    final int dropDelta = repo.droppedInserts - dropBefore;
    final List<Map<String, dynamic>> checks = <Map<String, dynamic>>[
      _check('신규 판독 저장', true, first),
      _check('동일 (센서,시각) 중복 → 저장 안 됨', false, dup),
      _check('중복 폐기가 카운터에 집계됨(무음 폐기 아님)', 1, dropDelta),
      _check('trid 중복이어도 시각이 다르면 저장됨', true, sameTridNewTime),
      _check('서버 행(trid=60000)이 기기 워터마크를 올리지 않음', bleMaxBefore, bleMaxAfter),
      _check('서버 행은 srv 워터마크에만 반영', 60000, srvMax),
    ];
    await repo.clearForEqsn(eqsn);

    return <String, dynamic>{
      'pass': checks.every((Map<String, dynamic> c) => c['pass'] == true),
      'checks': checks,
    };
  }

  static Map<String, dynamic> _check(String name, Object? expect, Object? actual) =>
      <String, dynamic>{
        'name': name,
        'expect': '$expect',
        'actual': '$actual',
        'pass': '$expect' == '$actual',
      };

  static Future<List<Map<String, dynamic>>> _dbGroups() async {
    final db = await LocalDb().db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT eqsn, src, MIN(trid) AS min_trid, MAX(trid) AS max_trid, '
      'COUNT(*) AS c, MAX(time_ms) AS max_time '
      'FROM glucose_points GROUP BY eqsn, src ORDER BY max_time DESC',
    );
    return rows.map((Map<String, Object?> r) => <String, dynamic>{
          'eqsn': r['eqsn'],
          'src': r['src'],
          'minTrid': r['min_trid'],
          'maxTrid': r['max_trid'],
          'count': r['c'],
          'maxTime': (r['max_time'] is num)
              ? DateTime.fromMillisecondsSinceEpoch((r['max_time'] as num).toInt(),
                      isUtc: true)
                  .toLocal()
                  .toIso8601String()
              : null,
        }).toList();
  }

  static int _int(Object? v, int fallback) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }
}
