import 'package:flutter/material.dart';

Size _getSize() {
  try {
    final w = WidgetsBinding.instance.window;
    final s = w.physicalSize / w.devicePixelRatio;
    if (s.width > 0 && s.height > 0 && s.width.isFinite && s.height.isFinite) {
      return s;
    }
  } catch (_) {}
  return const Size(375, 759);
}

Size size = _getSize();

///This method is used to set padding/margin (for the left and Right side) & width of the screen or widget according to the Viewport width.
double getHorizontalSize(double px) {
  if (px <= 0) return 0;
  final w = size.width > 0 ? size.width : 375.0;
  final r = px * (w / 375);
  return r < 0 ? 0 : r;
}

///This method is used to set padding/margin (for the top and bottom side) & height of the screen or widget according to the Viewport height.
double getVerticalSize(double px) {
  if (px <= 0) return 0;
  try {
    num statusBar =
        MediaQueryData.fromView(WidgetsBinding.instance.window).viewPadding.top;
    num screenHeight = (size.height > 0 ? size.height : 759.0) - statusBar;
    if (screenHeight <= 0) screenHeight = 759.0;
    final r = px * (screenHeight / 759.0);
    return r < 0 ? 0 : r;
  } catch (_) {
    return px;
  }
}

///This method is used to set text font size according to Viewport
double getFontSize(double px) {
  if (px <= 0) return 1.0;
  var height = getVerticalSize(px);
  var width = getHorizontalSize(px);
  var base = height < width ? height : width;
  if (base <= 0) return px.clamp(1.0, 999.0);
  // scale down all fonts globally by ~30%
  final r = base * 0.7;
  return r < 1 ? 1.0 : r;
}

///This method is used to set smallest px in image height and width
double getSize(double px) {
  if (px <= 0) return 0;
  var height = getVerticalSize(px);
  var width = getHorizontalSize(px);
  if (height < 0) height = 0;
  if (width < 0) width = 0;
  if (height < width) {
    return height.toInt().toDouble();
  } else {
    return width.toInt().toDouble();
  }
}

///This method is used to set padding responsively
EdgeInsetsGeometry getPadding({
  double? all,
  double? left,
  double? top,
  double? right,
  double? bottom,
}) {
  if (all != null) {
    left = all;
    top = all;
    right = all;
    bottom = all;
  }
  double _clamp(double v) => v.isNaN || v.isNegative ? 0 : v;
  final double l = _clamp(getHorizontalSize(left ?? 0));
  final double t = _clamp(getVerticalSize(top ?? 0));
  final double r = _clamp(getHorizontalSize(right ?? 0));
  final double b = _clamp(getVerticalSize(bottom ?? 0));
  return EdgeInsets.only(left: l, top: t, right: r, bottom: b);
}

///This method is used to set margin responsively
EdgeInsetsGeometry getMargin({
  double? all,
  double? left,
  double? top,
  double? right,
  double? bottom,
}) {
  if (all != null) {
    left = all;
    top = all;
    right = all;
    bottom = all;
  }
  double _clamp(double v) => v.isNaN || v.isNegative ? 0 : v;
  final double l = _clamp(getHorizontalSize(left ?? 0));
  final double t = _clamp(getVerticalSize(top ?? 0));
  final double r = _clamp(getHorizontalSize(right ?? 0));
  final double b = _clamp(getVerticalSize(bottom ?? 0));
  return EdgeInsets.only(left: l, top: t, right: r, bottom: b);
}
