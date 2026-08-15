import 'dart:async';

import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/sensor_expiry_service.dart';
import 'package:helpcare/presentation/widgets/sensor_expiry_dialogs.dart';

/// 앱 어디에 있든 만료 예고/만료 시트를 띄우는 전역 게이트.
///
/// [SensorExpiryService]는 "언제"만 판단하고, 실제 표시는 여기서 한 곳으로 모은다
/// (화면마다 중복 구현 → 중복 팝업이 되는 것을 막는다).
class SensorExpiryGate extends StatefulWidget {
  const SensorExpiryGate({super.key, required this.child});

  final Widget child;

  @override
  State<SensorExpiryGate> createState() => _SensorExpiryGateState();
}

class _SensorExpiryGateState extends State<SensorExpiryGate>
    with WidgetsBindingObserver {
  StreamSubscription<SensorExpiryStatus>? _sub;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = SensorExpiryService().prompts.listen(_onPrompt);
    SensorExpiryService().start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 포그라운드 복귀 시 즉시 재평가 — 12시간이 지난 뒤 진입하면
    // "진입 시점의 실제 잔여시간"부터 카운트해야 한다(요구 A).
    if (state == AppLifecycleState.resumed) {
      unawaited(SensorExpiryService().evaluate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onPrompt(SensorExpiryStatus s) async {
    if (_showing) return;
    final BuildContext? ctx = AppNav.navigatorKey.currentContext;
    if (ctx == null) return;
    _showing = true;
    try {
      final SensorExpiryAction? action = s.isExpired
          ? await SensorExpiredDialog.show(ctx, s)
          : await SensorExpiryDialog.show(ctx, s);
      if (action == null) return;
      final BuildContext? after = AppNav.navigatorKey.currentContext;
      if (after == null) return;
      await runSensorExpiryAction(after, action);
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
