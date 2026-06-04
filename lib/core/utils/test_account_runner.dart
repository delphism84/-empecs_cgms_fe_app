import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:helpcare/core/config/test_account.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/app_locale.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// `a@b.com` 로그인 세션에서 알람·언어·센서 SN 저장을 자동 검증.
/// UI 저장 버튼과 동일하게 [SettingsService.upsertAlarmByType] / 부분 [SettingsStorage.save] 사용.
class TestAccountRunner {
  TestAccountRunner._();

  static bool _running = false;
  static bool _completed = false;
  static final List<String> lastReport = <String>[];

  static Future<bool> isActiveSession() async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String last = (st['lastUserId'] as String? ?? '').trim();
      final String saved = (st['savedLoginEmail'] as String? ?? '').trim();
      return TestAccount.isEmail(last) || TestAccount.isEmail(saved);
    } catch (_) {
      return false;
    }
  }

  /// 홈 진입 후 1회 실행.
  static Future<void> runAfterHome(BuildContext? context) async {
    if (!TestAccount.autoRunQaOnHome || _running || _completed) return;
    if (!await isActiveSession()) return;

    _running = true;
    lastReport.clear();
    _log('=== TestAccount QA start (${TestAccount.email}) ===');

    try {
      await Future<void>.delayed(const Duration(milliseconds: 800));

      if (context != null && context.mounted) {
        HomeTab.go(4);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }

      await _step('alarm very_low 55->60 (SAVE)', _saveVeryLow60);
      await _step('alarm high 180->200 repeat 1 (SAVE)', _saveHigh200Repeat1);
      await _step('alarm very_low second edit 61 (SAVE)', _saveVeryLow61);
      await _step('alarm persist verify (listAlarms)', _verifyAlarmsPersist);
      await _step('language ko (SAVE)', () => _saveLanguage('ko'));
      await _step('language en (SAVE)', () => _saveLanguage('en'));
      await _step('language back ko (SAVE)', () => _saveLanguage('ko'));
      await _step('sensor SN register (SAVE)', _saveTestSensorSn);
      await _step('sensor SN verify (load)', _verifyTestSensorSn);

      final int pass = lastReport.where((e) => e.startsWith('PASS')).length;
      final int fail = lastReport.where((e) => e.startsWith('FAIL')).length;
      _log('=== TestAccount QA done pass=$pass fail=$fail ===');

      if (context != null && context.mounted) {
        HomeTab.go(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fail == 0
                  ? 'TestAccount QA OK ($pass/$pass)'
                  : 'TestAccount QA FAIL pass=$pass fail=$fail',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      _log('FATAL $e\n$st');
    } finally {
      _running = false;
      _completed = true;
    }
  }

  static Future<void> _step(String name, Future<bool> Function() fn) async {
    try {
      final bool ok = await fn();
      final String line = ok ? 'PASS: $name' : 'FAIL: $name';
      lastReport.add(line);
      _log(line);
    } catch (e) {
      lastReport.add('FAIL: $name ($e)');
      _log('FAIL: $name ($e)');
    }
  }

  static void _log(String msg) {
    log('[TestAccount] $msg', name: 'TestAccount');
    debugPrint('[TestAccount] $msg');
  }

  static Future<bool> _saveVeryLow60() async {
    final SettingsService svc = SettingsService();
    final Map<String, dynamic>? row = await svc.upsertAlarmByType('very_low', <String, dynamic>{
      'type': 'very_low',
      'enabled': true,
      'threshold': 60,
      'repeatMin': 1,
      'sound': true,
      'vibrate': true,
      'overrideDnd': true,
    });
    AlertEngine().invalidateAlarmsCache();
    return row != null && (row['threshold'] as num?)?.toInt() == 60;
  }

  static Future<bool> _saveHigh200Repeat1() async {
    final SettingsService svc = SettingsService();
    final Map<String, dynamic>? row = await svc.upsertAlarmByType('high', <String, dynamic>{
      'type': 'high',
      'enabled': true,
      'threshold': 200,
      'repeatMin': 1,
      'sound': true,
      'vibrate': true,
    });
    AlertEngine().invalidateAlarmsCache();
    return row != null &&
        (row['threshold'] as num?)?.toInt() == 200 &&
        (row['repeatMin'] as num?)?.toInt() == 1;
  }

  static Future<bool> _saveVeryLow61() async {
    final SettingsService svc = SettingsService();
    final Map<String, dynamic>? row = await svc.upsertAlarmByType('very_low', <String, dynamic>{
      'type': 'very_low',
      'enabled': true,
      'threshold': 61,
      'repeatMin': 1,
      'sound': true,
      'vibrate': true,
      'overrideDnd': true,
    });
    AlertEngine().invalidateAlarmsCache();
    return row != null && (row['threshold'] as num?)?.toInt() == 61;
  }

  static Future<bool> _verifyAlarmsPersist() async {
    final List<Map<String, dynamic>> list = await SettingsService().listAlarms();
    int? thOf(String type) {
      try {
        final row = list.firstWhere((e) => (e['type'] ?? '').toString() == type);
        return (row['threshold'] as num?)?.toInt();
      } catch (_) {
        return null;
      }
    }

    int? repOf(String type) {
      try {
        final row = list.firstWhere((e) => (e['type'] ?? '').toString() == type);
        return (row['repeatMin'] as num?)?.toInt();
      } catch (_) {
        return null;
      }
    }

    final int? vLow = thOf('very_low');
    final int? high = thOf('high');
    final int? highRep = repOf('high');
    _log('verify very_low=$vLow high=$high highRep=$highRep');
    return vLow == 61 && high == 200 && highRep == 1;
  }

  static Future<bool> _saveLanguage(String code) async {
    await AppLocale.apply(code);
    final Map<String, dynamic> st = await SettingsStorage.load();
    return AppLocale.normalize(st['language'] as String?) == code;
  }

  static Future<bool> _saveTestSensorSn() async {
    final String sn = TestAccount.testSensorSn.toUpperCase();
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    await SettingsStorage.save(<String, dynamic>{
      'eqsn': sn,
      'lastScannedQrFullSn': sn,
      'lastScannedQrSerial': sn,
      'lastScannedQrAt': nowIso,
      'lastScannedQrRegistered': true,
    });
    SettingsService.invalidateAlarmsMemCache();
    return true;
  }

  static Future<bool> _verifyTestSensorSn() async {
    final Map<String, dynamic> st = await SettingsStorage.load();
    final String eqsn = (st['eqsn'] as String? ?? '').trim().toUpperCase();
    return eqsn == TestAccount.testSensorSn.toUpperCase();
  }
}
