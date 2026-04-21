import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/dashboard/memo_modal.dart';

/// ME_01_01: 이벤트 기록(팝업)
///
/// 실제 앱에서는 `MainDashboardPage`/`ChartPage`에서 bottom sheet로 열리지만,
/// 자동 QA 캡처를 위해 단독 화면 라우트를 제공한다.
class Me0101EventEditorScreen extends StatefulWidget {
  const Me0101EventEditorScreen({super.key});

  @override
  State<Me0101EventEditorScreen> createState() => _Me0101EventEditorScreenState();
}

class _Me0101EventEditorScreenState extends State<Me0101EventEditorScreen> {
  Map<String, dynamic> _payload = const {};

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      final st = await SettingsStorage.load();
      st['me0101ViewedAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _markSaved() async {
    try {
      final String type = (_payload['type'] as String? ?? '').toString();
      final st = await SettingsStorage.load();
      st['me0101SavedAt'] = DateTime.now().toUtc().toIso8601String();
      st['me0101SavedType'] = type;
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('me0101_appbar'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: MemoModalContent(
                onChanged: (p) => _payload = p,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _markSaved();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(_payload);
                },
                child: Text('me0101_save_evidence'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

