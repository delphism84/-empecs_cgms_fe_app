import 'package:flutter/material.dart';

class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, this.size = 24, required this.gradient});

  final IconData icon;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(Rect.fromLTWH(0, 0, size, size)),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

class AppGradients {
  static const Gradient primary = LinearGradient(colors: [Color(0xFF49C5B1), Color(0xFF2AAE9B)]);
  static const Gradient warning = LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFF4511E)]);
  static const Gradient info = LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)]);
}

class AppIconGradients {
  static Gradient resolve(IconData icon) {
    // warning / alerts
    if (_any(icon, const [
      Icons.warning,
      Icons.warning_amber,
      Icons.error,
      Icons.notifications,
      Icons.notifications_none,
      Icons.notification_important,
    ])) {
      return AppGradients.warning;
    }

    // network / device / info
    if (_any(icon, const [
      Icons.sensors,
      Icons.bluetooth,
      Icons.bluetooth_connected,
      Icons.bluetooth_searching,
      Icons.wifi,
      Icons.info,
      Icons.timeline,
    ])) {
      return AppGradients.info;
    }

    // defaults to primary (health/general)
    return AppGradients.primary;
  }

  static bool _any(IconData icon, List<IconData> list) => list.contains(icon);
}


