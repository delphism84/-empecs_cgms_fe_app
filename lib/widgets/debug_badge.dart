import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/debug_config.dart';

class DebugBadge extends StatelessWidget {
  const DebugBadge({super.key, required this.child, required this.reqId});
  final Widget child;
  final String reqId; // 요구사항 ID, 예: TG_01_01, AR_01_01 등
  @override
  Widget build(BuildContext context) {
    if (!DebugConfig.overlayEnabled) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 4,
          top: 4,
          child: Tooltip(
            message: 'REQ: $reqId',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reqId,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


