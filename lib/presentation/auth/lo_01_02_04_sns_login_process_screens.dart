import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/social_auth_service.dart';

class Lo0102GoogleLoginScreen extends StatefulWidget {
  const Lo0102GoogleLoginScreen({super.key});

  @override
  State<Lo0102GoogleLoginScreen> createState() => _Lo0102GoogleLoginScreenState();
}

class _Lo0102GoogleLoginScreenState extends State<Lo0102GoogleLoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0102ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    final err = await SocialAuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() { _loading = false; _error = err; });
    if (err == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SnsLoginProcessScaffold(
      title: 'LO_01_02 · Google Login',
      subtitle: 'Google 계정으로 로그인',
      error: _error,
      loading: _loading,
      onSignIn: _signIn,
      onBackToLogin: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
    );
  }
}

class Lo0103AppleLoginScreen extends StatefulWidget {
  const Lo0103AppleLoginScreen({super.key});

  @override
  State<Lo0103AppleLoginScreen> createState() => _Lo0103AppleLoginScreenState();
}

class _Lo0103AppleLoginScreenState extends State<Lo0103AppleLoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0103ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    final err = await SocialAuthService.instance.signInWithApple();
    if (!mounted) return;
    setState(() { _loading = false; _error = err; });
    if (err == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SnsLoginProcessScaffold(
      title: 'LO_01_03 · Apple Login',
      subtitle: 'Apple ID로 로그인',
      error: _error,
      loading: _loading,
      onSignIn: _signIn,
      onBackToLogin: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
    );
  }
}

class Lo0104KakaoLoginScreen extends StatefulWidget {
  const Lo0104KakaoLoginScreen({super.key});

  @override
  State<Lo0104KakaoLoginScreen> createState() => _Lo0104KakaoLoginScreenState();
}

class _Lo0104KakaoLoginScreenState extends State<Lo0104KakaoLoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0104ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    final err = await SocialAuthService.instance.signInWithKakao();
    if (!mounted) return;
    setState(() { _loading = false; _error = err; });
    if (err == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SnsLoginProcessScaffold(
      title: 'LO_01_04 · Kakao Login',
      subtitle: '카카오 계정으로 로그인',
      error: _error,
      loading: _loading,
      onSignIn: _signIn,
      onBackToLogin: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
    );
  }
}

class _SnsLoginProcessScaffold extends StatelessWidget {
  const _SnsLoginProcessScaffold({
    required this.title,
    required this.subtitle,
    this.error,
    this.loading = false,
    required this.onSignIn,
    required this.onBackToLogin,
  });

  final String title;
  final String subtitle;
  final String? error;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(subtitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : onSignIn,
              child: loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text('auth_sign_in'.tr()),
            ),
            const Spacer(),
            TextButton(
              onPressed: onBackToLogin,
              child: Text('auth_back_to_login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

