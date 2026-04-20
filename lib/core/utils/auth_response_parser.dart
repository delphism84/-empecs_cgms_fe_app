import 'dart:convert';

/// BE별로 다른 로그인 JSON을 FE가 일관되게 파싱.
class AuthResponseParser {
  AuthResponseParser._();

  static String str(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map<String, dynamic>) return Map<String, dynamic>.from(v);
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return <String, dynamic>{};
  }

  /// `{ "data": { "token", "user" } }` / `{ "result": ... }` 등 래핑 해제 후 평탄화.
  static Map<String, dynamic> normalizeLoginEnvelope(Map<String, dynamic> raw) {
    Map<String, dynamic> d = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'result', 'payload']) {
      final inner = d[key];
      if (inner is Map) {
        final innerMap = asMap(inner);
        d = {...d, ...innerMap};
        break;
      }
    }
    return d;
  }

  static String? pickToken(Map<String, dynamic> d) {
    for (final k in ['token', 'accessToken', 'access_token', 'jwt', 'id_token']) {
      final v = d[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// 로그인 응답에서 계정 표시용 필드 (프로덕션은 token-only 인 경우가 있음 → [formEmail] 폴백).
  static LoginProfileFields parseLoginProfile({
    required Map<String, dynamic> envelope,
    required String formEmail,
  }) {
    final d = normalizeLoginEnvelope(envelope);
    final user = asMap(d['user']);

    String email = str(d['email']);
    if (email.isEmpty) email = str(user['email']);
    if (email.isEmpty) email = formEmail.trim();

    String display = str(d['displayName']);
    if (display.isEmpty) display = str(d['name']);
    if (display.isEmpty) display = str(user['displayName']);
    if (display.isEmpty) display = str(user['name']);
    if (display.isEmpty) {
      final fn = str(d['firstName']);
      final ln = str(d['lastName']);
      if (fn.isEmpty && user.isNotEmpty) {
        display = '${str(user['firstName'])} ${str(user['lastName'])}'.trim();
      } else {
        display = '$fn $ln'.trim();
      }
    }
    if (display.isEmpty) display = email;

    return LoginProfileFields(email: email, displayName: display, token: pickToken(d));
  }

  static Map<String, dynamic>? decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final bytes = base64Url.decode(payload);
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return j.map((k, v) => MapEntry(k.toString(), v));
      return null;
    } catch (_) {
      return null;
    }
  }
}

class LoginProfileFields {
  const LoginProfileFields({
    required this.email,
    required this.displayName,
    required this.token,
  });

  final String email;
  final String displayName;
  final String? token;
}
