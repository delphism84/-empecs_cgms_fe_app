import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// BE 스모크 (네트워크 필요).
///
/// - [QA_BASE]: `GET /api/health` (기본: empecsuser 호스트)
/// - [API_BASE]: 앱과 동일 API — `GET /api/settings/app` 비인증 시 401/403
///
/// 실행 예:
/// ```bash
/// flutter test test/qa_backend_smoke_test.dart
/// flutter test test/qa_backend_smoke_test.dart --dart-define=API_BASE=https://empecs.lunarsystem.co.kr
/// ```
const String kQaBase = String.fromEnvironment(
  'QA_BASE',
  defaultValue: 'https://empecsuser.lunarsystem.co.kr',
);

const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://empecs.lunarsystem.co.kr',
);

void main() {
  test('GET /api/health (QA_BASE)', () async {
    final uri = Uri.parse('$kQaBase/api/health');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    expect(res.statusCode, 200);
    expect(res.body.toLowerCase().contains('ok'), isTrue);
  });

  test('GET /api/settings/app without token returns 401 or 403 (API_BASE)', () async {
    final uri = Uri.parse('$kApiBase/api/settings/app');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    expect(
      res.statusCode == 401 || res.statusCode == 403,
      isTrue,
      reason: 'expected 401/403 for unauthenticated settings/app, got ${res.statusCode}',
    );
  });
}
