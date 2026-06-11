import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/sensor_warmup_service.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/warmup_state.dart';
import 'package:helpcare/core/utils/background_sync_gate.dart';
import 'package:helpcare/core/utils/online_monitor.dart';

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
  bool _finishing = false;
  int _warmupEggStage = 0;

  @override
  void initState() {
    super.initState();
    WarmupState.setWarmupUiVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WarmupState.setWarmupUiVisible(false);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      Map<String, dynamic> st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      final String lastEqsn = (st['sc0106WarmupEqsn'] as String? ?? '').trim();
      if (eqsn.isNotEmpty && lastEqsn.isNotEmpty && eqsn != lastEqsn) {
        st['sc0106WarmupDoneAt'] = '';
        st['sc0106WarmupActive'] = false;
        await SettingsStorage.save(st);
      }

      String s0 = (st['sc0106WarmupStartAt'] as String? ?? '').trim();
      String s1 = (st['sc0106WarmupEndsAt'] as String? ?? '').trim();
      bool active = st['sc0106WarmupActive'] == true;
      String doneAt = (st['sc0106WarmupDoneAt'] as String? ?? '').trim();
      DateTime? startAt = s0.isEmpty ? null : DateTime.tryParse(s0);
      DateTime? endsAt = s1.isEmpty ? null : DateTime.tryParse(s1);

      // Warm-up 화면 직접 진입 등으로 start가 누락되면 여기서 보정 시작한다.
      if (doneAt.isEmpty && !active) {
        await WarmupState.start(seconds: 30 * 60, eqsn: eqsn);
        await SensorWarmupService.beginWarmup(eqsn, durationSec: 30 * 60);
        AlertEngine().invalidateWarmupCache();
        st = await SettingsStorage.load();
        s0 = (st['sc0106WarmupStartAt'] as String? ?? '').trim();
        s1 = (st['sc0106WarmupEndsAt'] as String? ?? '').trim();
        active = st['sc0106WarmupActive'] == true;
        doneAt = (st['sc0106WarmupDoneAt'] as String? ?? '').trim();
        startAt = s0.isEmpty ? null : DateTime.tryParse(s0);
        endsAt = s1.isEmpty ? null : DateTime.tryParse(s1);
      }

      if (!mounted) return;
      final bool alreadyDone = doneAt.isNotEmpty && !active;
      setState(() {
        _startAt = startAt;
        _endsAt = endsAt;
        _active = active;
        _done = alreadyDone;
      });
      if (alreadyDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _ensureSnWarmupAlignedWithUiDone();
          if (!mounted) return;
          _navigateHome();
        });
      }
    } catch (_) {}
  }

  Future<void> _startWarmup({int seconds = 30 * 60}) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime ends = now.add(Duration(seconds: seconds));
    String eqsn = '';
    try {
      final st = await SettingsStorage.load();
      eqsn = (st['eqsn'] as String? ?? '').trim();
    } catch (_) {}
    await WarmupState.start(seconds: seconds, eqsn: eqsn);
    await SensorWarmupService.beginWarmup(eqsn, durationSec: seconds);
    AlertEngine().invalidateWarmupCache();
    if (!mounted) return;
    setState(() {
      _startAt = now;
      _endsAt = ends;
      _active = true;
      _done = false;
      _warmupEggStage = 0;
    });
  }

  Future<void> _markDone() async {
    try {
      String eqsn = '';
      try {
        final st = await SettingsStorage.load();
        eqsn = (st['eqsn'] as String? ?? '').trim();
      } catch (_) {}
      await SensorWarmupService.applyUiWarmupSkipped(eqsn);
      await WarmupState.completeNow();
      await SensorWarmupService.refreshFromStorage();
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
    if (!_active || _done || _finishing) return;
    unawaited(_finishWarmupAndGoHome());
  }

  /// QA 이스터에그: "웜업 중..." 더블탭 1회 → 적색, 2회 → 시작 29분 당김(1분 후 종료).
  void _onWarmupStatusDoubleTap() {
    if (!_active || _done || _finishing) return;
    if (_warmupEggStage == 0) {
      setState(() => _warmupEggStage = 1);
      return;
    }
    if (_warmupEggStage == 1) {
      unawaited(_applyWarmupFastForward());
    }
  }

  Future<void> _applyWarmupFastForward() async {
    if (!_active || _done || _finishing) return;
    try {
      String eqsn = '';
      try {
        final st = await SettingsStorage.load();
        eqsn = (st['eqsn'] as String? ?? '').trim();
      } catch (_) {}
      final ({DateTime startUtc, DateTime endsUtc}) shifted =
          await WarmupState.shiftStartBack(back: const Duration(minutes: 29));
      if (eqsn.isNotEmpty) {
        await SensorWarmupService.shiftStartBack(eqsn, back: const Duration(minutes: 29));
      }
      AlertEngine().invalidateWarmupCache();
      if (!mounted) return;
      setState(() {
        _startAt = shifted.startUtc;
        _endsAt = shifted.endsUtc;
        _warmupEggStage = 0;
      });
    } catch (_) {}
  }

  void _tick() {
    if (!_active || _endsAt == null || _finishing) return;
    final int rem = _remainingSec();
    if (rem <= 0 && !_done) {
      unawaited(_finishWarmupAndGoHome());
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _finishWarmupAndGoHome() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await _markDone();
      if (!mounted) return;
      WarmupState.setWarmupUiVisible(false);
      _schedulePostWarmupWork();
      Navigator.of(context).pushReplacementNamed('/home');
    } finally {
      _finishing = false;
    }
  }

  void _schedulePostWarmupWork() {
    // BLE GATT 안정화 후 백그라운드 I/O — notify 재구독·동기화 경합 완화
    unawaited(Future<void>.delayed(const Duration(seconds: 8), () {
      if (WarmupState.isWarmupNow) return;
      BackgroundSyncGate.notifyUiWarmupEnded();
    }));
    unawaited(Future<void>.delayed(const Duration(seconds: 22), () {
      if (WarmupState.isWarmupNow) return;
      OnlineMonitor().schedulePostWarmupSync();
    }));
  }

  Future<void> _ensureSnWarmupAlignedWithUiDone() async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      await SensorWarmupService.applyUiWarmupSkipped(eqsn);
      await SensorWarmupService.refreshFromStorage();
      AlertEngine().invalidateWarmupCache();
    } catch (_) {}
  }

  void _navigateHome() {
    if (!mounted || _finishing) return;
    _finishing = true;
    try {
      WarmupState.setWarmupUiVisible(false);
      _schedulePostWarmupWork();
      Navigator.of(context).pushReplacementNamed('/home');
    } finally {
      _finishing = false;
    }
  }

  int _remainingSec() {
    final DateTime? endsAt = _endsAt;
    if (endsAt == null) return 0;
    final DateTime endsUtc = endsAt.isUtc ? endsAt : endsAt.toUtc();
    final int s = endsUtc.difference(DateTime.now().toUtc()).inSeconds;
    return s < 0 ? 0 : s;
  }

  String _warmupStatusLabel() {
    if (_done) return 'warmup_complete'.tr();
    if (_active) return 'warmup_in_progress'.tr();
    return 'warmup_not_started'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final int rem = _active ? _remainingSec() : 0;
    final int total = 30 * 60;
    final double progress = _active ? (1.0 - (rem / total).clamp(0, 1)) : (_done ? 1.0 : 0.0);

    final String mm = (rem ~/ 60).toString().padLeft(2, '0');
    final String ss = (rem % 60).toString().padLeft(2, '0');
    final bool eggRed = _active && !_done && _warmupEggStage == 1;

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
                          GestureDetector(
                            onDoubleTap: _active && !_done ? _onWarmupStatusDoubleTap : null,
                            child: Text(
                              _warmupStatusLabel(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: eggRed ? Colors.red : null,
                              ),
                            ),
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
