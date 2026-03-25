import 'package:flutter/foundation.dart' show kIsWeb;

/// 웹에서 URL hash로 QA 초기 라우트 판별 (예: #/qa/qr-scan-success)
String? getQaInitialRoute() {
  if (!kIsWeb) return null;
  try {
    final String? hash = Uri.base.fragment;
    if (hash != null && hash.isNotEmpty) {
      final String path = hash.startsWith('/') ? hash : '/$hash';
      if (path == '/qa/qr-scan-success') return path;
    }
  } catch (_) {}
  return null;
}
