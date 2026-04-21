import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/global_loading.dart';
import 'package:helpcare/core/utils/notification_service.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/passcode.dart';
import 'package:helpcare/core/utils/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 디바이스(앱) 내부에서 도는 간단한 HTTP 서버.
/// Node 테스트 툴이 이 서버를 호출해 BLE notify 경로를 "직접 호출"한다.
///
/// 권장 연결(PC -> 디바이스):
/// - PC: `adb forward tcp:18789 tcp:<devicePort>`
/// - Node: `http://127.0.0.1:18789/...` 로 호출
class BleEmuServer {
  BleEmuServer._();
  static HttpServer? _server;

  static int get port => 8788;
  static int? get boundPort => _server?.port;

  static Future<void> maybeStart({int? bindPort}) async {
    // QA 자동화는 debug/profile에서 모두 필요. release에서만 비활성.
    if (kReleaseMode) return;
    // Web: dart:io HttpServer / InternetAddress 미지원
    if (kIsWeb) return;
    if (_server != null) return;
    final int base = bindPort ?? port;
    // 에뮬레이터/호스트 환경 차이 대응:
    // - anyIPv4 우선
    // - 실패 시 anyIPv6 / loopbackIPv4 순으로 폴백
    final List<InternetAddress> bindAddrs = <InternetAddress>[
      InternetAddress.anyIPv4,
      InternetAddress.anyIPv6,
      InternetAddress.loopbackIPv4,
    ];
    // 포트 충돌이 잦아 base~base+10까지 시도
    for (int p = base; p <= base + 10; p++) {
      for (final InternetAddress addr in bindAddrs) {
        try {
          final s = await HttpServer.bind(addr, p);
          _server = s;
          // ignore: avoid_print
          print('[EMU] BleEmuServer started on ${addr.address}:$p');
          unawaited(BleLogService().add('EMU', 'BleEmuServer started on ${addr.address}:$p'));
          s.listen(_handle);
          return;
        } catch (e) {
          // ignore: avoid_print
          print('[EMU] BleEmuServer bind failed on ${addr.address}:$p: $e');
          unawaited(BleLogService().add('EMU', 'BleEmuServer bind failed on ${addr.address}:$p: $e'));
        }
      }
    }
  }

