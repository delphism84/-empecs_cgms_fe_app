import 'dart:async';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/qa_route_web.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), (){
      if(!mounted) return;
      _goNext();
    });
  }

  Future<void> _goNext() async {
    final String? qaRoute = getQaInitialRoute();
    if (qaRoute != null && mounted) {
      Navigator.of(context).pushReplacementNamed(qaRoute);
      return;
    }
    try {
      final st = await SettingsStorage.load();
      final String token = (st['authToken'] as String? ?? '').trim();
      final bool bioEnabled = st['biometricEnabled'] == true;
      if (bioEnabled && token.isNotEmpty) {
        Navigator.of(context).pushReplacementNamed('/biometric/gate');
        return;
      }
      final bool enabled = st['passcodeEnabled'] == true;
      final String h = (st['passcodeHash'] as String? ?? '').trim();
      if (enabled && h.isNotEmpty) {
        Navigator.of(context).pushReplacementNamed('/passcode');
        return;
      }
    } catch (_) {}
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose(){
    _timer?.cancel();
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
