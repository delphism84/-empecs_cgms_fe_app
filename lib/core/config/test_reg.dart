import 'package:helpcare/core/config/test_account.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// 회원가입 QA: 상단 제목 더블탭으로 `testreg=on` 후 테스트 계정 자동 입력.
/// [TestAccount.enabled] ? ?? ?? (release APK ???).
class TestReg {
  TestReg._();

  static const String storageKey = 'testRegOn';

  static const String email = TestAccount.email;
  static const String password = TestAccount.password;

  static Future<bool> isOn() async {
    if (!TestAccount.enabled) return false;
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      return st[storageKey] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable() async {
    if (!TestAccount.enabled) return;
    await SettingsStorage.save(<String, dynamic>{
      storageKey: true,
      'signupDraftEmail': email,
      'signupDraftPassword': password,
    });
  }

  static Future<void> disable() async {
    if (!TestAccount.enabled) return;
    await SettingsStorage.save(<String, dynamic>{storageKey: false});
  }
}
