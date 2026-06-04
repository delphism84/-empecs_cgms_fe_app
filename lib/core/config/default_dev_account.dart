import 'package:helpcare/core/config/test_account.dart';

/// 검수/개발용 기본 계정 — 서버 `POST /api/auth/login`으로 검증
class DefaultDevAccount {
  DefaultDevAccount._();

  static const String email = 'app@empecs.com';
  static const String password = 'Empecs!@34';

  static bool get autoOpenExistingLogin => TestAccount.autoLogin;
  static bool get autoSubmitExistingLogin => TestAccount.autoLogin;
}
