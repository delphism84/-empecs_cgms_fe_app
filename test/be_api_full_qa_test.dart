import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Node `tools/api-qa-bot/run.mjs` 와 동일한 BE 계약을 Dart로 검증 (네트워크 필요).
///
/// 기본은 **skip** — CI/로컬에서 부담 없이 `flutter test`만 돌리기 위함.
///
/// ```bash
/// flutter test test/be_api_full_qa_test.dart --dart-define=RUN_BE_FULL_QA=true
/// flutter test test/be_api_full_qa_test.dart --dart-define=RUN_BE_FULL_QA=true --dart-define=API_BASE=https://empecs.lunarsystem.co.kr
/// flutter test test/be_api_full_qa_test.dart --dart-define=RUN_BE_FULL_QA=true --dart-define=SKIP_REGISTER=true --dart-define=LOGIN_EMAIL=... --dart-define=LOGIN_PASSWORD=...
/// ```
const bool kRunFull = bool.fromEnvironment('RUN_BE_FULL_QA', defaultValue: false);
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://empecs.lunarsystem.co.kr',
);
const bool kSkipRegister = bool.fromEnvironment('SKIP_REGISTER', defaultValue: false);
const String kLoginEmail = String.fromEnvironment('LOGIN_EMAIL', defaultValue: '');
const String kLoginPassword = String.fromEnvironment('LOGIN_PASSWORD', defaultValue: '');

bool _ok2xx(int s) => s >= 200 && s < 300;

Map<String, dynamic> _json(http.Response r) {
  final o = jsonDecode(r.body);
  if (o is Map<String, dynamic>) return o;
  if (o is Map) return Map<String, dynamic>.from(o);
  return <String, dynamic>{};
}

void main() {
  test(
    'BE full API contract (enable: --dart-define=RUN_BE_FULL_QA=true)',
    () async {
      final base = kApiBase.replaceAll(RegExp(r'/$'), '');
      final client = http.Client();
      try {
        final probe = await client
            .get(Uri.parse('$base/api/settings/app'))
            .timeout(const Duration(seconds: 20));
        expect(
          probe.statusCode == 401 || probe.statusCode == 403,
          isTrue,
          reason: 'settings/app without auth',
        );

        late String token;
        if (kSkipRegister) {
          expect(kLoginEmail.isNotEmpty && kLoginPassword.isNotEmpty, isTrue);
          final login = await client
              .post(
                Uri.parse('$base/api/auth/login'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'email': kLoginEmail, 'password': kLoginPassword}),
              )
              .timeout(const Duration(seconds: 20));
          expect(_ok2xx(login.statusCode), isTrue, reason: 'login');
          token = _json(login)['token'] as String? ?? '';
        } else {
          final id = DateTime.now().millisecondsSinceEpoch;
          final email = 'dart_qa_${id}@lunarsystem.co.kr';
          final reg = await client
              .post(
                Uri.parse('$base/api/auth/register'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': email,
                  'password': 'TestPass123!',
                  'firstName': 'QA',
                  'lastName': 'Dart',
                  'dateOfBirth': '1990-01-01',
                  'agreeTerms': true,
                }),
              )
              .timeout(const Duration(seconds: 20));
          expect(reg.statusCode, 201, reason: 'register');
          token = _json(reg)['token'] as String? ?? '';
        }
        expect(token.isNotEmpty, isTrue);

        final headers = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        };

        final me = await client.get(Uri.parse('$base/api/auth/me'), headers: headers).timeout(const Duration(seconds: 20));
        expect(_ok2xx(me.statusCode), isTrue, reason: 'auth/me');

        final app = await client.get(Uri.parse('$base/api/settings/app'), headers: headers).timeout(const Duration(seconds: 20));
        expect(app.statusCode, 200, reason: 'settings/app');

        final now = DateTime.now().toUtc();
        final from = now.subtract(const Duration(days: 7)).toIso8601String();
        final to = now.toIso8601String();
        final gq = Uri.parse('$base/api/data/glucose').replace(queryParameters: {
          'from': from,
          'to': to,
          'limit': '50',
        });
        final gl = await client.get(gq, headers: headers).timeout(const Duration(seconds: 20));
        expect(_ok2xx(gl.statusCode), isTrue, reason: 'glucose list');

        final eq = Uri.parse('$base/api/data/events').replace(queryParameters: {
          'from': from,
          'to': to,
          'limit': '50',
          'sync': 'true',
        });
        final ev = await client.get(eq, headers: headers).timeout(const Duration(seconds: 20));
        expect(_ok2xx(ev.statusCode), isTrue, reason: 'events list');

        final eqsn = 'DARTQA_${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
        final resolve = Uri.parse('$base/api/settings/eq-list/resolve').replace(queryParameters: {'serial': eqsn});
        final res = await client.get(resolve, headers: headers).timeout(const Duration(seconds: 20));
        expect(
          res.statusCode == 200 || res.statusCode == 404,
          isTrue,
          reason: 'eq resolve',
        );

        final upsert = await client
            .post(
              Uri.parse('$base/api/settings/eq-list'),
              headers: headers,
              body: jsonEncode({'serial': eqsn, 'startAt': now.toIso8601String()}),
            )
            .timeout(const Duration(seconds: 20));
        expect(
          upsert.statusCode == 200 || upsert.statusCode == 201,
          isTrue,
          reason: 'eq-list post',
        );

        final tMs = [now.millisecondsSinceEpoch - 180000, now.millisecondsSinceEpoch - 120000];
        final batch = await client
            .post(
              Uri.parse('$base/api/data/glucose/batch'),
              headers: headers,
              body: jsonEncode({
                'eqsn': eqsn,
                't': tMs,
                'v': [100, 102],
                'tr': [7001, 7002],
              }),
            )
            .timeout(const Duration(seconds: 20));
        expect(_ok2xx(batch.statusCode), isTrue, reason: 'glucose batch');

        String? eventId;
        final batchEv = await client
            .post(
              Uri.parse('$base/api/data/events/batch'),
              headers: headers,
              body: jsonEncode({
                'eqsn': eqsn,
                'events': [
                  {
                    'type': 'memo',
                    'time': now.subtract(const Duration(seconds: 90)).toIso8601String(),
                    'memo': 'dart-qa a',
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (_ok2xx(batchEv.statusCode)) {
          final b = _json(batchEv);
          final ids = b['insertedIds'];
          if (ids is List && ids.isNotEmpty) {
            eventId = ids.first.toString();
          }
        }
        if (batchEv.statusCode == 404 || eventId == null) {
          final one = await client
              .post(
                Uri.parse('$base/api/data/events'),
                headers: headers,
                body: jsonEncode({
                  'type': 'memo',
                  'time': now.subtract(const Duration(seconds: 60)).toIso8601String(),
                  'memo': 'dart-qa single',
                  'eqsn': eqsn,
                }),
              )
              .timeout(const Duration(seconds: 20));
          expect(_ok2xx(one.statusCode), isTrue, reason: 'event single');
          eventId = _json(one)['_id'] as String?;
        }

        if (eventId != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(eventId)) {
          final d1 = await client.delete(Uri.parse('$base/api/data/events/$eventId'), headers: headers).timeout(const Duration(seconds: 20));
          final d2 = await client.delete(Uri.parse('$base/api/data/events/$eventId'), headers: headers).timeout(const Duration(seconds: 20));
          expect(d1.statusCode, 200);
          expect(d2.statusCode, 200);
        }
      } finally {
        client.close();
      }
    },
    skip: !kRunFull,
  );
}
