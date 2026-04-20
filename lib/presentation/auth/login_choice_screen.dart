import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/sign_in_one_screen/sign_in_one_screen.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/presentation/auth/lo_01_02_04_sns_login_process_screens.dart';
import 'package:helpcare/presentation/auth/lo_02_signup_flow_screens.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:easy_localization/easy_localization.dart';

/// Main login selection screen
///
/// LO_01_01: SNS 로그인 (Google/Apple/Kakao)
/// - QA/bot를 위해 특정 플래그가 켜져 있으면 진입 시 자동으로 Easy Login 시트를 연다.
class LoginChoiceScreen extends StatefulWidget {
  const LoginChoiceScreen({super.key});

  @override
  State<LoginChoiceScreen> createState() => _LoginChoiceScreenState();
}

class _LoginChoiceScreenState extends State<LoginChoiceScreen> {
  @override
  void initState() {
    super.initState();
    _markViewedAndMaybeAutoOpen();
  }

  Future<void> _markViewedAndMaybeAutoOpen() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final s = await SettingsStorage.load();
      s['lo0101ViewedAt'] = now;
      final bool autoOpen = s['lo0101AutoOpenEasyLoginSheet'] == true;
      if (autoOpen) s['lo0101AutoOpenEasyLoginSheet'] = false; // one-shot
      await SettingsStorage.save(s);

      if (autoOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showEasyLogin(context);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text('auth_login_title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // splash image on top
            Center(
              child: SizedBox(
                height: size.height * 0.22,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: Image.asset(
                    ImageConstant.appSplash2,
                    errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/splash2.png'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              width: double.infinity,
              text: 'auth_easy_login_upper'.tr(),
              variant: ButtonVariant.FillLoginGreen,
              onTap: () => _showEasyLogin(context),
            ),
            const SizedBox(height: 12),
            CustomButton(
              width: double.infinity,
              text: 'auth_create_account_upper'.tr(),
              variant: ButtonVariant.OutlinePrimaryWhite,
              fontStyle: ButtonFontStyle.GilroyMedium16Primary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const Lo0201SignUpIntroScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              width: double.infinity,
              text: 'auth_existing_login_upper'.tr(),
              variant: ButtonVariant.OutlinePrimaryWhite,
              fontStyle: ButtonFontStyle.GilroyMedium16Primary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignInOneScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              width: double.infinity,
              text: 'auth_continue_guest_upper'.tr(),
              variant: ButtonVariant.OutlinePrimaryWhite,
              fontStyle: ButtonFontStyle.GilroyMedium16Primary,
              onTap: () => _enterGuestMode(context),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _enterGuestMode(BuildContext context) async {
    try {
      final s = await SettingsStorage.load();
      s['guestMode'] = true;
      s['authToken'] = '';
      s['lastUserId'] = '';
      s['displayName'] = 'Guest';
      s['lo0108EnteredAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
      try { AppSettingsBus.notify(); } catch (_) {}
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  Future<void> _markSheetOpened() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0101SheetOpenedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _markProviderTapped(String provider) async {
    try {
      final s = await SettingsStorage.load();
      s['lo0101LastProvider'] = provider.trim();
      s['lo0101LastProviderAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  void _showEasyLogin(BuildContext context) {
    _markSheetOpened();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle, color: Colors.red),
                  title: Text('auth_continue_google'.tr()),
                  onTap: () async {
                    Navigator.pop(context);
                    await _markProviderTapped('google');
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Lo0102GoogleLoginScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.apple),
                  title: Text('auth_continue_apple'.tr()),
                  onTap: () async {
                    Navigator.pop(context);
                    await _markProviderTapped('apple');
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Lo0103AppleLoginScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble, color: Colors.amber),
                  title: Text('auth_continue_kakao'.tr()),
                  onTap: () async {
                    Navigator.pop(context);
                    await _markProviderTapped('kakao');
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Lo0104KakaoLoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('common_close'.tr())),
              ],
            ),
          ),
        );
      },
    );
  }
}


