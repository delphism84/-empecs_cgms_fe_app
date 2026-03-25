import 'package:flutter/material.dart';

enum ToastLevel { serverError, warning, success }

class CommonToast {
  static OverlayEntry? _entry;
  static DateTime? _lastShown;

  static void show(BuildContext context, String message, ToastLevel level, {Duration duration = const Duration(seconds: 3)}) {
    _remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(builder: (_) => _ToastWidget(message: message, level: level));
    overlay.insert(_entry!);
    _lastShown = DateTime.now();
    Future.delayed(duration, () {
      // prevent race: only remove if not replaced recently
      if (_lastShown != null && DateTime.now().difference(_lastShown!) >= duration) {
        _remove();
      }
    });
  }

  static void showServerError(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) =>
      show(context, message, ToastLevel.serverError, duration: duration);
  static void showWarning(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, ToastLevel.warning, duration: duration);
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) =>
      show(context, message, ToastLevel.success, duration: duration);

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }
}

class _ToastWidget extends StatelessWidget {
  const _ToastWidget({required this.message, required this.level});
  final String message;
  final ToastLevel level;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    switch (level) {
      case ToastLevel.serverError:
        bg = const Color(0xFFFFEBEE); // light red
        fg = const Color(0xFFD32F2F); // red 700
        icon = Icons.close_rounded;
        break;
      case ToastLevel.warning:
        bg = const Color(0xFFFFF8E1); // light amber
        fg = const Color(0xFFF9A825); // amber 800
        icon = Icons.warning_amber_rounded;
        break;
      case ToastLevel.success:
      default:
        bg = const Color(0xFFE8F5E9); // light green
        fg = const Color(0xFF2E7D32); // green 800
        icon = Icons.check_circle_rounded;
        break;
    }

    // top-center toast
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: fg.withOpacity(0.8), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message,
                        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


