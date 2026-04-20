import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Node `scripts/qa-e2e-full.js` 와 같은 BE를 최소 확인 (BLE 제외)
/// 실행: flutter test test/qa_backend_smoke_test.dart --dart-define=QA_BASE=https://empecsuser.lunarsystem.co.kr
const String kQaBase = String.fromEnvironment(
  'QA_BASE',
  defaultValue: 'https://empecsuser.lunarsystem.co.kr',
);

void main() {
  test('GET /api/health', () async {
    final uri = Uri.parse('$kQaBase/api/health');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    expect(res.statusCode, 200);
    expect(res.body.contains('ok'), isTrue);
  });
}
