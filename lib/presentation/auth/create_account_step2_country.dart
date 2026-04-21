import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'create_account_step3_credentials.dart';

/// Create Account Step 2: Country/Language/Agreement
class CreateAccountStep2CountryPage extends StatefulWidget {
  const CreateAccountStep2CountryPage({super.key});
  @override
  State<CreateAccountStep2CountryPage> createState() => _CreateAccountStep2CountryPageState();
}

class _CreateAccountStep2CountryPageState extends State<CreateAccountStep2CountryPage> {
  final List<Map<String, String>> _countries = const [
    {'code': 'KR', 'name': 'South Korea', 'lang': 'Korean'},
    {'code': 'US', 'name': 'United States', 'lang': 'English'},
    {'code': 'JP', 'name': 'Japan', 'lang': 'Japanese'},
    {'code': 'CN', 'name': 'China', 'lang': 'Chinese'},
  ];
  String? _countryCode;
  String? _language;
  bool _agreeResidence = false;

  static const _kMinTouchTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth_country_language_title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('onboarding_select_country'.tr()),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'auth_choose_country_hint'.tr()),
              value: _countryCode,
              items: _countries
                  .map((e) => DropdownMenuItem(value: e['code'], child: Text(e['name']!)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _countryCode = v;
                  _language = _countries.firstWhere((e) => e['code'] == v)['lang'];
                });
              },
            ),
            const SizedBox(height: 16),
            Text('onboarding_select_language'.tr()),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              value: _language,
              items: (_countryCode == null
                      ? _countries
                      : _countries.where((e) => e['code'] == _countryCode))
                  .map((e) => DropdownMenuItem(value: e['lang'], child: Text(e['lang']!)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreeResidence,
              onChanged: (v) => setState(() => _agreeResidence = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('onboarding_country_notices_agree'.tr()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: _kMinTouchTarget + 8,
              child: ElevatedButton(
                onPressed: _countryCode != null && _language != null && _agreeResidence
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateAccountStep3CredentialsPage(),
                        ),
                      );
                    }
                  : null,
                child: Text('common_next'.tr()),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
// no trailing imports


