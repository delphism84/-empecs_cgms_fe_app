import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Sc0105ManualSnScreen extends StatefulWidget {
  const Sc0105ManualSnScreen({super.key});

  @override
  State<Sc0105ManualSnScreen> createState() => _Sc0105ManualSnScreenState();
}

class _Sc0105ManualSnScreenState extends State<Sc0105ManualSnScreen> {
  final TextEditingController _sn = TextEditingController();
  bool _saving = false;
  String _lastSaved = '';
  String _lastScannedQrFullSn = '';
  String _lastScannedQrAt = '';
  bool _lastScannedQrRegistered = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLastScannedQr();
  }

  Future<void> _loadLastScannedQr() async {
    try {
      final st = await SettingsStorage.load();
      if (!mounted) return;
      setState(() {
        _lastScannedQrFullSn = (st['lastScannedQrFullSn'] as String? ?? '').trim();
        _lastScannedQrAt = (st['lastScannedQrAt'] as String? ?? '').trim();
        _lastScannedQrRegistered = st['lastScannedQrRegistered'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      final String v = (st['sc0105ManualSnValue'] as String? ?? '').trim();
      if (!mounted) return;
      setState(() {
        _lastSaved = v;
        if (v.isNotEmpty) _sn.text = v;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final String input = _sn.text.trim();
    if (_saving) return;
    setState(() => _saving = true);
    try {
      String v = input;
      // 수동 등록에서 SN 미입력 시 MAC을 대체 식별자로 사용
      if (v.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          v = (prefs.getString('cgms.last_mac') ?? '').trim().toUpperCase();
        } catch (_) {}
      }
      if (v.isEmpty) return;

      final st = await SettingsStorage.load();
      final List<dynamic> list = (st['registeredDevices'] as List? ?? <Map<String, dynamic>>[]);
      final Map<String, dynamic> manualEntry = {
        'id': 'SN-${DateTime.now().millisecondsSinceEpoch}',
        'sn': v,
        'fullSn': v,
        'model': '',
        'year': '',
        'sampleFlag': '',
        'registeredAt': DateTime.now().toIso8601String(),
        'source': 'manual_sn',
      };
      // 수동 입력은 항상 최신값으로 덮어쓰기(기존 manual_sn 항목 교체)
      final int idx = list.lastIndexWhere((e) => e is Map && (e['source']?.toString() == 'manual_sn'));
      if (idx >= 0) {
        list[idx] = manualEntry;
      } else {
        list.add(manualEntry);
      }
      st['registeredDevices'] = list;
      st['eqsn'] = v;
      st['sc0105ManualSnAt'] = DateTime.now().toUtc().toIso8601String();
      st['sc0105ManualSnValue'] = v;
      await SettingsStorage.save(st);
      if (!mounted) return;
      setState(() => _lastSaved = v);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SN saved')));
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_05 · Enter Serial Number')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'If QR scan fails, enter the sensor serial number (SN) manually.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sn,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'SN (5 digits)',
                hintText: '00033',
                border: OutlineInputBorder(),
              ),
              maxLength: 5,
            ),
            if (_lastSaved.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Last saved: $_lastSaved', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            if (_lastScannedQrFullSn.isNotEmpty || _lastScannedQrAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Last scanned QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                _lastScannedQrRegistered ? 'SN: $_lastScannedQrFullSn' : 'Unregistered QR SN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _lastScannedQrRegistered ? null : Theme.of(context).colorScheme.error,
                ),
              ),
              if (_lastScannedQrAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _lastScannedQrAt.split('.').first,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save SN'),
            ),
          ],
        ),
      ),
    );
  }
}

