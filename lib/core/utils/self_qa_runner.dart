import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:helpcare/core/config/default_dev_account.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/auth_response_parser.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// `--dart-define=IS_SELF_QA=1` 또는 `--dart-define=QA_CMD=…`에 `api`/`full`/`all`이 포함될 때
/// 스플래시 직후 자동 BE 검증 (로그인·EQ·혈당/이벤트 업로드·GET 확인).
///
/// 선택:
/// - `SELF_QA_EMAIL` / `SELF_QA_PASSWORD` — 있으면 먼저 로그인 시도
/// - 없으면 [DefaultDevAccount] 로 로그인 시도 후, 실패 시 `@lunarsystem.co.kr` 로 신규 가입
///
/// ```bash
/// flutter run -d chrome --dart-define=IS_SELF_QA=1
/// flutter run -d chrome --dart-define=QA_CMD=full
/// flutter run -d chrome --dart-define=IS_SELF_QA=1 --dart-define=SELF_QA_EMAIL=u@lunarsystem.co.kr --dart-define=SELF_QA_PASSWORD=secret
/// ```
class SelfQaRunner {
  SelfQaRunner._();

  /// `bool.fromEnvironment`는 값이 정확히 `"true"`일 때만 true → `=1`도 켜지도록 문자열로 판별.
  static const String _isSelfQaRaw = String.fromEnvironment('IS_SELF_QA', defaultValue: '');
  static bool get enabled {
    final v = _isSelfQaRaw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  /// 스플래시에서 BE 자가 QA를 돌릴지(토큰 확보 후 `/home` 지름길 포함).
  static bool get shouldRunBackend => enabled || QaCmdRunner.wantBackend;
  static const String _envEmail = String.fromEnvironment('SELF_QA_EMAIL', defaultValue: '');
  static const String _envPassword = String.fromEnvironment('SELF_QA_PASSWORD', defaultValue: '');

  static final List<String> lastLogLines = <String>[];

  static void _log(String m) {
    final line = '[SelfQA] $m';
    developer.log(m, name: 'SelfQA');
    debugPrint(line);
    lastLogLines.add(line);
    if (lastLogLines.length > 200) {
      lastLogLines.removeRange(0, lastLogLines.length - 200);
    }
  }

  /// 스플래시 등에서 await. 실패해도 예외를 밖으로 던지지 않음(로그만).
  static Future<void> runIfEnabled() async {
    if (!enabled && !QaCmdRunner.wantBackend) return;
    try {
      await run();
    } catch (e, st) {
      _log('FATAL: $e\n$st');
    }
  }

  static Future<void> run() async {
    if (!enabled && !QaCmdRunner.wantBackend) return;
    lastLogLines.clear();
    _log(enabled ? 'start (IS_SELF_QA=1)' : 'start (QA_CMD backend)');
    ApiClient.invalidateBaseCache();

    final api = ApiClient();

    // --- Auth: env → DefaultDevAccount → register ---
    String? token;
    String usedEmail = '';

    Future<void> tryLogin(String email, String password) async {
      if (email.isEmpty || password.isEmpty) return;
      await api.loadToken();
      final resp = await api.post('/api/auth/login', body: {'email': email, 'password': password}, withGlobalLoading: false);
      if (!ApiClient.isHttpSuccess(resp.statusCode)) {
        _log('login failed ${resp.statusCode} for $email');
        return;
      }
      try {
        final Map<String, dynamic> data = AuthResponseParser.asMap(jsonDecode(resp.body));
        final env = AuthResponseParser.normalizeLoginEnvelope(data);
        token = AuthResponseParser.pickToken(env);
        usedEmail = email;
        _log('login OK $email');
      } catch (e) {
        _log('login parse error: $e');
      }
    }

    if (_envEmail.isNotEmpty && _envPassword.isNotEmpty) {
      await tryLogin(_envEmail.trim(), _envPassword);
    }
    if (token == null || token!.isEmpty) {
      await tryLogin(DefaultDevAccount.email, DefaultDevAccount.password);
    }
    if (token == null || token!.isEmpty) {
      final id = DateTime.now().millisecondsSinceEpoch;
      usedEmail = 'selfqa_$id@lunarsystem.co.kr';
      const password = 'TestPass123!';
      await api.loadToken();
      final reg = await api.post('/api/auth/register', body: {
        'email': usedEmail,
        'password': password,
        'firstName': 'Self',
        'lastName': 'QA',
        'dateOfBirth': '1990-01-01',
        'agreeTerms': true,
      }, withGlobalLoading: false);
      if (!ApiClient.isHttpSuccess(reg.statusCode)) {
        _log('register failed ${reg.statusCode} ${reg.body}');
        return;
      }
      try {
        final Map<String, dynamic> data = AuthResponseParser.asMap(jsonDecode(reg.body));
        final env = AuthResponseParser.normalizeLoginEnvelope(data);
        token = AuthResponseParser.pickToken(env);
        _log('register OK $usedEmail');
      } catch (e) {
        _log('register parse error: $e');
      }
    }

    if (token == null || token!.isEmpty) {
      _log('no token, abort');
      return;
    }

    await api.saveToken(token!);
    try {
      await ProfileSyncService.refreshFromServer();
    } catch (_) {}

    // --- OnlineMonitor-style probe ---
    final appProbe = await api.get('/api/settings/app', withGlobalLoading: false);
    _log('GET /api/settings/app → ${appProbe.statusCode}');
    if (appProbe.statusCode != 200) {
      _log('settings/app unexpected, abort uploads');
      return;
    }

    // --- Sensor context (DataService._canUpload) ---
    final now = DateTime.now().toUtc();
    final eqsn = 'SELFQA_${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    try {
      final st = await SettingsStorage.load();
      st['eqsn'] = eqsn;
      st['sensorStartAt'] = now.toIso8601String();
      st['sensorStartAtEqsn'] = eqsn;
      st['guestMode'] = false;
      await SettingsStorage.save(st);
    } catch (_) {}

    final upsertEq = await api.post('/api/settings/eq-list', body: {
      'serial': eqsn,
      'startAt': now.toIso8601String(),
    }, withGlobalLoading: false);
    _log('POST /api/settings/eq-list → ${upsertEq.statusCode}');

    final ds = DataService();
    final tMs = [now.millisecondsSinceEpoch - 120000, now.millisecondsSinceEpoch - 60000];
    final batchOk = await ds.postGlucoseBatch(t: tMs, v: [101.0, 103.0], tr: [50001, 50002]);
    _log('postGlucoseBatch → $batchOk');

    final evOk = await ds.postEventsBatch(events: [
      {
        'type': 'memo',
        'time': now.subtract(const Duration(seconds: 30)).toIso8601String(),
        'memo': 'self-qa memo',
      },
    ]);
    if (!evOk) {
      final oneEv = await ds.postEvent(
        type: 'memo',
        time: now.subtract(const Duration(seconds: 20)),
        memo: 'self-qa single',
      );
      _log('postEventsBatch failed, postEvent → $oneEv');
    } else {
      _log('postEventsBatch → true');
    }

    final from = now.subtract(const Duration(days: 1)).toIso8601String();
    final to = now.add(const Duration(minutes: 1)).toIso8601String();
    final gGet = await api.get('/api/data/glucose', query: {'from': from, 'to': to, 'limit': '20'}, withGlobalLoading: false);
    _log('GET /api/data/glucose → ${gGet.statusCode}');

    final eGet = await api.get('/api/data/events', query: {'from': from, 'to': to, 'limit': '20', 'sync': 'true'}, withGlobalLoading: false);
    _log('GET /api/data/events → ${eGet.statusCode}');

    _log('done OK');
  }
}

