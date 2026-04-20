import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/auth/create_account_step1.dart';
import 'package:helpcare/presentation/auth/create_account_step4_profile.dart';

/// LO_02_01: 회원가입 안내(진행 여부 선택)
class Lo0201SignUpIntroScreen extends StatefulWidget {
  const Lo0201SignUpIntroScreen({super.key});

  @override
  State<Lo0201SignUpIntroScreen> createState() => _Lo0201SignUpIntroScreenState();
}

class _Lo0201SignUpIntroScreenState extends State<Lo0201SignUpIntroScreen> {
  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0201ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _setChoice(String v) async {
    try {
      final s = await SettingsStorage.load();
      s['lo0201Choice'] = v;
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LO_02_01 · Sign up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text(
              'Sign up',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to sign up?\n\n- With an account you can sync data, share reports, and backup settings.\n- You can sign up later if you prefer.',
              style: TextStyle(color: Colors.black87, height: 1.25),
              textAlign: TextAlign.start,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await _setChoice('start');
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountStep1Page()));
              },
              child: const Text('Sign up'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await _setChoice('later');
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Later (Back to login)'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// LO_02_03: 본인인증(휴대폰 번호 인증) - 모의 플로우
class Lo0203PhoneVerifyScreen extends StatefulWidget {
  const Lo0203PhoneVerifyScreen({super.key, this.nextRoute = '/lo/02/04'});

  final String nextRoute;

  @override
  State<Lo0203PhoneVerifyScreen> createState() => _Lo0203PhoneVerifyScreenState();
}

class _Lo0203PhoneVerifyScreenState extends State<Lo0203PhoneVerifyScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _sent = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0203ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _setPhone(String v) async {
    try {
      final s = await SettingsStorage.load();
      s['lo0203Phone'] = v.trim();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  Future<void> _setVerified() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0203VerifiedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LO_02_03 · Phone verification')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Phone verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.start),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')), LengthLimitingTextInputFormatter(20)],
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '010-1234-5678',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _setPhone(v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _sent = true);
              },
              child: Text(_sent ? 'Resend code' : 'Send code'),
            ),
            const SizedBox(height: 16),
            if (_sent) ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  hintText: '6 digits',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _verified = true);
                  await _setVerified();
                },
                child: const Text('Verify (mock)'),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: !_verified
                  ? null
                  : () {
                      Navigator.of(context).pushReplacementNamed(widget.nextRoute);
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

/// LO_02_05: 회원가입 완료 안내
class Lo0205SignUpCompleteScreen extends StatefulWidget {
  const Lo0205SignUpCompleteScreen({super.key});

  @override
  State<Lo0205SignUpCompleteScreen> createState() => _Lo0205SignUpCompleteScreenState();
}

class _Lo0205SignUpCompleteScreenState extends State<Lo0205SignUpCompleteScreen> {
  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final s = await SettingsStorage.load();
      s['lo0205ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LO_02_05 · Sign up complete')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sign up complete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.start),
            const SizedBox(height: 12),
            const Text(
              'Your account has been created.\nYou can now log in to use the service.',
              style: TextStyle(fontSize: 14, height: 1.3),
              textAlign: TextAlign.start,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
              child: const Text('Go to login'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// LO_02_04 라우트를 기존 Step4로 매핑하기 위한 thin wrapper (QA에서 명확한 ID 표기)
class Lo0204UserInfoWrapperScreen extends StatelessWidget {
  const Lo0204UserInfoWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateAccountStep4ProfilePage();
  }
}

