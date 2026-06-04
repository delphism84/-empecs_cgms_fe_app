import 'package:flutter/foundation.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// QA ?? ??? ??.
///
/// ?? ??: debug ?? + `--dart-define=ENABLE_TEST_ACCOUNT=1`
/// release APK(`flutter build apk --release`)?? ?? ???.
class TestAccount {
  TestAccount._();

  static const String email = 'a@b.com';
  static const String password = '11111111';
  static const String testSensorSn = 'C21Z00102';

  static bool get enabled {
    if (!kDebugMode) return false;
    const String raw = String.fromEnvironment('ENABLE_TEST_ACCOUNT', defaultValue: '');
    final String v = raw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  static bool get autoLogin => enabled;
  static bool get autoRunQaOnHome => enabled;

  static bool isEmail(String? raw) {
    return (raw ?? '').trim().toLowerCase() == email.toLowerCase();
  }

  static Future<bool> isActiveSession() async {
    if (!enabled) return false;
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      final String last = (st['lastUserId'] as String? ?? '').trim();
      final String saved = (st['savedLoginEmail'] as String? ?? '').trim();
      return isEmail(last) || isEmail(saved);
    } catch (_) {
      return false;
    }
  }
}
