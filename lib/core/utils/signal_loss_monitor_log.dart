import 'package:flutter/foundation.dart';

/// AR_01_06 Signal Loss: 로컬 전용 모니터링 로그(서버 없음). 알람 상세 화면 하단에 표시.
class SignalLossMonitorLog {
  SignalLossMonitorLog._();

  static const int maxLines = 200;
  static final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>(<String>[]);

  static void append(String line) {
    final DateTime t = DateTime.now();
    final String ts =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final List<String> next = [...lines.value, '[$ts] $line'];
    if (next.length > maxLines) {
      next.removeRange(0, next.length - maxLines);
    }
    lines.value = next;
  }

  static void clear() {
    lines.value = <String>[];
  }
}
