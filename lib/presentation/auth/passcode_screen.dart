import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/passcode.dart';
import 'package:helpcare/presentation/home.dart';
import 'package:helpcare/presentation/auth/login_choice_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:helpcare/presentation/auth/passcode_reset_screen.dart';

class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onCompleted(String code) async {
    final String c = code.trim();
    if (!Passcode.isValid(c)) return;
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final st = await SettingsStorage.load();
      final bool enabled = st['passcodeEnabled'] == true;
      final String stored = (st['passcodeHash'] as String? ?? '').trim();
      final String h = Passcode.hash(c);
      final bool ok = enabled && stored.isNotEmpty && stored == h;
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Invalid passcode';
          _ctrl.text = '';
        });
        return;
      }

      // 성공: 토큰이 있으면 홈, 없으면 로그인 선택 화면으로
      final String token = (st['authToken'] as String? ?? '').trim();
      if (!mounted) return;
      if (token.isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Home()),
          (Route<dynamic> r) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginChoiceScreen()),
          (Route<dynamic> r) => false,
        );
      }
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Easy Passcode (LO_01_05)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Text(
                'Enter 4-digit passcode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 12),
              PinCodeTextField(
                appContext: context,
                length: 4,
                controller: _ctrl,
                autoFocus: true,
                keyboardType: TextInputType.number,
                enableActiveFill: true,
                obscureText: true,
                obscuringCharacter: '●',
                animationType: AnimationType.fade,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                  fieldHeight: 54,
                  fieldWidth: 54,
                  activeFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                  activeColor: primary,
                  selectedColor: primary,
                  inactiveColor: Colors.black12,
                ),
                onCompleted: _onCompleted,
                onChanged: (_) {
                  if (_error != null) setState(() { _error = null; });
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              Text(
                'Numeric keypad will be shown automatically.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _busy ? null : () => _onCompleted(_ctrl.text),
                child: Text(_busy ? 'Checking...' : 'Unlock'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasscodeResetScreen()),
                  );
                },
                child: const Text('Reset passcode (LO_03_01)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

