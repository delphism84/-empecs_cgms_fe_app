import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/sensor_expiry_service.dart';
import 'package:helpcare/core/utils/sensor_usage.dart';
import 'package:helpcare/presentation/sensor_page/sensor_remove_page.dart';

/// 만료 예고/만료 시트에서 사용자가 고른 행동.
enum SensorExpiryAction {
  /// 새 센서 시작 — 제거 매뉴얼 → 부착 매뉴얼 → QR → 워밍업
  startNew,

  /// 나중에 알림 — 만료 시점에 재알림
  later,

  /// 센서 제거만 — 연결 해제 후 메인
  removeOnly,

  /// 센서 제거 매뉴얼 열람
  removeManual,
}

const Color _kWarn = Color(0xFFE0A100);
const Color _kDanger = Color(0xFFD32F2F);

/// 만료 **12시간 전** 시트.
/// 요구: 남은 사용시간 / 만료 예정 일시 / 12→0 카운트다운 / 자세한 내용 /
///       [새 센서 시작] · [나중에 알림]  (Dexcom 하단 시트 레이아웃 준용)
class SensorExpiryDialog extends StatefulWidget {
  const SensorExpiryDialog({super.key, required this.status});

  final SensorExpiryStatus status;

  static Future<SensorExpiryAction?> show(
      BuildContext context, SensorExpiryStatus status) {
    return showModalBottomSheet<SensorExpiryAction>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SensorExpiryDialog(status: status),
    );
  }

  @override
  State<SensorExpiryDialog> createState() => _SensorExpiryDialogState();
}

class _SensorExpiryDialogState extends State<SensorExpiryDialog> {
  Timer? _tick;
  late Duration _remaining;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    // 재진입 시에도 "진입 시점의 실제 잔여시간"에서 시작해야 하므로 만료 시각 기준으로 매초 재계산한다.
    _remaining = _computeRemaining();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _computeRemaining());
    });
  }

  Duration _computeRemaining() {
    final Duration d = widget.status.expiresAtLocal.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SheetShell(
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: _kWarn, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'sensor_expiry_title'.tr(),
                key: const Key('sensor_expiry_title'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _Row(
          label: 'sensor_expiry_remain'.tr(),
          value: SensorUsage.formatRemainHm(_remaining),
          valueKey: const Key('sensor_expiry_remain_value'),
          emphasize: true,
        ),
        const SizedBox(height: 8),
        _Row(
          label: 'sensor_expiry_at'.tr(),
          value: SensorUsage.formatExpiryAt(widget.status.expiresAtLocal),
          valueKey: const Key('sensor_expiry_at_value'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              'sensor_expiry_detail'.tr(),
              style: const TextStyle(
                  color: Color(0xFF1E9E58), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (_detailsOpen) ...<Widget>[
          const SizedBox(height: 4),
          _DetailBlock(
            title: 'sensor_expiry_detail_remove_title'.tr(),
            body: 'sensor_expiry_detail_remove_body'.tr(),
          ),
          const SizedBox(height: 8),
          _DetailBlock(
            title: 'sensor_expiry_detail_new_title'.tr(),
            body: 'sensor_expiry_detail_new_body'.tr(),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const Key('sensor_expiry_start_new'),
            onPressed: () =>
                Navigator.of(context).pop(SensorExpiryAction.startNew),
            child: Text('sensor_expiry_start_new'.tr()),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            key: const Key('sensor_expiry_later'),
            onPressed: () => Navigator.of(context).pop(SensorExpiryAction.later),
            child: Text('sensor_expiry_later'.tr()),
          ),
        ),
      ],
    );
  }
}

/// **만료 시** 시트 — "사용 기한 종료" / 제거 매뉴얼 / 새 센서 시작 / 센서 제거
class SensorExpiredDialog extends StatelessWidget {
  const SensorExpiredDialog({super.key, required this.status});

  final SensorExpiryStatus status;

  static Future<SensorExpiryAction?> show(
      BuildContext context, SensorExpiryStatus status) {
    return showModalBottomSheet<SensorExpiryAction>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SensorExpiredDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SheetShell(
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.error_outline, color: _kDanger, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'sensor_expired_title'.tr(),
                key: const Key('sensor_expired_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: _kDanger),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Text('sensor_expired_desc'.tr(), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        _Row(
          label: 'sensor_expiry_at'.tr(),
          value: SensorUsage.formatExpiryAt(status.expiresAtLocal),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const Key('sensor_expired_start_new'),
            onPressed: () =>
                Navigator.of(context).pop(SensorExpiryAction.startNew),
            child: Text('sensor_expiry_start_new'.tr()),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            key: const Key('sensor_expired_remove_manual'),
            onPressed: () =>
                Navigator.of(context).pop(SensorExpiryAction.removeManual),
            child: Text('sensor_remove_manual'.tr()),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            key: const Key('sensor_expired_remove_only'),
            onPressed: () =>
                Navigator.of(context).pop(SensorExpiryAction.removeOnly),
            child: Text('sensor_remove'.tr()),
          ),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          key: valueKey,
          style: emphasize
              ? theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: _kWarn)
              : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 시트에서 고른 행동을 실제 화면 전환으로 옮긴다.
/// 새 센서 = 제거 매뉴얼 → 부착 매뉴얼 → QR 스캔 → 워밍업 / 제거만 = 연결 해제 후 메인.
Future<void> runSensorExpiryAction(
    BuildContext context, SensorExpiryAction action) async {
  final NavigatorState nav = Navigator.of(context);
  switch (action) {
    case SensorExpiryAction.later:
      await SensorExpiryService().snoozeWarning();
      return;
    case SensorExpiryAction.removeManual:
      await nav.pushNamed('/sensor/remove');
      return;
    case SensorExpiryAction.removeOnly:
      await _disconnectSensor();
      await nav.pushNamed('/sensor/remove');
      if (!nav.mounted) return;
      nav.popUntil((Route<dynamic> r) => r.isFirst);
      return;
    case SensorExpiryAction.startNew:
      await _disconnectSensor();
      // 여기서 표시 이력을 지우면 안 된다. 센서는 아직 만료 상태라 다음 tick 이
      // 만료 시트를 다시 띄워 교체 안내 화면을 덮어버린다(`isDismissible:false` 라 갇힌다).
      // 이력 키는 `eqsn@시작시각` 이므로 **새 센서를 등록하면** 자동으로 새 키가 되어 다시 알린다.
      if (!nav.mounted) return;
      // 제거 매뉴얼 → (CTA) 부착 매뉴얼 → (CTA) QR 스캔 → 워밍업.
      // 각 단계는 화면의 다음 버튼으로 이어진다(뒤로가기로 진행되지 않게).
      await nav.push(MaterialPageRoute<void>(
        builder: (_) => const SensorRemovePage(nextRoute: '/um/01/01'),
      ));
      return;
  }
}

/// 만료 시에는 연결을 끊고 자동 재연결도 멈춘다(요구 B).
Future<void> _disconnectSensor() async {
  try {
    await BleService().disconnect(clearPersistentPairing: true);
  } catch (_) {}
}
