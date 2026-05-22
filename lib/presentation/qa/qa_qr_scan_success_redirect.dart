import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// QA 전용: QR 스캔 성공 상태를 저장한 뒤 BLE 스캔 화면(SC_01_01)으로 이동.
/// 웹에서 #/qa/qr-scan-success 로 진입 시 사용.
class QaQrScanSuccessRedirect extends StatefulWidget {
  const QaQrScanSuccessRedirect({super.key});

  @override
  State<QaQrScanSuccessRedirect> createState() => _QaQrScanSuccessRedirectState();
}

class _QaQrScanSuccessRedirectState extends State<QaQrScanSuccessRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAndGo());
  }

  Future<void> _applyAndGo() async {
    const String fullSn = 'C21ZS00033';
    const String serial = '00033';
    try {
      final s = await SettingsStorage.load();
      final List list = (s['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
      list.add({
        'id': 'QR-${DateTime.now().millisecondsSinceEpoch}',
        'sn': serial,
        'fullSn': fullSn,
        'model': 'C21',
        'year': '2025',
        'sampleFlag': 'S',
        'registeredAt': DateTime.now().toIso8601String(),
      });
      s['registeredDevices'] = list;
      s['eqsn'] = fullSn;
      await SettingsStorage.save(s);
    } catch (_) {}
    if (!mounted) return;
    await AppNav.goNamed('/sc/01/01/scan', replaceStack: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('qa_qr_scan_redirect_message'.tr()),
          ],
        ),
      ),
    );
  }
}

/// Web QA: snapshot for login / data-share checks (no token body, no passwords).
class QaWebCheckScreen extends StatefulWidget {
  const QaWebCheckScreen({super.key});

  @override
  State<QaWebCheckScreen> createState() => _QaWebCheckScreenState();
}

class _QaWebCheckScreenState extends State<QaWebCheckScreen> {
  String _json = '';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final st = await SettingsStorage.load();
      final String token = (st['authToken'] as String? ?? '').trim();
      final int glucoseCount = await GlucoseLocalRepo().count();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      final Map<String, dynamic> bounds = await GlucoseLocalRepo().rangeBounds(
        eqsn: eqsn.isEmpty ? null : eqsn,
        userId: (st['lastUserId'] as String? ?? '').trim(),
      );
      final Map<String, Object?> snap = <String, Object?>{
        'platform': kIsWeb ? 'web' : 'native',
        'guestMode': st['guestMode'],
        'lastUserId': (st['lastUserId'] as String? ?? '').toString().isEmpty
            ? '(empty)'
            : (st['lastUserId'] as String? ?? '').toString(),
        'hasAuthToken': token.isNotEmpty,
        'tokenLength': token.length,
        'eqsn': eqsn.isEmpty ? '(empty)' : eqsn,
        'sc0701Format': st['sc0701Format'],
        'sc0701Enabled': st['sc0701Enabled'],
        'sc0701LastSharedOk': st['sc0701LastSharedOk'],
        'sc0701LastFilePath': (st['sc0701LastFilePath'] as String? ?? '').toString().isEmpty
            ? '(none)'
            : '(set)',
        'glucoseLocalCount': glucoseCount,
        'glucoseRangeBounds': bounds,
      };
      _json = const JsonEncoder.withIndent('  ').convert(snap);
    } catch (e) {
      _json = '{"error": "${e.toString().replaceAll('"', "'")}"}';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QA web check'),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: SelectableText(_json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
        ),
      ),
    );
  }
}
