import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'create_account_step4_profile.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// Create Account Step 3: Email & Password (일반 회원가입)
/// iOS HIG: 44pt min touch target, proper keyboard types, autofill hints
class CreateAccountStep3CredentialsPage extends StatefulWidget {
  const CreateAccountStep3CredentialsPage({super.key});

  @override
  State<CreateAccountStep3CredentialsPage> createState() => _CreateAccountStep3CredentialsPageState();
}

class _CreateAccountStep3CredentialsPageState extends State<CreateAccountStep3CredentialsPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _agreeTerms = false;

  static const _minPasswordLength = 8;
  static const _kMinTouchTarget = 44.0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email.';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Invalid email format.';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password.';
    if (v.length < _minPasswordLength) return 'Password must be at least $_minPasswordLength characters.';
    return null;
  }

  String? _validatePasswordConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password.';
    if (v != _passwordCtrl.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service.')),
      );
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final st = await SettingsStorage.load();
        st['signupDraftEmail'] = _emailCtrl.text.trim();
        await SettingsStorage.save(st);
      } catch (_) {}
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateAccountStep4ProfilePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email & Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'example@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: [LengthLimitingTextInputFormatter(32)],
                  decoration: InputDecoration(
                    labelText: 'Password (min $_minPasswordLength chars)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      splashRadius: _kMinTouchTarget / 2,
                    ),
                  ),
                  validator: _validatePassword,
                  onChanged: (_) => setState(() {}), // re-validate confirm
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordConfirmCtrl,
                  obscureText: _obscurePasswordConfirm,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: [LengthLimitingTextInputFormatter(32)],
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                      splashRadius: _kMinTouchTarget / 2,
                    ),
                  ),
                  validator: _validatePasswordConfirm,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: _kMinTouchTarget,
                  child: CheckboxListTile(
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I agree to the Terms of Service and Privacy Policy'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: _kMinTouchTarget + 8,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
