import 'dart:async';

import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

import 'package:helpcare/core/utils/qa_route_web.dart';
import 'package:helpcare/core/utils/self_qa_runner.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    QaCmdRunner.armUiTourTimer();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final bool webQaEntry = getQaInitialRoute() != null;
    if (SelfQaRunner.shouldRunBackend) {
      await SelfQaRunner.runIfEnabled();
      if (mounted) await Future<void>.delayed(const Duration(milliseconds: 400));
    } else if (webQaEntry) {
      if (mounted) await Future<void>.delayed(const Duration(milliseconds: 250));
    } else if (QaCmdRunner.any) {
      if (mounted) await Future<void>.delayed(const Duration(milliseconds: 400));
    } else {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (!mounted) return;
    await _goNext();
  }

  Future<void> _goNext() async {
    final String? qaRoute = getQaInitialRoute();
    if (qaRoute != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(qaRoute);
      return;
    }
    try {
      final st = await SettingsStorage.load();
      if (!mounted) return;
      if (await WarmupState.isActive()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/sc/01/06');
        return;
      }
      final String token = (st['authToken'] as String? ?? '').trim();
      final bool bioEnabled = st['biometricEnabled'] == true;
      if (bioEnabled && token.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/biometric/gate');
        return;
      }
      final bool enabled = st['passcodeEnabled'] == true;
      final String h = (st['passcodeHash'] as String? ?? '').trim();
      if (enabled && h.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/passcode');
        return;
      }
      // 유효 토큰이 있으면 콜드 스타트에서도 로그인 유지.
      // (바이오/패스코드 미설정 시에도 /login 으로 튕기지 않게 — Doze/재기동 후 '랜덤 로그아웃' 방지)
      if (token.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: getPadding(
                    left: 0,
                    top: 0,
                    right: 0,
                  ),
                  child: CommonImageView(
                    imagePath: ImageConstant.appSplash,
                    height: size.height * 0.3,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      
    );
  }
}
