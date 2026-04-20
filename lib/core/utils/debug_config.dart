import 'package:flutter/foundation.dart' show kIsWeb;

class DebugConfig {
  static bool overlayEnabled = false;
  static bool debugNavVisible = false;

  /// API 베이스 URL
  /// - **Web (예: https://empecsuser.lunarsystem.co.kr)**: 현재 오리진 → nginx가 `/api` 를 BE로 프록시 (동일 스택 Docker)
  /// - **모바일(안드로이드/iOS)**: 운영 API 호스트 고정 — BLE·실기기는 여기서 검증
  /// docs/social_login_fe.guide.md · BE: empecs.lunarsystem.co.kr
  static String get apiBase {
    if (kIsWeb) {
      try {
        return Uri.base.removeFragment().origin;
      } catch (_) {}
    }
    return 'https://empecs.lunarsystem.co.kr';
  }

  // 모든 API 기본 타임아웃(ms)
  static const int apiTimeoutMs = 3000;
}


