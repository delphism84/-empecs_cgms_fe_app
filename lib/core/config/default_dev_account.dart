/// 검수/개발용 기본 계정 — 서버 `POST /api/auth/login`으로 검증
/// API 문서: https://empecs.lunarsystem.co.kr/api/docs/api.md
class DefaultDevAccount {
  DefaultDevAccount._();

  static const String email = 'app@empecs.com';
  static const String password = 'Empecs!@34';
}
