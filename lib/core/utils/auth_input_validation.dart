/// 로그인 ID(이메일) 검증 — `POST /api/auth/login` 계약과 맞춤
/// (참고: https://empecs.lunarsystem.co.kr/api/docs/api.md)
bool isValidLoginEmailId(String raw) {
  final String s = raw.trim();
  if (s.length < 5) return false;
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
}
