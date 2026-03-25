import 'package:flutter/material.dart';
import 'create_account_step5_confirm.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// Create Account Step 4: First/Last name, DOB, Email, Gender, Unit
class CreateAccountStep4ProfilePage extends StatefulWidget {
  const CreateAccountStep4ProfilePage({super.key});
  @override
  State<CreateAccountStep4ProfilePage> createState() => _CreateAccountStep4ProfilePageState();
}

class _CreateAccountStep4ProfilePageState extends State<CreateAccountStep4ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  static const _kMinTouchTarget = 44.0;
  DateTime? _birth;
  String _gender = 'male';
  String _unit = 'mg/dL';

  @override
  void initState() {
    super.initState();
    _markViewed();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final st = await SettingsStorage.load();
      final draftEmail = (st['signupDraftEmail'] as String? ?? '').trim();
      if (draftEmail.isNotEmpty && _email.text.isEmpty) {
        _email.text = draftEmail;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['lo0204ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  String? _validateRequired(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'Please enter $label.';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email.';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Invalid email format.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Information')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                      validator: (v) => _validateRequired(v, 'First Name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                      validator: (v) => _validateRequired(v, 'Last Name'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  validator: _validateEmail,
                ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(now.year - 20, now.month, now.day),
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: now,
                    );
                    if (picked != null) setState(() => _birth = picked);
                  },
                  child: Text(_birth == null ? 'Select Date of Birth' : '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _gender,
                items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female'))],
                onChanged: (v) => setState(() => _gender = v ?? 'male'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _unit,
                items: const [DropdownMenuItem(value: 'mg/dL', child: Text('mg/dL')), DropdownMenuItem(value: 'mmol', child: Text('mmol'))],
                onChanged: (v) => setState(() => _unit = v ?? 'mg/dL'),
              ),
            ]),
                const SizedBox(height: 24),
                SizedBox(
                  height: _kMinTouchTarget + 8,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        if (_birth == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select date of birth.')),
                          );
                          return;
                        }
                        try {
                          final st = await SettingsStorage.load();
                          st['signupDraftFirstName'] = _firstName.text.trim();
                          st['signupDraftLastName'] = _lastName.text.trim();
                          st['signupDraftEmail'] = _email.text.trim();
                          st['signupDraftDob'] = _birth!.toIso8601String();
                          st['signupDraftGender'] = _gender;
                          st['signupDraftUnit'] = _unit;
                          await SettingsStorage.save(st);
                        } catch (_) {}
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateAccountStep5ConfirmPage()),
                        );
                      }
                    },
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



