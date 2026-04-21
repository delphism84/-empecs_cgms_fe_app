import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

class Sc0106WarmupScreen extends StatefulWidget {
  const Sc0106WarmupScreen({super.key});

  @override
  State<Sc0106WarmupScreen> createState() => _Sc0106WarmupScreenState();
}

class _Sc0106WarmupScreenState extends State<Sc0106WarmupScreen> {
  Timer? _t;

  DateTime? _startAt;
  DateTime? _endsAt;
  bool _active = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await SettingsStorage.load();
      final String s0 = (st['sc0106WarmupStartAt'] as String? ?? '').trim();
      final String s1 = (st['sc0106WarmupEndsAt'] as String? ?? '').trim();
      final bool active = st['sc0106WarmupActive'] == true;
      final String doneAt = (st['sc0106WarmupDoneAt'] as String? ?? '').trim();
      final DateTime? startAt = s0.isEmpty ? null : DateTime.tryParse(s0);
      final DateTime? endsAt = s1.isEmpty ? null : DateTime.tryParse(s1);
      if (!mounted) return;
      setState(() {
        _startAt = startAt;
        _endsAt = endsAt;
        _active = active;
        _done = doneAt.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _startWarmup({int seconds = 30 * 60}) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime ends = now.add(Duration(seconds: seconds));
    await WarmupState.start(seconds: seconds);
    AlertEngine().invalidateWarmupCache();
    if (!mounted) return;
    setState(() {
      _startAt = now;
      _endsAt = ends;
      _active = true;
      _done = false;
    });
  }

  Future<void> _markDone() async {
    try {
      await WarmupState.completeNow();
      AlertEngine().invalidateWarmupCache();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _active = false;
      _done = true;
    });
  }

  /// 개발자 이스터에그: 시간 롱클릭 시 웜업 스킵
  void _onTimeLongPress() {
    if (!_active || _done) return;
    _markDone();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _tick() {
    if (!_active || _endsAt == null) return;
    final int rem = _remainingSec();
    if (rem <= 0 && !_done) {
      _markDone();
      _navigateHome();
    } else {
      // 화면 갱신용
      if (mounted) setState(() {});
    }
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  int _remainingSec() {
    final DateTime? endsAt = _endsAt;
    if (endsAt == null) return 0;
    final int s = endsAt.difference(DateTime.now().toUtc()).inSeconds;
    return s < 0 ? 0 : s;
  }

  @override
  Widget build(BuildContext context) {
    final int rem = _active ? _remainingSec() : 0;
    final int total = 30 * 60;
    final double progress = _active ? (1.0 - (rem / total).clamp(0, 1)) : (_done ? 1.0 : 0.0);

    final String mm = (rem ~/ 60).toString().padLeft(2, '0');
    final String ss = (rem % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: !(_active && !_done),
      child: Scaffold(
      appBar: AppBar(title: Text('warmup_appbar'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'warmup_title_line'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'warmup_readings_unavailable'.tr(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _done
                                ? 'warmup_complete'.tr()
                                : (_active ? 'warmup_in_progress'.tr() : 'warmup_not_started'.tr()),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              onLongPress: _active && !_done ? _onTimeLongPress : null,
                              child: Text(
                                _active ? '$mm:$ss' : (_done ? '00:00' : '30:00'),
                                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_active && _startAt != null)
                            Text(
                              'warmup_started_at'.tr(namedArgs: {'v': _startAt!.toIso8601String()}),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          if (_active && _endsAt != null)
                            Text(
                              'warmup_ends_at'.tr(namedArgs: {'v': _endsAt!.toIso8601String()}),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          if (!_active && !_done)
                            Text(
                              'warmup_countdown_hint'.tr(),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_active && !_done && kDebugMode)
                    OutlinedButton.icon(
                      onPressed: () => _startWarmup(seconds: total),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('warmup_debug_start'.tr()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}


