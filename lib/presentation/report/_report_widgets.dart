import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

class MathHelper {
  static double sqrt(double v) {
    // fast sqrt wrapper without importing dart:math in multiple files
    return v <= 0 ? 0 : _sqrt(v);
  }

  static double _sqrt(double v) {
    double x = v;
    double last;
    do {
      last = x;
      x = 0.5 * (x + v / x);
    } while ((last - x).abs() > 1e-9);
    return x;
  }
}
// removed duplicate import; kept at top

class ReportCard extends StatelessWidget {
  const ReportCard({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: getPadding(all: 12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(getHorizontalSize(12)),
        border: Border.all(color: ColorConstant.green500, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: getFontSize(16), fontWeight: FontWeight.w700, color: ColorConstant.green500), overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 2),
              ]),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}


