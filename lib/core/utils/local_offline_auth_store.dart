import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Offline (local-only) sign-in: **only** the last successful login id + password
/// verifier (salted SHA-256). Plaintext password is not stored for offline use.
/// After the next online login success, [writeCredentials] overwrites salt/hash — no
/// separate password-change handling.
///
/// Legacy `localAccounts` (plaintext) is migrated once then cleared.
class LocalOfflineAuthStore {
  static const String kOfflineLastLoginEmail = 'offlineLastLoginEmail';
  static const String kOfflinePwSaltHex = 'offlinePwSaltHex';
  static const String kOfflinePwHashHex = 'offlinePwHashHex';

  static String _digest(String saltHex, String plaintextPassword) {
    final payload = '$saltHex\$empecs.cgms.offline.v1\$$plaintextPassword';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Persists verifier for [email] / [plaintextPassword] and drops legacy multi-account list.
  static void writeCredentials(Map<String, dynamic> st, String email, String plaintextPassword) {
    final salt = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    st[kOfflineLastLoginEmail] = email.trim();
    st[kOfflinePwSaltHex] = salt;
    st[kOfflinePwHashHex] = _digest(salt, plaintextPassword);
    st['localAccounts'] = <dynamic>[];
  }

  /// Constant-time compare of hex digests (same length).
  static bool _constTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Returns true only if [email] matches last successful id and [plaintextPassword] matches verifier.
  static bool verify(Map<String, dynamic> st, String email, String plaintextPassword) {
    final storedEmail = (st[kOfflineLastLoginEmail] as String? ?? '').trim();
    final salt = (st[kOfflinePwSaltHex] as String? ?? '').trim();
    final hash = (st[kOfflinePwHashHex] as String? ?? '').trim();
    if (storedEmail.isEmpty || salt.isEmpty || hash.isEmpty) return false;
    if (storedEmail.toLowerCase() != email.trim().toLowerCase()) return false;
    final computed = _digest(salt, plaintextPassword);
    return _constTimeEquals(computed, hash);
  }

  static DateTime? _parseTs(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s.trim());
  }

  /// If new-style offline credentials are missing, build them from legacy `localAccounts`
  /// (prefer `savedLoginEmail`, then `lastUserId`, else most recently `updatedAt`/`createdAt`).
  /// Returns true if [st] was mutated (caller should [SettingsStorage.save]).
  static bool migrateLegacyIfNeeded(Map<String, dynamic> st) {
    final existing = (st[kOfflinePwHashHex] as String? ?? '').trim();
    if (existing.isNotEmpty) return false;

    final raw = st['localAccounts'];
    if (raw is! List || raw.isEmpty) return false;

    final saved = (st['savedLoginEmail'] as String? ?? '').trim().toLowerCase();
    final lastUid = (st['lastUserId'] as String? ?? '').trim().toLowerCase();

    Map<String, dynamic>? pick;
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final em = (m['email'] as String? ?? '').trim().toLowerCase();
      if (em.isNotEmpty && em == saved) {
        pick = m;
        break;
      }
    }
    if (pick == null) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final em = (m['email'] as String? ?? '').trim().toLowerCase();
        if (em.isNotEmpty && em == lastUid) {
          pick = m;
          break;
        }
      }
    }
    if (pick == null) {
      DateTime bestAt = DateTime.fromMillisecondsSinceEpoch(0);
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final at = _parseTs(m['updatedAt'] as String?) ?? _parseTs(m['createdAt'] as String?) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (at.isAfter(bestAt)) {
          bestAt = at;
          pick = m;
        }
      }
    }

    final email = (pick?['email'] as String? ?? '').trim();
    final pw = pick?['password'] as String? ?? '';
    if (email.isEmpty || pw.isEmpty) return false;

    writeCredentials(st, email, pw);
    return true;
  }
}
