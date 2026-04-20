import 'dart:convert';

import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// BE `GET /api/auth/me`로 프로필 갱신. 실패 시 무시(로컬 유지).
/// JWT 클레임으로 `lastUserId` / `displayName`이 비어 있을 때 로컬 보강.
class ProfileSyncService {
  ProfileSyncService._();

  static String str(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  static bool _isPlaceholderToken(String t) {
    return t.isEmpty ||
        t == 'OFFLINE_USER_TOKEN' ||
        t.startsWith('LOCAL_USER') ||
        t.startsWith('local-');
  }

  static bool looksLikeJwt(String token) => token.split('.').length == 3;

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

  /// 설정 화면 등에서 토큰은 있는데 user 키가 비어 있을 때 JWT에서만 보강 (동기 저장).
  static Future<void> ensureLocalUserFromJwt() async {
    try {
      final st = await SettingsStorage.load();
      final tok = str(st['authToken']);
      if (_isPlaceholderToken(tok)) return;
      if (!looksLikeJwt(tok)) return;

      final m = decodeJwtPayload(tok);
      if (m == null) return;

      String uid = str(st['lastUserId']);
      String dn = str(st['displayName']);
      bool changed = false;

      String em = str(m['email']);
      if (em.isEmpty) em = str(m['preferred_username']);
      final sub = str(m['sub']);

      String name = str(m['name']);
      if (name.isEmpty) {
        name = '${str(m['given_name'])} ${str(m['family_name'])}'.trim();
      }

      if (uid.isEmpty) {
        if (em.isNotEmpty) {
          st['lastUserId'] = em;
          changed = true;
        } else if (sub.isNotEmpty) {
          st['lastUserId'] = sub;
          changed = true;
        }
      }

      if (dn.isEmpty) {
        final label = name.isNotEmpty
            ? name
            : (em.isNotEmpty ? em : (sub.isNotEmpty ? sub : ''));
        if (label.isNotEmpty) {
          st['displayName'] = label;
          changed = true;
        }
      }

      if (changed) {
        st['guestMode'] = false;
        await SettingsStorage.save(st);
        try {
          AppSettingsBus.notify();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }

  static void _applyMeMap(Map<String, dynamic> data, Map<String, dynamic>? nested) {
    // flat
    String email = str(data['email']);
    String fn = str(data['firstName']);
    String ln = str(data['lastName']);
    String dn = str(data['displayName']);
    String name = str(data['name']);
    // nested user { ... }
    if (nested != null) {
      if (email.isEmpty) email = str(nested['email']);
      if (fn.isEmpty) fn = str(nested['firstName']);
      if (ln.isEmpty) ln = str(nested['lastName']);
      if (dn.isEmpty) dn = str(nested['displayName']);
      if (name.isEmpty) name = str(nested['name']);
    }
    final composed = dn.isNotEmpty
        ? dn
        : (name.isNotEmpty ? name : [fn, ln].where((x) => x.isNotEmpty).join(' ').trim());
    // caller merges into storage
    data['_resolvedEmail'] = email;
    data['_resolvedDisplayName'] = composed;
  }

  static Future<void> refreshFromServer() async {
    try {
      await ensureLocalUserFromJwt();

      final st = await SettingsStorage.load();
      final token = str(st['authToken']);
      if (_isPlaceholderToken(token)) return;

      final api = ApiClient();
      await api.loadToken();
      final resp = await api.get('/api/auth/me');
      if (resp.statusCode != 200) {
        await ensureLocalUserFromJwt();
        return;
      }
      final raw = jsonDecode(resp.body);
      if (raw is! Map<String, dynamic>) {
        final m = _asStringKeyMap(raw);
        if (m == null) return;
        await _persistProfileFromMe(m);
        return;
      }
      await _persistProfileFromMe(raw);
    } catch (_) {
      try {
        await ensureLocalUserFromJwt();
      } catch (_) {}
    }
  }

  static Future<void> _persistProfileFromMe(Map<String, dynamic> data) async {
    final nested = _asStringKeyMap(data['user']) ?? _asStringKeyMap(data['profile']);
    _applyMeMap(data, nested);

    String email = str(data['_resolvedEmail']);
    String composed = str(data['_resolvedDisplayName']);

    if (email.isEmpty && nested != null) {
      email = str(nested['username']);
    }
    if (email.isEmpty) email = str(data['sub']);
    if (email.isEmpty && nested != null) email = str(nested['id']);

    final s2 = await SettingsStorage.load();
    if (email.isNotEmpty) s2['lastUserId'] = email;
    if (composed.isNotEmpty) {
      s2['displayName'] = composed;
    } else if (email.isNotEmpty && str(s2['displayName']).isEmpty) {
      s2['displayName'] = email;
    }
    s2['guestMode'] = false;
    await SettingsStorage.save(s2);
    await ApiClient().loadToken();
    try {
      AppSettingsBus.notify();
    } catch (_) {}
  }
}
