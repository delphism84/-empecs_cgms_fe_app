import 'dart:async';

import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/presentation/settings_page/alarm_detail_page.dart';

class AlarmTypeDetailPage extends StatefulWidget {
  const AlarmTypeDetailPage({
    super.key,
    required this.type,
    required this.title,
    required this.reqId,
    this.initialAlarm,
  });

  final String type; // very_low|low|high|rate|system
  final String title;
  final String reqId;
  /// 알림 목록에서 이미 알고 있는 설정 — 진입 시 로딩 스피너 생략.
  final Map<String, dynamic>? initialAlarm;

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
    final Map<String, dynamic>? seed = widget.initialAlarm;
    if (seed != null && seed.isNotEmpty) {
      _alarm = Map<String, dynamic>.from(seed);
      SettingsService.normalizeAlarmMethodFields(_alarm!);
      _loading = false;
    } else {
      unawaited(_load());
    }
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
    if (mounted) setState(() => _loading = true);
    Map<String, dynamic>? one;
    try {
      final list = await _svc.listAlarms();
      for (final a in list) {
        if ((a['type'] ?? '').toString() == widget.type) {
          one = a;
          break;
        }
      }
    } catch (_) {}
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
      alarm: _alarm!,
      title: widget.title,
      fixedType: widget.type,
      hideTypePicker: true,
    );
  }
}
