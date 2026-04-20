import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'package:helpcare/core/config/social_auth_config.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/focus_bus.dart';

/// 실제 소셜 로그인 수행 후 설정 저장. 목업 없음.
class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  static bool _googleInitialized = false;

  Future<void> _ensureGoogleInit() async {
    if (_googleInitialized) return;
    final clientId = SocialAuthConfig.hasGoogleKey ? SocialAuthConfig.googleClientId : null;
    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: SocialAuthConfig.googleServerClientId,
    );
    _googleInitialized = true;
  }

  /// Google 실제 로그인. BE /api/auth/social/verify로 idToken 전송 후 JWT 저장.
  Future<String?> signInWithGoogle() async {
    if (!SocialAuthConfig.hasGoogleKey) {
      return 'Google 클라이언트 ID를 설정해 주세요. (social_auth_config.dart)';
    }
    try {
      await _ensureGoogleInit();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) return 'Google 토큰을 가져올 수 없습니다.';
      return await _verifyAndSaveSession(
        provider: 'google',
        body: {'provider': 'google', 'idToken': idToken},
        email: account.email,
        displayName: account.displayName ?? account.email,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return e.toString();
    } catch (e, st) {
      debugPrint('Google sign-in error: $e $st');
      return e.toString();
    }
  }

  /// Apple 실제 로그인. BE /api/auth/social/verify로 idToken 전송 후 JWT 저장.
  Future<String?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken ?? credential.authorizationCode;
      if (idToken.isEmpty) return 'Apple 토큰을 가져올 수 없습니다.';
      final name = credential.givenName != null || credential.familyName != null
          ? '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim()
          : (credential.email ?? 'Apple User');
      return await _verifyAndSaveSession(
        provider: 'apple',
        body: {'provider': 'apple', 'idToken': idToken, if (name.isNotEmpty) 'name': name},
        email: credential.email ?? '',
        displayName: name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      return e.message;
    } catch (e, st) {
      debugPrint('Apple sign-in error: $e $st');
      return e.toString();
    }
  }

  /// Kakao 실제 로그인. BE /api/auth/social/verify로 accessToken 전송 후 JWT 저장.
  Future<String?> signInWithKakao() async {
    if (!SocialAuthConfig.hasKakaoKey) {
      return 'Kakao 네이티브 앱 키를 설정해 주세요. (social_auth_config.dart 및 Android/iOS 설정)';
    }
    try {
      final oauthToken = await kakao.UserApi.instance.loginWithKakaoTalk();
      final accessToken = oauthToken.accessToken;
      if (accessToken.isEmpty) return 'Kakao 토큰을 가져올 수 없습니다.';
      kakao.User? user;
      try {
        user = await kakao.UserApi.instance.me();
      } catch (_) {}
      final email = user?.kakaoAccount?.email ?? '';
      final name = user?.kakaoAccount?.profile?.nickname ?? user?.kakaoAccount?.email ?? 'Kakao User';
      return await _verifyAndSaveSession(
        provider: 'kakao',
        body: {'provider': 'kakao', 'accessToken': accessToken},
        email: email,
        displayName: name,
      );
    } on kakao.KakaoAuthException catch (e) {
      if (e.error == kakao.AuthErrorCause.accessDenied) return null;
      return e.errorDescription ?? e.toString();
    } catch (e, st) {
      debugPrint('Kakao sign-in error: $e $st');
      return e.toString();
    }
  }

  /// BE POST /api/auth/social/verify 호출 후 JWT를 authToken으로 저장.
  Future<String?> _verifyAndSaveSession({
    required String provider,
    required Map<String, dynamic> body,
    required String email,
    required String displayName,
  }) async {
    try {
      final api = ApiClient();
      final resp = await api.post('/api/auth/social/verify', body: body);
      if (resp.statusCode != 200) {
        try {
          final err = jsonDecode(resp.body) as Map<String, dynamic>?;
          return (err?['error'] ?? err?['message'] ?? resp.body).toString();
        } catch (_) {
          return '서버 오류 (${resp.statusCode})';
        }
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>?;
      final jwt = (data?['token'] ?? data?['accessToken'] ?? data?['jwt']) as String?;
      if (jwt == null || jwt.isEmpty) return '서버 응답에 토큰이 없습니다.';

      final s = await SettingsStorage.load();
      s['guestMode'] = false;
      s['authProvider'] = provider;
      s['authToken'] = jwt;
      s['lastUserId'] = email.isNotEmpty ? email : '${provider}_${DateTime.now().millisecondsSinceEpoch}';
      s['displayName'] = displayName.isNotEmpty ? displayName : (data?['displayName'] ?? data?['name'] ?? '${provider}_user').toString();
      s['lo0101SnsDoneAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
      await api.saveToken(jwt);
      try {
        AppSettingsBus.notify();
      } catch (_) {}
      unawaited(ProfileSyncService.refreshFromServer());
      return null;
    } catch (e, st) {
      debugPrint('social verify error: $e $st');
      return e.toString();
    }
  }
}
