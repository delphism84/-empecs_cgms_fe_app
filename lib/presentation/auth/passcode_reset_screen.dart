import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

class PasscodeResetScreen extends StatefulWidget {
  const PasscodeResetScreen({super.key});

  @override
  State<PasscodeResetScreen> createState() => _PasscodeResetScreenState();
}

class _PasscodeResetScreenState extends State<PasscodeResetScreen> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_busy) return;
    final String email = _id.text.trim();
    final String password = _pw.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() { _error = 'Enter ID / Password'; });
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final api = ApiClient();
      final resp = await api.post('/api/auth/login', body: {'email': email, 'password': password});
      if (resp.statusCode != 200) {
        setState(() { _error = 'Invalid member information'; });
        return;
      }
      // 로그인 성공이면 passcode 초기화
      final st = await SettingsStorage.load();
      st['passcodeEnabled'] = false;
      st['passcodeHash'] = '';
      await SettingsStorage.save(st);

      // 로그인 화면으로 이동
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passcode reset completed')));
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (e) {
      setState(() { _error = 'Reset failed: $e'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passcode reset (LO_03_01)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Enter member information to reset passcode.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _id,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _reset,
              child: Text(_busy ? 'Resetting...' : 'Reset passcode'),
            ),
            const SizedBox(height: 10),
            Text(
              'Reset will disable the easy passcode.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

