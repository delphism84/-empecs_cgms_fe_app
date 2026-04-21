import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'create_account_step4_profile.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/auth_input_validation.dart';

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
    if (v == null || v.trim().isEmpty) return 'auth_validate_email_empty'.tr();
    if (!isValidLoginEmailId(v)) return 'auth_validate_email_invalid'.tr();
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'auth_validate_password_empty'.tr();
    if (v.length < _minPasswordLength) {
      return 'auth_validate_password_min'.tr(namedArgs: {'n': '$_minPasswordLength'});
    }
    return null;
  }

  String? _validatePasswordConfirm(String? v) {
    if (v == null || v.isEmpty) return 'auth_validate_password_confirm_empty'.tr();
    if (v != _passwordCtrl.text) return 'auth_validate_password_mismatch'.tr();
    return null;
  }

  Future<void> _submit() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth_snackbar_agree_terms'.tr())),
      );
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final st = await SettingsStorage.load();
        st['signupDraftEmail'] = _emailCtrl.text.trim();
        st['signupDraftPassword'] = _passwordCtrl.text;
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
      appBar: AppBar(title: Text('auth_email_password_title'.tr())),
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
                  decoration: InputDecoration(
                    labelText: 'auth_label_email_field'.tr(),
                    hintText: 'auth_hint_email_example'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
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
                    labelText: 'auth_label_password_min'.tr(namedArgs: {'n': '$_minPasswordLength'}),
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
                    labelText: 'auth_label_confirm_password'.tr(),
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
                    title: Text('auth_terms_agree_required'.tr()),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: _kMinTouchTarget + 8,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text('common_next'.tr()),
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
