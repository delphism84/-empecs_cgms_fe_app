import 'package:flutter/foundation.dart' show kIsWeb;

/// 웹에서 URL hash로 스플래시 직후 진입할 QA 라우트 (예: `#/sc/07/01`, `#/login`).
/// 프로덕션 라우트 전체를 열지 않고 화이트리스트만 허용한다.
const Set<String> kQaWebHashRoutes = <String>{
  '/qa/qr-scan-success',
  '/qa/web-check',
  '/sc/07/01',
  '/login',
  '/lo/01/01/email',
  '/home',
};

String? getQaInitialRoute() {
  if (!kIsWeb) return null;
  try {
    final String hash = Uri.base.fragment;
    if (hash.isEmpty) return null;
    final String path = hash.startsWith('/') ? hash : '/$hash';
    if (kQaWebHashRoutes.contains(path)) return path;
  } catch (_) {}
  return null;
}
