import 'package:flutter/foundation.dart' show kIsWeb;

class DebugConfig {
  static bool overlayEnabled = false;
  static bool debugNavVisible = false;

  /// API 베이스 URL
  /// - **Web 배포**(동일 도메인에서 nginx가 `/api` 프록시): [Uri.base] 오리진 사용
  /// - **Web 로컬**(flutter run / file:// / localhost): 오리진에는 API가 없으므로 운영 호스트와 동일하게 고정
  /// - **모바일**: 운영 API 호스트 고정
  /// docs/social_login_fe.guide.md · BE: empecs.lunarsystem.co.kr
  static const String _productionApiOrigin = 'https://empecs.lunarsystem.co.kr';

  static String get apiBase {
    if (kIsWeb) {
      try {
        final Uri u = Uri.base.removeFragment();
        final String host = u.host.toLowerCase();
        final bool noApiOnThisOrigin = host.isEmpty ||
            host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '0.0.0.0' ||
            host.startsWith('192.168.') ||
            host.endsWith('.local');
        if (noApiOnThisOrigin) {
          return _productionApiOrigin;
        }
        final bool sameStackDeployed =
            host.contains('lunarsystem.co.kr') || host.contains('empecs');
        if (sameStackDeployed) {
          return u.origin;
        }
        return _productionApiOrigin;
      } catch (_) {}
    }
    return _productionApiOrigin;
  }

  // 모든 API 기본 타임아웃(ms)
  static const int apiTimeoutMs = 3000;
}