/// `--dart-define=QA_CMD=...` — optional **REST self-QA** flags plus **UI route tour**
/// (login, signup intro, data share) via [AppNav].
///
/// Comma-separated tokens (case-insensitive):
/// - `api` — same backend probe as [SelfQaRunner]
/// - `login` / `signup` / `share` or `data_share` — navigate to that screen
/// - `full` / `all` / `ui` / `tour` — `api` + `/login` -> `/lo/02/01` -> `/home` (Data Share는 `share` 토큰으로만)
///
/// ```bash
/// flutter run -d chrome --dart-define=QA_CMD=full
/// flutter run -d chrome --dart-define=QA_CMD=api,login,signup,share
/// ```
class QaCmdRunner {
  QaCmdRunner._();

  static const String _raw = String.fromEnvironment('QA_CMD', defaultValue: '');

  static Set<String> get _parts {
    final s = _raw.trim().toLowerCase();
    if (s.isEmpty) return const <String>{};
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static bool get any => _parts.isNotEmpty;

  /// Whether to run [SelfQaRunner] REST checks.
  static bool get wantBackend =>
      _parts.contains('api') ||
      _parts.contains('full') ||
      _parts.contains('all') ||
      _parts.contains('backend');

  static bool get wantUiTour {
    if (!any) return false;
    if (_parts.contains('full') ||
        _parts.contains('all') ||
        _parts.contains('ui') ||
        _parts.contains('tour')) {
      return true;
    }
    return _parts.contains('login') ||
        _parts.contains('signup') ||
        _parts.contains('share') ||
        _parts.contains('data_share');
  }

  static List<String> get _uiRoutesOrdered {
    final p = _parts;
    if (p.contains('full') || p.contains('all') || p.contains('ui') || p.contains('tour')) {
      return const ['/login', '/lo/02/01'];
    }
    final out = <String>[];
    if (p.contains('login')) out.add('/login');
    if (p.contains('signup')) out.add('/lo/02/01');
    if (p.contains('share') || p.contains('data_share')) out.add('/sc/07/01');
    return out;
  }

  static const int _stepMs = 2200;

  static bool _tourArmed = false;
  static bool _tourDone = false;
  static bool _tourCancelled = false;

  /// QR·웜업 등 실제 온보딩이 시작되면 지연 UI 투어를 취소한다.
  static void cancelUiTour() {
    if (_tourCancelled) return;
    _tourCancelled = true;
    _tourDone = true;
    _qaCmdLog('ui tour cancelled (user flow)');
  }

  static void _qaCmdLog(String m) {
    developer.log(m, name: 'QaCmd');
    debugPrint('[QaCmd] $m');
  }

  /// Call from [SplashScreen] initState; starts a delayed UI hop sequence once the navigator exists.
  static void armUiTourTimer() {
    if (!wantUiTour || _tourArmed) return;
    _tourArmed = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 5500), _runUiTour),
    );
  }

  static Future<void> _runUiTour() async {
    if (!wantUiTour || _tourDone || _tourCancelled) return;
    _tourDone = true;
    final routes = _uiRoutesOrdered;
    if (routes.isEmpty) {
      _qaCmdLog('ui tour: no routes');
      return;
    }
    _qaCmdLog('ui tour start -> ${routes.join(' -> ')} -> /home');
    for (var i = 0; i < routes.length; i++) {
      if (_tourCancelled) return;
      final r = routes[i];
      final ok = await AppNav.goNamed(r, replaceStack: i == 0);
      _qaCmdLog('nav $r -> $ok');
      if (i < routes.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: _stepMs));
      }
    }
    if (_tourCancelled) return;
    final homeOk = await AppNav.goNamed('/home', replaceStack: true);
    _qaCmdLog('ui tour done (exit /home -> $homeOk)');
  }
}
