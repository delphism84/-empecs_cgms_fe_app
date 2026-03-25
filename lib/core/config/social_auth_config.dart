/// 소셜 로그인 키 설정 (docs/cgms info.csv 기준)
class SocialAuthConfig {
  SocialAuthConfig._();

  /// Google Cloud Console > Web 클라이언트 ID (Android/iOS/서버 겸용)
  /// docs/cgms info.csv: 962492042457-3m9pqdol4i3dl5dgbj8lp7v289eh1jov.apps.googleusercontent.com
  static const String googleClientId = '962492042457-3m9pqdol4i3dl5dgbj8lp7v289eh1jov.apps.googleusercontent.com';

  /// 백엔드 토큰 검증용 Web OAuth 클라이언트 ID
  static const String? googleServerClientId = '962492042457-3m9pqdol4i3dl5dgbj8lp7v289eh1jov.apps.googleusercontent.com';

  /// Kakao Developers > 네이티브 앱키
  /// docs/cgms info.csv: 0110d1cd0e392b8686c2ba1083e3c97c
  static const String kakaoNativeAppKey = '0110d1cd0e392b8686c2ba1083e3c97c';

  static bool get hasGoogleKey => googleClientId.isNotEmpty;
  static bool get hasKakaoKey => kakaoNativeAppKey.isNotEmpty;
}
