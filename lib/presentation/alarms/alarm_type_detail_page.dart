import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/presentation/settings_page/alarm_detail_page.dart';

class AlarmTypeDetailPage extends StatefulWidget {
  const AlarmTypeDetailPage({
    super.key,
    required this.type,
    required this.title,
    required this.reqId,
  });

  final String type; // very_low|low|high|rate|system
  final String title;
  final String reqId;

  @override
  State<AlarmTypeDetailPage> createState() => _AlarmTypeDetailPageState();
}

class _AlarmTypeDetailPageState extends State<AlarmTypeDetailPage> {
  final SettingsService _svc = SettingsService();
  bool _loading = true;
  Map<String, dynamic>? _alarm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _seedLocal(String type) {
    return {
      '_id': 'local:$type',
      'type': type,
      'enabled': true,
      'threshold': type == 'system'
          ? -88
          : type == 'very_low'
              ? 55
              : type == 'low'
                  ? 70
                  : type == 'high'
                      ? 180
                      : type == 'rate'
                          ? 2
                          : null,
      'quietFrom': '22:00',
      'quietTo': '07:00',
      'sound': true,
      'vibrate': true,
      'repeatMin': 10,
      if (type == 'very_low') 'overrideDnd': true,
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, dynamic>? one;
    // 1) server
    try {
      final list = await _svc.listAlarms();
      one = list.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['type'] ?? '').toString() == widget.type,
            orElse: () => <String, dynamic>{},
          );
      if (one.isEmpty) one = null;
    } catch (_) {}
    // 2) local cache
    if (one == null) {
      try {
        final st = await SettingsStorage.load();
        final dynamic v = st['alarmsCache'];
        if (v is List) {
          final list = v.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
          one = list.firstWhere(
            (a) => (a['type'] ?? '').toString() == widget.type,
            orElse: () => <String, dynamic>{},
          );
          if (one.isEmpty) one = null;
        }
      } catch (_) {}
    }
    one ??= _seedLocal(widget.type);

    if (!mounted) return;
    setState(() {
      _alarm = one;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _alarm == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return AlarmDetailPage(
      alarm: _alarm ?? _seedLocal(widget.type),
      title: widget.title,
      fixedType: widget.type,
      hideTypePicker: true,
    );
  }
}

