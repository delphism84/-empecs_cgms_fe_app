import 'debug_config.dart';

/// docs/social_login_fe.guide.md 기준 — empecs.lunarsystem.co.kr
class AuthUrls {
  // backend api base
  static String get apiBase => DebugConfig.apiBase;

  /// 서비스 URL (OAuth 콜백 등)
  static const String serviceUrl = 'https://empecs.lunarsystem.co.kr';

  // auth endpoints
  static String get register => '$apiBase/api/auth/register';
  static String get login => '$apiBase/api/auth/login';
  static String get me => '$apiBase/api/auth/me';
  static String get socialVerify => '$apiBase/api/auth/social/verify';

  /// BE 콜백 성공 시 리다이렉트 (웹용)
  static String get authCallbackSuccess => '$serviceUrl/auth/callback';

  /// BE 콜백 실패 시 리다이렉트 (웹용)
  static String get authCallbackFail => '$serviceUrl/login';

  // external official login pages (for mock/testing)
  static const String googleOfficial = 'https://accounts.google.com/';
  static const String kakaoOfficial = 'https://accounts.kakao.com/login';
  static const String appleOfficial = 'https://appleid.apple.com/sign-in';
}