  static Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }

  static Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/health') {
        return _json(req, 200, {'ok': true, 'service': 'ble-emu', 'port': (_server?.port ?? port)});
      }

      if (req.method == 'POST' && path == '/emu/cgms/notify') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String? hex = (j['hex'] as String?)?.trim();
        final List<int> bytes = hex != null && hex.isNotEmpty ? _parseHex(hex) : _parseBytes(j['bytes']);
        if (bytes.isEmpty) return _json(req, 400, {'ok': false, 'error': 'no bytes'});
        await BleService().debugInjectCgmsNotifyBytes(bytes, silent: (j['silent'] == true));
        return _json(req, 200, {'ok': true, 'len': bytes.length});
      }

      if (req.method == 'POST' && path == '/emu/cgms/value') {
        // 고수준 주입(편의): 실제 저장 경로는 동일, 다만 BLE 파서(2AA7)는 타지 않음
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final num? v = j['value'] as num?;
        if (v == null) return _json(req, 400, {'ok': false, 'error': 'missing value'});
        BleService().simulateNotify(v.toDouble());
        return _json(req, 200, {'ok': true, 'value': v});
      }

      if (req.method == 'POST' && path == '/emu/app/apiBase') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String baseUrl = (j['baseUrl'] as String? ?? '').trim();
        if (baseUrl.isEmpty) return _json(req, 400, {'ok': false, 'error': 'missing baseUrl'});
        final s = await SettingsStorage.load();
        s['apiBaseUrl'] = baseUrl;
        await SettingsStorage.save(s);
        ApiClient.invalidateBaseCache();
        return _json(req, 200, {'ok': true, 'apiBaseUrl': baseUrl});
      }

      if (req.method == 'GET' && path == '/emu/app/apiBase') {
        final s = await SettingsStorage.load();
        final String baseUrl = (s['apiBaseUrl'] as String? ?? '').trim();
        return _json(req, 200, {'ok': true, 'apiBaseUrl': baseUrl});
      }

      if (req.method == 'POST' && path == '/emu/app/session') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String token = (j['token'] as String? ?? '').trim();
        final String userId = (j['userId'] as String? ?? '').trim();
        final String eqsn = (j['eqsn'] as String? ?? 'LOCAL').trim();
        final String startAt = (j['sensorStartAt'] as String? ?? DateTime.now().toUtc().toIso8601String()).trim();
        if (token.isEmpty) return _json(req, 400, {'ok': false, 'error': 'missing token'});
        await ApiClient().saveToken(token);
        final s = await SettingsStorage.load();
        s['guestMode'] = false;
        s['lastUserId'] = userId;
        s['eqsn'] = eqsn;
        s['sensorStartAt'] = startAt;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'userId': userId, 'eqsn': eqsn, 'sensorStartAt': startAt});
      }

      if (req.method == 'POST' && path == '/emu/app/logTx') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final int maxLines = (j['maxLines'] as num?)?.toInt() ?? 80;

        final DateTime now = DateTime.now();
        final List<String> logs = await BleLogService().snapshot(limit: maxLines.clamp(10, 300));
        final s = await SettingsStorage.load();
        final String eqsn = (s['eqsn'] as String? ?? '').trim();
        final String userId = (s['lastUserId'] as String? ?? '').trim();
        final String lang = (s['language'] as String? ?? '').trim();
        final String region = (s['region'] as String? ?? '').trim();
        final String timeFormat = (s['timeFormat'] as String? ?? '').trim();
        final String unit = (s['glucoseUnit'] as String? ?? '').trim();
        final String apiBase = (s['apiBaseUrl'] as String? ?? '').trim();

        final String memo = [
          '[log_tx]',
          'time=${now.toUtc().toIso8601String()}',
          if (userId.isNotEmpty) 'userId=$userId',
          if (eqsn.isNotEmpty) 'eqsn=$eqsn',
          if (apiBase.isNotEmpty) 'apiBase=$apiBase',
          if (lang.isNotEmpty) 'lang=$lang',
          if (region.isNotEmpty) 'region=$region',
          if (timeFormat.isNotEmpty) 'timeFormat=$timeFormat',
          if (unit.isNotEmpty) 'unit=$unit',
          'globalLoading=${GlobalLoading.activeCount.value}',
          '--- ble_logs (latest ${logs.length}) ---',
          ...logs,
        ].join('\n');

        bool ok = false;
        try {
          // backend 이벤트 타입 enum 제한이 있어, memo 타입으로 전송하고 본문에 tag를 포함한다.
          ok = await DataService().postEvent(type: 'memo', time: now, memo: memo);
        } catch (_) {
          ok = false;
        }

        final ss = await SettingsStorage.load();
        ss['lastLogTxAt'] = now.toUtc().toIso8601String();
        ss['lastLogTxOk'] = ok;
        await SettingsStorage.save(ss);

        return _json(req, 200, {'ok': true, 'uploaded': ok, 'at': ss['lastLogTxAt'], 'lines': logs.length});
      }

      if (req.method == 'POST' && path == '/emu/app/lockscreen/glucose') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final num? v = j['value'] as num?;
        final String trend = (j['trend'] as String? ?? '').trim();
        final String unit = (j['unit'] as String? ?? 'mg/dL').trim();
        if (v == null) return _json(req, 400, {'ok': false, 'error': 'missing value'});
        try {
          await NotificationService().showLockScreenGlucose(value: v.toDouble(), trend: trend, unit: unit.isEmpty ? 'mg/dL' : unit);
          final s = await SettingsStorage.load();
          return _json(req, 200, {
            'ok': true,
            'at': (s['lastLockScreenAt'] as String? ?? '').trim(),
            'value': s['lastLockScreenValue'],
            'trend': (s['lastLockScreenTrend'] as String? ?? '').trim(),
          });
        } catch (e) {
          final s = await SettingsStorage.load();
          s['lastLockScreenAt'] = DateTime.now().toUtc().toIso8601String();
          s['lastLockScreenOk'] = false;
          await SettingsStorage.save(s);
          return _json(req, 500, {'ok': false, 'error': 'notify_failed'});
        }
      }

      // sensors (ST_03_01)
      if (req.method == 'GET' && path == '/emu/app/sensors') {
        try {
          final list = await SettingsService().listSensors();
          return _json(req, 200, {'ok': true, 'items': list, 'count': list.length});
        } catch (e) {
          return _json(req, 500, {'ok': false, 'error': 'list_failed'});
        }
      }

      // alarms (AR_01_xx) - 서버 체크용
      if (req.method == 'GET' && path == '/emu/app/alarms') {
        try {
          final list = await SettingsService().listAlarms();
          return _json(req, 200, {'ok': true, 'items': list, 'count': list.length});
        } catch (e) {
          return _json(req, 500, {'ok': false, 'error': 'list_failed'});
        }
      }

      if (req.method == 'POST' && path == '/emu/app/sensors') {
        try {
          final body = await utf8.decoder.bind(req).join();
          final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
          final created = await SettingsService().createSensor(j);
          if (created == null) return _json(req, 500, {'ok': false, 'error': 'create_failed'});
          return _json(req, 200, {'ok': true, 'sensor': created});
        } catch (_) {
          return _json(req, 500, {'ok': false, 'error': 'create_failed'});
        }
      }

      if (req.method == 'POST' && path == '/emu/app/sensors/clear') {
        // best-effort: delete all
        int deleted = 0;
        try {
          final list = await SettingsService().listSensors();
          for (final it in list) {
            final id = (it['_id'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            try {
              final ok = await SettingsService().deleteSensor(id);
              if (ok) deleted++;
            } catch (_) {}
          }
          return _json(req, 200, {'ok': true, 'deleted': deleted});
        } catch (_) {
          return _json(req, 500, {'ok': false, 'error': 'clear_failed', 'deleted': deleted});
        }
      }

      // LO_01_05: easy passcode
      if (req.method == 'POST' && path == '/emu/app/passcode/set') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String code = (j['code'] as String? ?? '').trim();
        final bool enabled = j['enabled'] != false;
        if (!Passcode.isValid(code)) return _json(req, 400, {'ok': false, 'error': 'invalid_code'});
        final s = await SettingsStorage.load();
        s['passcodeEnabled'] = enabled;
        s['passcodeHash'] = Passcode.hash(code);
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'passcodeEnabled': enabled});
      }

      if (req.method == 'POST' && path == '/emu/app/passcode/clear') {
        final s = await SettingsStorage.load();
        s['passcodeEnabled'] = false;
        s['passcodeHash'] = '';
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'passcodeEnabled': false});
      }

      if (req.method == 'POST' && path == '/emu/app/passcode/check') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String code = (j['code'] as String? ?? '').trim();
        if (!Passcode.isValid(code)) return _json(req, 400, {'ok': false, 'error': 'invalid_code'});
        final s = await SettingsStorage.load();
        final bool enabled = s['passcodeEnabled'] == true;
        final String stored = (s['passcodeHash'] as String? ?? '').trim();
        final bool ok = enabled && stored.isNotEmpty && stored == Passcode.hash(code);
        return _json(req, 200, {'ok': ok, 'passcodeEnabled': enabled});
      }

      // LO_03_01: passcode reset with member info (login check)
      if (req.method == 'POST' && path == '/emu/app/passcode/reset') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String email = (j['email'] as String? ?? '').trim();
        final String password = (j['password'] as String? ?? '').toString();

        // debug override (bot convenience)
        final bool force = j['force'] == true;
        if (force && kDebugMode) {
          final s = await SettingsStorage.load();
          s['passcodeEnabled'] = false;
          s['passcodeHash'] = '';
          await SettingsStorage.save(s);
          return _json(req, 200, {'ok': true, 'forced': true});
        }

        if (email.isEmpty || password.isEmpty) {
          return _json(req, 400, {'ok': false, 'error': 'missing_member_info'});
        }
        try {
          // NOTE: ApiClient가 base override를 사용 중이면 그 base로 호출된다.
          final r = await ApiClient().post('/api/auth/login', body: {'email': email, 'password': password});
          if (r.statusCode != 200) return _json(req, 401, {'ok': false, 'error': 'invalid_member'});
        } catch (_) {
          return _json(req, 500, {'ok': false, 'error': 'login_check_failed'});
        }

        final s = await SettingsStorage.load();
        s['passcodeEnabled'] = false;
        s['passcodeHash'] = '';
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true});
      }

      // SC_01_01: consent + alarm range
      if (req.method == 'POST' && path == '/emu/app/sc0101') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final bool consent = j['consent'] == true;
        final int low = ((j['low'] as num?)?.toInt() ?? 70).clamp(40, 120);
        final int high = ((j['high'] as num?)?.toInt() ?? 180).clamp(120, 300);
        final s = await SettingsStorage.load();
        s['sc0101Consent'] = consent;
        s['sc0101Low'] = low;
        s['sc0101High'] = high;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'consent': consent, 'low': low, 'high': high});
      }

      if (req.method == 'GET' && path == '/emu/app/sc0101') {
        final s = await SettingsStorage.load();
        final bool consent = s['sc0101Consent'] == true;
        final int low = ((s['sc0101Low'] as num?)?.toInt() ?? 70).clamp(40, 120);
        final int high = ((s['sc0101High'] as num?)?.toInt() ?? 180).clamp(120, 300);
        return _json(req, 200, {'ok': true, 'consent': consent, 'low': low, 'high': high});
      }

      // SC_01_02: re-register after logout (automation helpers)
      if (req.method == 'POST' && path == '/emu/app/devices/set') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final List<dynamic> list = (j['registeredDevices'] as List<dynamic>? ?? const <dynamic>[]);
        final s = await SettingsStorage.load();
        s['registeredDevices'] = list;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'count': list.length});
      }

      if (req.method == 'POST' && path == '/emu/app/logout') {
        final s = await SettingsStorage.load();
        s['authToken'] = '';
        s['guestMode'] = false;
        await SettingsStorage.save(s);
        ApiClient().saveToken(''); // clear runtime token cache
        // keep registeredDevices (re-register flow)
        final List<dynamic> list = (s['registeredDevices'] as List<dynamic>? ?? const <dynamic>[]);
        final bool hasDevice = list.isNotEmpty;
        if (hasDevice) {
          await AppNav.goNamed('/sc/01/02', replaceStack: true);
        } else {
          await AppNav.goNamed('/login', replaceStack: true);
        }
        return _json(req, 200, {'ok': true, 'hasDevice': hasDevice, 'route': AppNav.route});
      }

      // SC_01_05: manual SN register (automation helper)
      if (req.method == 'POST' && path == '/emu/app/sc0105/manualSn') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String sn = (j['sn'] as String? ?? '').trim();
        final bool valid = RegExp(r'^\d{5}$').hasMatch(sn);
        if (!valid) return _json(req, 400, {'ok': false, 'error': 'invalid_sn'});
        final s = await SettingsStorage.load();
        final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
        list.add({
          'id': 'SN-${DateTime.now().millisecondsSinceEpoch}',
          'sn': sn,
          'model': '',
          'year': '',
          'sampleFlag': '',
          'registeredAt': DateTime.now().toIso8601String(),
          'source': 'manual_sn',
        });
        s['registeredDevices'] = list;
        s['sc0105ManualSnAt'] = DateTime.now().toUtc().toIso8601String();
        s['sc0105ManualSnValue'] = sn;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'sn': sn, 'count': list.length});
      }

      // SC_01_04: QR 스캔 성공 시뮬레이션 (QA/봇용). 등록 기기 + eqsn 설정 후 BLE 스캔 화면으로 이동 가능.
      if (req.method == 'POST' && path == '/emu/app/sc0104/qrSuccess') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String fullSn = (j['fullSn'] as String? ?? 'C21ZS00033').trim().toUpperCase();
        final String serial = (j['serial'] as String? ?? '00033').trim();
        final String model = (j['model'] as String? ?? 'C21').trim();
        final String year = (j['year'] as String? ?? '2025').trim();
        final String sampleFlag = (j['sampleFlag'] as String? ?? '').trim();
        final s = await SettingsStorage.load();
        final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
        list.add({
          'id': 'QR-${DateTime.now().millisecondsSinceEpoch}',
          'sn': serial,
          'fullSn': fullSn,
          'model': model,
          'year': year,
          'sampleFlag': sampleFlag,
          'registeredAt': DateTime.now().toIso8601String(),
        });
        s['registeredDevices'] = list;
        s['eqsn'] = fullSn;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'fullSn': fullSn, 'serial': serial, 'count': list.length});
      }

      // SC_01_06: warm-up (30min countdown) automation helper
      if (req.method == 'POST' && path == '/emu/app/sc0106/start') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final int seconds = ((j['seconds'] as num?)?.toInt() ?? (30 * 60)).clamp(10, 4 * 60 * 60);
        final DateTime now = DateTime.now().toUtc();
        final DateTime ends = now.add(Duration(seconds: seconds));
        final s = await SettingsStorage.load();
        s['sc0106WarmupStartAt'] = now.toIso8601String();
        s['sc0106WarmupEndsAt'] = ends.toIso8601String();
        s['sc0106WarmupActive'] = true;
        s['sc0106WarmupDoneAt'] = '';
        await SettingsStorage.save(s);
        await AppNav.goNamed('/sc/01/06', replaceStack: true);
        return _json(req, 200, {'ok': true, 'seconds': seconds, 'route': AppNav.route});
      }

      // SC_01_03: NFC scan guide (automation helper)
      if (req.method == 'POST' && path == '/emu/app/sc0103') {
        final s = await SettingsStorage.load();
        s['sc0103ViewedAt'] = DateTime.now().toUtc().toIso8601String();
        await SettingsStorage.save(s);
        await AppNav.goNamed('/sc/01/03', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // SC_06_02: QR reconnect guide (automation helper)
      if (req.method == 'POST' && path == '/emu/app/sc0602') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String reason = (j['reason'] as String? ?? '').trim();
        final s = await SettingsStorage.load();
        s['sc0602ViewedAt'] = DateTime.now().toUtc().toIso8601String();
        if (reason.isNotEmpty) s['sc0602Reason'] = reason;
        await SettingsStorage.save(s);
        await AppNav.goNamed('/sc/06/02', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // LO_01_01: login page SNS options (automation helper)
      // - openSheet=true 이면 LoginChoiceScreen 진입 시 Easy Login 시트를 자동으로 띄운다.
      if (req.method == 'POST' && path == '/emu/app/lo0101') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final bool openSheet = j['openSheet'] != false;
        final bool navigate = j['navigate'] == true;
        try {
          final s = await SettingsStorage.load();
          s['lo0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          s['lo0101AutoOpenEasyLoginSheet'] = openSheet;
          // clear previous marker for clean QA wait
          s['lo0101SheetOpenedAt'] = '';
          await SettingsStorage.save(s);
        } catch (_) {}
        if (navigate) {
          await AppNav.goNamed('/login', replaceStack: true);
        }
        return _json(req, 200, {'ok': true, 'route': AppNav.route, 'openSheet': openSheet, 'navigate': navigate});
      }

      // LO_01_08: guest mode entry (automation helper)
      if (req.method == 'POST' && path == '/emu/app/lo0108') {
        try {
          final s = await SettingsStorage.load();
          s['guestMode'] = true;
          s['authToken'] = '';
          s['lastUserId'] = '';
          s['lo0108EnteredAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
          try { AppSettingsBus.notify(); } catch (_) {}
        } catch (_) {}
        await AppNav.goNamed('/home', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route, 'guestMode': true});
      }

      // LO_01_02~04: SNS provider login process screens (automation helper)
      if (req.method == 'POST' && path == '/emu/app/lo0102') {
        try {
          final s = await SettingsStorage.load();
          s['lo0102ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/01/02', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/lo0103') {
        try {
          final s = await SettingsStorage.load();
          s['lo0103ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/01/03', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/lo0104') {
        try {
          final s = await SettingsStorage.load();
          s['lo0104ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/01/04', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // LO_02_01/03/05: sign-up flow screens (automation helper)
      if (req.method == 'POST' && path == '/emu/app/lo0201') {
        try {
          final s = await SettingsStorage.load();
          s['lo0201ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          s['lo0201Choice'] = (jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>)['choice']?.toString() ?? '';
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/02/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/lo0203') {
        try {
          final body = await utf8.decoder.bind(req).join();
          final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
          final s = await SettingsStorage.load();
          s['lo0203ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          if (j.containsKey('phone')) s['lo0203Phone'] = (j['phone'] as String? ?? '').trim();
          if (j['verified'] == true) s['lo0203VerifiedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/02/04', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/lo0205') {
        try {
          final s = await SettingsStorage.load();
          s['lo0205ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/02/05', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // SC_02_01/04_01/05_01/08_01: sensor pages evidence + navigation helpers
      if (req.method == 'POST' && path == '/emu/app/sc0201') {
        try {
          final st = await SettingsStorage.load();
          st['sc0201ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          st['sc0201RenderedAt'] = '';
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/02/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/sc0301') {
        try {
          final st = await SettingsStorage.load();
          st['sc0301ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/03/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/sc0401') {
        try {
          final st = await SettingsStorage.load();
          st['sc0401ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/04/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/sc0501') {
        try {
          final st = await SettingsStorage.load();
          st['sc0501ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/05/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/sc0601') {
        try {
          final st = await SettingsStorage.load();
          st['sc0601ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/06/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/sc0801') {
        try {
          final st = await SettingsStorage.load();
          st['sc0801ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/sc/08/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // GU_01_01~03: main screen glucose value/trend/color (automation helper)
      if (req.method == 'POST' && path == '/emu/app/gu0101') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final List<dynamic> values = (j['values'] as List<dynamic>? ?? const <dynamic>[]);
        try {
          // QA reliability: clear local points so "latest" is deterministic
          try {
            await GlucoseLocalRepo().clear();
          } catch (_) {}
          final stTr = await SettingsStorage.load();
          int trid = (stTr['lastTrid'] as int? ?? 0);
          double? first;
          double? last;
          final DateTime baseTime = DateTime.now();
          int idx = 0;
          for (final v in values) {
            final num? n = v is num ? v : num.tryParse(v.toString());
            if (n == null) continue;
            final double dv = n.toDouble();
            first ??= dv;
            last = dv;
            // emulate: enqueue into the same ingest path (local repo + UI bus + backend sync)
            trid = (trid + 1) & 0xFFFF;
            // ensure distinct timestamps (repo may dedupe identical time)
            final DateTime t = baseTime.add(Duration(seconds: idx));
            idx++;
            IngestQueueService().enqueueGlucose(t, dv, trid: trid);
          }
          stTr['lastTrid'] = trid;
          await SettingsStorage.save(stTr);
          // best-effort evidence snapshot for bot verification
          if (last != null) {
            final st = await SettingsStorage.load();
            st['gu0101RenderedAt'] = DateTime.now().toUtc().toIso8601String();
            st['gu0101Value'] = last.round();
            st['gu0102Trend'] = (first != null && last > first)
                ? 'upFast'
                : ((first != null && last < first) ? 'downFast' : 'flat');
            st['gu0103Color'] = (last >= 180) ? 'high' : ((last <= 70) ? 'low' : 'in');
            await SettingsStorage.save(st);
          }
        } catch (_) {}
        await AppNav.goNamed('/gu/01/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route, 'count': values.length});
      }

      // TG_01_01~02: trend portrait/landscape (automation helper)
      if (req.method == 'POST' && path == '/emu/app/tg0101') {
        try {
          final st = await SettingsStorage.load();
          st['tg0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/tg/01/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/tg0102') {
        try {
          final st = await SettingsStorage.load();
          st['tg0102ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/tg/01/02', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // RP_01_01: report screen (automation helper)
      if (req.method == 'POST' && path == '/emu/app/rp0101') {
        try {
          final st = await SettingsStorage.load();
          st['rp0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          st['rp0101RenderedAt'] = '';
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/rp/01/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // ME_01_01: event editor popup (automation helper)
      if (req.method == 'POST' && path == '/emu/app/me0101') {
        try {
          final st = await SettingsStorage.load();
          st['me0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/me/01/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/me0101/foodshot') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String asset = (j['asset'] as String? ?? 'assets/images/img_rectangle104.png').trim();
        try {
          final st = await SettingsStorage.load();
          st['me0101FoodShotAt'] = DateTime.now().toUtc().toIso8601String();
          st['me0101FoodShotAsset'] = asset;
          await SettingsStorage.save(st);
        } catch (_) {}
        return _json(req, 200, {'ok': true, 'asset': asset});
      }

      // PD_01_01: previous data view screen seed + navigation helper
      if (req.method == 'POST' && path == '/emu/app/pd0101/seed') {
        // seed 2 sensor ranges similar to ppt example
        try {
          await GlucoseLocalRepo().clear();
        } catch (_) {}
        try {
          final now = DateTime.now().toUtc();
          // Sensor2: last N days (AppConstants)
          final DateTime s2From = now.subtract(Duration(days: AppConstants.defaultSensorValidityDays));
          final DateTime s2To = now.subtract(const Duration(days: 1));
          // Sensor1: older 21~15 days ago
          final DateTime s1From = now.subtract(const Duration(days: 21));
          final DateTime s1To = now.subtract(const Duration(days: 15));

          Future<void> seedEq(String eqsn, DateTime from, DateTime to, {int stepMin = 30}) async {
            final List<DateTime> times = <DateTime>[];
            final List<double> values = <double>[];
            final List<int?> trids = <int?>[];
            int trid = 1;
            for (DateTime t = from; t.isBefore(to); t = t.add(Duration(minutes: stepMin))) {
              times.add(t);
              // simple oscillation 80~180
              final double v = 120 + 40 * (math.sin(times.length / 10.0));
              values.add(v);
              trids.add(trid);
              trid = (trid % 65535) + 1;
            }
            await GlucoseLocalRepo().addPointsBatch(times: times, values: values, trids: trids, eqsn: eqsn);
          }

          await seedEq('C21ZS00102', s2From, s2To);
          await seedEq('C21ZS00101', s1From, s1To);

          final st = await SettingsStorage.load();
          st['pd0101RefreshedAt'] = DateTime.now().toUtc().toIso8601String();
          // count will be updated by screen reload as well; set a hint here
          st['pd0101ItemsCount'] = 2;
          await SettingsStorage.save(st);
          return _json(req, 200, {'ok': true, 'seeded': 2});
        } catch (e) {
          return _json(req, 500, {'ok': false, 'error': e.toString()});
        }
      }
      if (req.method == 'POST' && path == '/emu/app/pd0101') {
        // seed (best-effort) then navigate
        try {
          // call handler logic directly
          await GlucoseLocalRepo().clear();
        } catch (_) {}
        // reuse seed endpoint logic by inlining minimal
        try {
          final now = DateTime.now().toUtc();
          final DateTime s2From = now.subtract(Duration(days: AppConstants.defaultSensorValidityDays));
          final DateTime s2To = now.subtract(const Duration(days: 1));
          final DateTime s1From = now.subtract(const Duration(days: 21));
          final DateTime s1To = now.subtract(const Duration(days: 15));
          Future<void> seedEq(String eqsn, DateTime from, DateTime to, {int stepMin = 30}) async {
            final List<DateTime> times = <DateTime>[];
            final List<double> values = <double>[];
            final List<int?> trids = <int?>[];
            int trid = 1;
            for (DateTime t = from; t.isBefore(to); t = t.add(Duration(minutes: stepMin))) {
              times.add(t);
              final double v = 120 + 40 * (math.sin(times.length / 10.0));
              values.add(v);
              trids.add(trid);
              trid = (trid % 65535) + 1;
            }
            await GlucoseLocalRepo().addPointsBatch(times: times, values: values, trids: trids, eqsn: eqsn);
          }
          await seedEq('C21ZS00102', s2From, s2To);
          await seedEq('C21ZS00101', s1From, s1To);
        } catch (_) {}
        try {
          final st = await SettingsStorage.load();
          st['pd0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          st['pd0101RefreshedAt'] = DateTime.now().toUtc().toIso8601String();
          st['pd0101ItemsCount'] = 2;
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/pd/01/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // LO_02_02/04: sign-up terms + user info (automation helper)
      if (req.method == 'POST' && path == '/emu/app/lo0202') {
        try {
          final st = await SettingsStorage.load();
          st['lo0202ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/lo/02/02', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }
      if (req.method == 'POST' && path == '/emu/app/lo0204') {
        try {
          final st = await SettingsStorage.load();
          st['lo0204ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(st);
        } catch (_) {}
        await AppNav.goNamed('/lo/02/04', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // LO_01_07: sensor registration check (automation helper)
      if (req.method == 'POST' && path == '/emu/app/lo0107') {
        try {
          final s = await SettingsStorage.load();
          s['lo0107ViewedAt'] = DateTime.now().toUtc().toIso8601String();
          await SettingsStorage.save(s);
        } catch (_) {}
        await AppNav.goNamed('/lo/01/07', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // SC_07_01: data share prefs (automation helper)
      if (req.method == 'POST' && path == '/emu/app/sc0701') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final s = await SettingsStorage.load();
        if (j.containsKey('enabled')) s['sc0701Enabled'] = (j['enabled'] == true);
        if (j.containsKey('preset')) s['sc0701Preset'] = (j['preset'] as String? ?? 'Custom').trim();
        if (j.containsKey('from')) s['sc0701From'] = (j['from'] as String? ?? '').trim();
        if (j.containsKey('to')) s['sc0701To'] = (j['to'] as String? ?? '').trim();
        if (j.containsKey('itemSummary')) s['sc0701ItemSummary'] = (j['itemSummary'] == true);
        if (j.containsKey('itemDistribution')) s['sc0701ItemDistribution'] = (j['itemDistribution'] == true);
        if (j.containsKey('itemGraph')) s['sc0701ItemGraph'] = (j['itemGraph'] == true);
        if (j.containsKey('itemUserProfile')) s['sc0701ItemUserProfile'] = (j['itemUserProfile'] == true);
        if (j.containsKey('methodEmail')) s['sc0701MethodEmail'] = (j['methodEmail'] == true);
        if (j.containsKey('methodSms')) s['sc0701MethodSms'] = (j['methodSms'] == true);
        if (j.containsKey('format')) s['sc0701Format'] = (j['format'] as String? ?? 'PDF').trim();
        if (j.containsKey('revocable')) s['sc0701Revocable'] = (j['revocable'] == true);
        // if range is empty, fill from preset (evidence-friendly)
        final String preset = (s['sc0701Preset'] as String? ?? 'Custom').trim();
        String from = (s['sc0701From'] as String? ?? '').trim();
        String to = (s['sc0701To'] as String? ?? '').trim();
        if (from.isEmpty || to.isEmpty) {
          final now = DateTime.now();
          final end = DateTime(now.year, now.month, now.day);
          int days = 7;
          if (preset == '1D') days = 1;
          if (preset == '7D') days = 7;
          if (preset == '30D') days = 30;
          final start = end.subtract(Duration(days: days - 1));
          from = start.toIso8601String();
          to = end.toIso8601String();
          s['sc0701From'] = from;
          s['sc0701To'] = to;
          // legacy keys too
          s['shareFrom'] = from;
          s['shareTo'] = to;
          s['shareRange'] = days.toString();
          s['shareConsent'] = true;
        }
        // evidence helper
        s['sc0701ViewedAt'] = DateTime.now().toUtc().toIso8601String();
        // clear render marker (qa-bot will wait for it after nav)
        s['sc0701RenderedAt'] = '';
        await SettingsStorage.save(s);
        await AppNav.goNamed('/sc/07/01', replaceStack: true);
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      // LO_02_06 / LO_01_06: biometric settings (debug/bot)
      if (req.method == 'POST' && path == '/emu/app/biometric') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final bool enabled = j['enabled'] == true;
        final s = await SettingsStorage.load();
        s['biometricEnabled'] = enabled;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'biometricEnabled': enabled});
      }

      if (req.method == 'POST' && path == '/emu/app/biometric/bypass') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final bool enabled = j['enabled'] == true;
        final s = await SettingsStorage.load();
        s['biometricDebugBypass'] = enabled;
        await SettingsStorage.save(s);
        return _json(req, 200, {'ok': true, 'biometricDebugBypass': enabled});
      }

      if (req.method == 'GET' && path == '/emu/app/biometric') {
        final s = await SettingsStorage.load();
        final bool enabled = s['biometricEnabled'] == true;
        final bool bypass = s['biometricDebugBypass'] == true;
        final bool canCheck = await BiometricService().canCheck();
        return _json(req, 200, {'ok': true, 'biometricEnabled': enabled, 'biometricDebugBypass': bypass, 'canCheck': canCheck});
      }

      // alarms (ST_04_01)
      if (req.method == 'GET' && path == '/emu/app/alarms') {
        try {
          final list = await SettingsService().listAlarms();
          return _json(req, 200, {'ok': true, 'items': list, 'count': list.length});
        } catch (_) {
          return _json(req, 500, {'ok': false, 'error': 'list_failed'});
        }
      }

      if (req.method == 'POST' && path == '/emu/app/alarms/clear') {
        // best-effort: delete all
        int deleted = 0;
        try {
          final list = await SettingsService().listAlarms();
          for (final it in list) {
            final id = (it['_id'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            try {
              final ok = await SettingsService().deleteAlarm(id);
              if (ok) deleted++;
            } catch (_) {}
          }
          // cache reload for immediate reflection
          AlertEngine().invalidateAlarmsCache();
          return _json(req, 200, {'ok': true, 'deleted': deleted});
        } catch (_) {
          try { AlertEngine().invalidateAlarmsCache(); } catch (_) {}
          return _json(req, 500, {'ok': false, 'error': 'clear_failed', 'deleted': deleted});
        }
      }

      if (req.method == 'POST' && path == '/emu/app/prefs') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final s = await SettingsStorage.load();
        if (j.containsKey('language')) s['language'] = (j['language'] as String? ?? 'en').trim();
        if (j.containsKey('region')) s['region'] = (j['region'] as String? ?? 'KR').trim();
        if (j.containsKey('autoRegion')) s['autoRegion'] = (j['autoRegion'] == true);
        if (j.containsKey('timeFormat')) s['timeFormat'] = (j['timeFormat'] as String? ?? '24h').trim();
        if (j.containsKey('glucoseUnit')) s['glucoseUnit'] = (j['glucoseUnit'] as String? ?? 'mgdl').trim();
        if (j.containsKey('alarmsMuteAll')) s['alarmsMuteAll'] = (j['alarmsMuteAll'] == true);
        // Accessibility (Settings > Accessibility) - QA automation helpers
        if (j.containsKey('accHighContrast')) s['accHighContrast'] = (j['accHighContrast'] == true);
        if (j.containsKey('accLargerFont')) s['accLargerFont'] = (j['accLargerFont'] == true);
        if (j.containsKey('accColorblind')) s['accColorblind'] = (j['accColorblind'] == true);
        if (j.containsKey('chartDotSize')) {
          final int ds = ((j['chartDotSize'] as num?)?.toInt() ?? 2).clamp(1, 10);
          s['chartDotSize'] = ds;
        }
        await SettingsStorage.save(s);
        try { AppSettingsBus.notify(); } catch (_) {}
        return _json(req, 200, {
          'ok': true,
          'language': (s['language'] as String? ?? '').trim(),
          'region': (s['region'] as String? ?? '').trim(),
          'autoRegion': s['autoRegion'] == true,
          'timeFormat': (s['timeFormat'] as String? ?? '').trim(),
          'glucoseUnit': (s['glucoseUnit'] as String? ?? '').trim(),
          'alarmsMuteAll': s['alarmsMuteAll'] == true,
          'accHighContrast': s['accHighContrast'] == true,
          'accLargerFont': s['accLargerFont'] == true,
          'accColorblind': s['accColorblind'] == true,
          'chartDotSize': (s['chartDotSize'] as num?)?.toInt() ?? 2,
        });
      }

      if (req.method == 'POST' && path == '/emu/app/nav') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String route = (j['route'] as String? ?? '/settings').trim();
        final bool replace = j['replaceStack'] == true;
        final bool ok = await AppNav.goNamed(route, replaceStack: replace);
        return _json(req, 200, {'ok': ok, 'route': AppNav.route});
      }

      if (req.method == 'GET' && path == '/emu/app/nav') {
        return _json(req, 200, {'ok': true, 'route': AppNav.route});
      }

      if (req.method == 'GET' && path == '/emu/app/stats') {
        final s = await SettingsStorage.load();
        final int glucoseCount = await GlucoseLocalRepo().count();
        final String eqsn = (s['eqsn'] as String? ?? '').trim();
        final String userId = (s['lastUserId'] as String? ?? '').trim();
        final int maxTridAny = await GlucoseLocalRepo().maxTrid(eqsn: eqsn);
        final int maxTridUser = await GlucoseLocalRepo().maxTrid(eqsn: eqsn, userId: userId);
        final String lang = (s['language'] as String? ?? 'en').trim();
        final String region = (s['region'] as String? ?? 'KR').trim();
        final bool autoRegion = (s['autoRegion'] as bool? ?? true);
        final String timeFormat = (s['timeFormat'] as String? ?? '24h').trim();
        final String glucoseUnit = (s['glucoseUnit'] as String? ?? 'mgdl').trim();
        final bool alarmsMuteAll = s['alarmsMuteAll'] == true;
        final bool accHighContrast = s['accHighContrast'] == true;
        final bool accLargerFont = s['accLargerFont'] == true;
        final bool accColorblind = s['accColorblind'] == true;
        final int chartDotSize = ((s['chartDotSize'] as num?)?.toInt() ?? 2).clamp(1, 10);
        final String lastLogTxAt = (s['lastLogTxAt'] as String? ?? '').trim();
        final bool lastLogTxOk = s['lastLogTxOk'] == true;
        final String lastLockScreenAt = (s['lastLockScreenAt'] as String? ?? '').trim();
        final bool lastLockScreenOk = s['lastLockScreenOk'] == true;
        final dynamic lastLockScreenValue = s['lastLockScreenValue'];
        final String lastLockScreenTrend = (s['lastLockScreenTrend'] as String? ?? '').trim();
        final bool ar0108Enabled = s['ar0108Enabled'] != false;
        final String lo0101ViewedAt = (s['lo0101ViewedAt'] as String? ?? '').trim();
        final String lo0101SheetOpenedAt = (s['lo0101SheetOpenedAt'] as String? ?? '').trim();
        final String lo0101LastProvider = (s['lo0101LastProvider'] as String? ?? '').trim();
        final String lo0101LastProviderAt = (s['lo0101LastProviderAt'] as String? ?? '').trim();
        final String lo0102ViewedAt = (s['lo0102ViewedAt'] as String? ?? '').trim();
        final String lo0103ViewedAt = (s['lo0103ViewedAt'] as String? ?? '').trim();
        final String lo0104ViewedAt = (s['lo0104ViewedAt'] as String? ?? '').trim();
        final String lo0108EnteredAt = (s['lo0108EnteredAt'] as String? ?? '').trim();
        final String lo0201ViewedAt = (s['lo0201ViewedAt'] as String? ?? '').trim();
        final String lo0201Choice = (s['lo0201Choice'] as String? ?? '').trim();
        final String lo0203ViewedAt = (s['lo0203ViewedAt'] as String? ?? '').trim();
        final String lo0203Phone = (s['lo0203Phone'] as String? ?? '').trim();
        final String lo0203VerifiedAt = (s['lo0203VerifiedAt'] as String? ?? '').trim();
        final String lo0205ViewedAt = (s['lo0205ViewedAt'] as String? ?? '').trim();
        final String sc0201ViewedAt = (s['sc0201ViewedAt'] as String? ?? '').trim();
        final String sc0201RenderedAt = (s['sc0201RenderedAt'] as String? ?? '').trim();
        final String sc0301ViewedAt = (s['sc0301ViewedAt'] as String? ?? '').trim();
        final String sc0401ViewedAt = (s['sc0401ViewedAt'] as String? ?? '').trim();
        final String sc0501ViewedAt = (s['sc0501ViewedAt'] as String? ?? '').trim();
        final String sc0601ViewedAt = (s['sc0601ViewedAt'] as String? ?? '').trim();
        final String sc0801ViewedAt = (s['sc0801ViewedAt'] as String? ?? '').trim();
        final String gu0101RenderedAt = (s['gu0101RenderedAt'] as String? ?? '').trim();
        final dynamic gu0101Value = s['gu0101Value'];
        final String gu0102Trend = (s['gu0102Trend'] as String? ?? '').trim();
        final String gu0103Color = (s['gu0103Color'] as String? ?? '').trim();
        final String tg0101ViewedAt = (s['tg0101ViewedAt'] as String? ?? '').trim();
        final String tg0102ViewedAt = (s['tg0102ViewedAt'] as String? ?? '').trim();
        final String rp0101ViewedAt = (s['rp0101ViewedAt'] as String? ?? '').trim();
        final String rp0101RenderedAt = (s['rp0101RenderedAt'] as String? ?? '').trim();
        final String pd0101ViewedAt = (s['pd0101ViewedAt'] as String? ?? '').trim();
        final String pd0101RefreshedAt = (s['pd0101RefreshedAt'] as String? ?? '').trim();
        final int pd0101ItemsCount = (s['pd0101ItemsCount'] as int? ?? 0);
        final String me0101ViewedAt = (s['me0101ViewedAt'] as String? ?? '').trim();
        final String me0101SavedAt = (s['me0101SavedAt'] as String? ?? '').trim();
        final String me0101SavedType = (s['me0101SavedType'] as String? ?? '').trim();
        final String me0101FoodShotAt = (s['me0101FoodShotAt'] as String? ?? '').trim();
        final String me0101FoodShotAsset = (s['me0101FoodShotAsset'] as String? ?? '').trim();
        final String lo0202ViewedAt = (s['lo0202ViewedAt'] as String? ?? '').trim();
        final String lo0202AgreedAt = (s['lo0202AgreedAt'] as String? ?? '').trim();
        final String lo0204ViewedAt = (s['lo0204ViewedAt'] as String? ?? '').trim();
        final bool passcodeEnabled = s['passcodeEnabled'] == true;
        final bool biometricEnabled = s['biometricEnabled'] == true;
        final bool biometricDebugBypass = s['biometricDebugBypass'] == true;
        final bool sc0101Consent = s['sc0101Consent'] == true;
        final int sc0101Low = ((s['sc0101Low'] as num?)?.toInt() ?? 70).clamp(40, 120);
        final int sc0101High = ((s['sc0101High'] as num?)?.toInt() ?? 180).clamp(120, 300);
        final List<dynamic> regs = (s['registeredDevices'] as List<dynamic>? ?? const <dynamic>[]);
        final bool sc0102HasDevice = regs.isNotEmpty;
        final int registeredDevicesCount = regs.length;
        final String um0101ViewedAt = (s['um0101ViewedAt'] as String? ?? '').trim();
        final String lo0107ViewedAt = (s['lo0107ViewedAt'] as String? ?? '').trim();
        final String sc0104ViewedAt = (s['sc0104ViewedAt'] as String? ?? '').trim();
        final String sc0105ManualSnAt = (s['sc0105ManualSnAt'] as String? ?? '').trim();
        final String sc0105ManualSnValue = (s['sc0105ManualSnValue'] as String? ?? '').trim();
        final String sc0106WarmupStartAt = (s['sc0106WarmupStartAt'] as String? ?? '').trim();
        final String sc0106WarmupEndsAt = (s['sc0106WarmupEndsAt'] as String? ?? '').trim();
        final bool sc0106WarmupActive = (s['sc0106WarmupActive'] == true);
        final String sc0106WarmupDoneAt = (s['sc0106WarmupDoneAt'] as String? ?? '').trim();
        final String sc0103ViewedAt = (s['sc0103ViewedAt'] as String? ?? '').trim();
        final String sc0602ViewedAt = (s['sc0602ViewedAt'] as String? ?? '').trim();
        final String sc0602Reason = (s['sc0602Reason'] as String? ?? '').trim();
        final String sc0701ViewedAt = (s['sc0701ViewedAt'] as String? ?? '').trim();
        final bool sc0701Enabled = (s['sc0701Enabled'] == true);
        final String sc0701Preset = (s['sc0701Preset'] as String? ?? '').trim();
        final String sc0701From = (s['sc0701From'] as String? ?? '').trim();
        final String sc0701To = (s['sc0701To'] as String? ?? '').trim();
        final bool sc0701ItemSummary = (s['sc0701ItemSummary'] == true);
        final bool sc0701ItemDistribution = (s['sc0701ItemDistribution'] == true);
        final bool sc0701ItemGraph = (s['sc0701ItemGraph'] == true);
        final bool sc0701ItemUserProfile = (s['sc0701ItemUserProfile'] == true);
        final bool sc0701MethodEmail = (s['sc0701MethodEmail'] == true);
        final bool sc0701MethodSms = (s['sc0701MethodSms'] == true);
        final String sc0701Format = (s['sc0701Format'] as String? ?? '').trim();
        final bool sc0701Revocable = (s['sc0701Revocable'] == true);
        final String sc0701LastSharedAt = (s['sc0701LastSharedAt'] as String? ?? '').trim();
        final bool sc0701LastSharedOk = (s['sc0701LastSharedOk'] == true);
        final String sc0701LastNote = (s['sc0701LastNote'] as String? ?? '').trim();
        final String sc0701LastFilePath = (s['sc0701LastFilePath'] as String? ?? '').trim();
        final String sc0701RenderedAt = (s['sc0701RenderedAt'] as String? ?? '').trim();
        int sc0106WarmupRemainingSec = 0;
        try {
          if (sc0106WarmupActive && sc0106WarmupEndsAt.isNotEmpty) {
            final dt = DateTime.tryParse(sc0106WarmupEndsAt);
            if (dt != null) {
              final int s0 = dt.toUtc().difference(DateTime.now().toUtc()).inSeconds;
              sc0106WarmupRemainingSec = s0 < 0 ? 0 : s0;
            }
          }
        } catch (_) {}
        String lastRegSn = '';
        try {
          if (regs.isNotEmpty && regs.last is Map) {
            lastRegSn = ((regs.last as Map)['sn'] ?? '').toString();
          }
        } catch (_) {}
        String lastMac = '';
        try {
          final prefs = await SharedPreferences.getInstance();
          lastMac = (prefs.getString('cgms.last_mac') ?? '').trim();
        } catch (_) {}
        return _json(req, 200, {
          'ok': true,
          'currentRoute': AppNav.route,
          'apiBaseUrl': (s['apiBaseUrl'] as String? ?? '').trim(),
          'guestMode': s['guestMode'] == true,
          'language': lang,
          'region': region,
          'autoRegion': autoRegion,
          'timeFormat': timeFormat,
          'always24h': timeFormat == '24h',
          'glucoseUnit': glucoseUnit,
          'alarmsMuteAll': alarmsMuteAll,
          'accHighContrast': accHighContrast,
          'accLargerFont': accLargerFont,
          'accColorblind': accColorblind,
          'chartDotSize': chartDotSize,
          'lastLogTxAt': lastLogTxAt,
          'lastLogTxOk': lastLogTxOk,
          'lastLockScreenAt': lastLockScreenAt,
          'lastLockScreenOk': lastLockScreenOk,
          'lastLockScreenValue': lastLockScreenValue,
          'lastLockScreenTrend': lastLockScreenTrend,
          'ar0108Enabled': ar0108Enabled,
          'lo0101ViewedAt': lo0101ViewedAt,
          'lo0101SheetOpenedAt': lo0101SheetOpenedAt,
          'lo0101LastProvider': lo0101LastProvider,
          'lo0101LastProviderAt': lo0101LastProviderAt,
          'lo0102ViewedAt': lo0102ViewedAt,
          'lo0103ViewedAt': lo0103ViewedAt,
          'lo0104ViewedAt': lo0104ViewedAt,
          'lo0108EnteredAt': lo0108EnteredAt,
          'lo0201ViewedAt': lo0201ViewedAt,
          'lo0201Choice': lo0201Choice,
          'lo0203ViewedAt': lo0203ViewedAt,
          'lo0203Phone': lo0203Phone,
          'lo0203VerifiedAt': lo0203VerifiedAt,
          'lo0205ViewedAt': lo0205ViewedAt,
          'sc0201ViewedAt': sc0201ViewedAt,
          'sc0201RenderedAt': sc0201RenderedAt,
          'sc0301ViewedAt': sc0301ViewedAt,
          'sc0401ViewedAt': sc0401ViewedAt,
          'sc0501ViewedAt': sc0501ViewedAt,
          'sc0601ViewedAt': sc0601ViewedAt,
          'sc0801ViewedAt': sc0801ViewedAt,
          'gu0101RenderedAt': gu0101RenderedAt,
          'gu0101Value': gu0101Value,
          'gu0102Trend': gu0102Trend,
          'gu0103Color': gu0103Color,
          'tg0101ViewedAt': tg0101ViewedAt,
          'tg0102ViewedAt': tg0102ViewedAt,
          'rp0101ViewedAt': rp0101ViewedAt,
          'rp0101RenderedAt': rp0101RenderedAt,
          'pd0101ViewedAt': pd0101ViewedAt,
          'pd0101RefreshedAt': pd0101RefreshedAt,
          'pd0101ItemsCount': pd0101ItemsCount,
          'me0101ViewedAt': me0101ViewedAt,
          'me0101SavedAt': me0101SavedAt,
          'me0101SavedType': me0101SavedType,
          'me0101FoodShotAt': me0101FoodShotAt,
          'me0101FoodShotAsset': me0101FoodShotAsset,
          'lo0202ViewedAt': lo0202ViewedAt,
          'lo0202AgreedAt': lo0202AgreedAt,
          'lo0204ViewedAt': lo0204ViewedAt,
          'passcodeEnabled': passcodeEnabled,
          'biometricEnabled': biometricEnabled,
          'biometricDebugBypass': biometricDebugBypass,
          'sc0101Consent': sc0101Consent,
          'sc0101Low': sc0101Low,
          'sc0101High': sc0101High,
          'sc0102HasDevice': sc0102HasDevice,
          'registeredDevicesCount': registeredDevicesCount,
          'lastRegisteredSn': lastRegSn,
          'lastMac': lastMac,
          'um0101ViewedAt': um0101ViewedAt,
          'lo0107ViewedAt': lo0107ViewedAt,
          'sc0104ViewedAt': sc0104ViewedAt,
          'sc0105ManualSnAt': sc0105ManualSnAt,
          'sc0105ManualSnValue': sc0105ManualSnValue,
          'sc0103ViewedAt': sc0103ViewedAt,
          'sc0106WarmupStartAt': sc0106WarmupStartAt,
          'sc0106WarmupEndsAt': sc0106WarmupEndsAt,
          'sc0106WarmupActive': sc0106WarmupActive,
          'sc0106WarmupDoneAt': sc0106WarmupDoneAt,
          'sc0106WarmupRemainingSec': sc0106WarmupRemainingSec,
          'sc0602ViewedAt': sc0602ViewedAt,
          'sc0602Reason': sc0602Reason,
          'sc0701ViewedAt': sc0701ViewedAt,
          'sc0701Enabled': sc0701Enabled,
          'sc0701Preset': sc0701Preset,
          'sc0701From': sc0701From,
          'sc0701To': sc0701To,
          'sc0701ItemSummary': sc0701ItemSummary,
          'sc0701ItemDistribution': sc0701ItemDistribution,
          'sc0701ItemGraph': sc0701ItemGraph,
          'sc0701ItemUserProfile': sc0701ItemUserProfile,
          'sc0701MethodEmail': sc0701MethodEmail,
          'sc0701MethodSms': sc0701MethodSms,
          'sc0701Format': sc0701Format,
          'sc0701Revocable': sc0701Revocable,
          'sc0701LastSharedAt': sc0701LastSharedAt,
          'sc0701LastSharedOk': sc0701LastSharedOk,
          'sc0701LastNote': sc0701LastNote,
          'sc0701LastFilePath': sc0701LastFilePath,
          'sc0701RenderedAt': sc0701RenderedAt,
          'eqsn': eqsn,
          'lastUserId': userId,
          'lastTrid': (s['lastTrid'] as int?) ?? 0,
          'maxTridLocalAny': maxTridAny,
          'maxTridLocalUser': maxTridUser,
          'glucoseCountLocal': glucoseCount,
          'lastAlert': (s['lastAlert'] as Map?) ?? {},
        });
      }

      // SC_01_06: warm-up state (QA/봇용 강제 설정)
      if (req.method == 'POST' && path == '/emu/app/warmup') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final bool active = j['active'] != false;
        final int minutes = ((j['minutes'] as num?)?.toInt() ?? 30).clamp(1, 120);
        final now = DateTime.now();
        final s = await SettingsStorage.load();
        if (!active) {
          s['sc0106WarmupActive'] = false;
          s['sc0106WarmupDoneAt'] = now.toUtc().toIso8601String();
        } else {
          s['sc0106WarmupStartAt'] = now.toUtc().toIso8601String();
          s['sc0106WarmupEndsAt'] = now.add(Duration(minutes: minutes)).toUtc().toIso8601String();
          s['sc0106WarmupActive'] = true;
          s['sc0106WarmupDoneAt'] = '';
        }
        await SettingsStorage.save(s);
        return _json(req, 200, {
          'ok': true,
          'active': s['sc0106WarmupActive'] == true,
          'startAt': (s['sc0106WarmupStartAt'] as String? ?? '').trim(),
          'endsAt': (s['sc0106WarmupEndsAt'] as String? ?? '').trim(),
          'doneAt': (s['sc0106WarmupDoneAt'] as String? ?? '').trim(),
        });
      }

      if (req.method == 'POST' && path == '/emu/app/alarm/system') {
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> j = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
        final String reason = (j['reason'] as String? ?? 'signal_loss').trim();
        await AlertEngine().debugTriggerSystemAlarm(reason: reason.isEmpty ? 'signal_loss' : reason);
        return _json(req, 200, {'ok': true, 'type': 'system', 'reason': reason});
      }

      if (req.method == 'POST' && path == '/emu/app/alarms/reload') {
        AlertEngine().invalidateAlarmsCache();
        return _json(req, 200, {'ok': true});
      }

      return _json(req, 404, {'ok': false, 'error': 'not found', 'path': path});
    } catch (e) {
      return _json(req, 500, {'ok': false, 'error': e.toString()});
    }
  }

  static Future<void> _json(HttpRequest req, int status, Map<String, dynamic> body) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  static List<int> _parseBytes(dynamic v) {
    if (v is List) {
      final out = <int>[];
      for (final x in v) {
        final n = x is int ? x : int.tryParse(x.toString());
        if (n == null) continue;
        out.add(n & 0xFF);
      }
      return out;
    }
    return <int>[];
  }

  static List<int> _parseHex(String hex) {
    final cleaned = hex
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), ' ')
        .trim();
    if (cleaned.isEmpty) return <int>[];
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p, radix: 16);
      if (n == null) continue;
      out.add(n & 0xFF);
    }
    return out;
  }
}

