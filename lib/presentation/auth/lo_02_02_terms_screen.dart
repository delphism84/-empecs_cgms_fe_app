import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// LO_02_02: 약관동의
///
/// 기존 가입 플로우(CreateAccountStep3)에도 약관/개인정보 동의 UI가 있으나,
/// 자동 QA 캡처/검수를 위해 별도 라우트 화면을 제공한다.
class Lo0202TermsScreen extends StatefulWidget {
  const Lo0202TermsScreen({super.key});

  @override
  State<Lo0202TermsScreen> createState() => _Lo0202TermsScreenState();
}

class _Lo0202TermsScreenState extends State<Lo0202TermsScreen> {
  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool agreeAge = false;
  bool agreeMarketing = false;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['lo0202ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _markAgreed() async {
    try {
      final st = await SettingsStorage.load();
      st['lo0202AgreedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  void _openDoc(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              child: Text(body),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canNext = agreeTerms && agreePrivacy && agreeAge;
    return Scaffold(
      appBar: AppBar(title: Text('terms_appbar'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('terms_tos_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: agreeTerms,
              onChanged: (v) => setState(() => agreeTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('terms_required_tos_label'.tr()),
              secondary: TextButton(onPressed: () => _openDoc('terms_tos_title'.tr(), _termsText), child: Text('terms_view'.tr())),
            ),
            CheckboxListTile(
              value: agreePrivacy,
              onChanged: (v) => setState(() => agreePrivacy = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('terms_required_privacy_label'.tr()),
              secondary: TextButton(onPressed: () => _openDoc('terms_privacy_title'.tr(), _privacyText), child: Text('terms_view'.tr())),
            ),
            CheckboxListTile(
              value: agreeAge,
              onChanged: (v) => setState(() => agreeAge = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('terms_required_age_label'.tr()),
            ),
            CheckboxListTile(
              value: agreeMarketing,
              onChanged: (v) => setState(() => agreeMarketing = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('terms_optional_marketing_label'.tr()),
              secondary: TextButton(onPressed: () => _openDoc('terms_marketing_title'.tr(), _marketingText), child: Text('terms_view'.tr())),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: !canNext
                  ? null
                  : () async {
                      await _markAgreed();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
              child: Text('terms_agree_continue'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

const String _termsText = 'Terms of Service\n\n(placeholder)\n\n- Will be replaced with the latest version at release.';
const String _privacyText = 'Privacy Policy\n\n(placeholder)\n\n- Will be replaced with the latest version at release.';
const String _marketingText = 'Marketing Consent\n\n(placeholder)\n\n- Marketing consent is optional.';

