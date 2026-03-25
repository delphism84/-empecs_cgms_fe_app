import 'package:flutter/foundation.dart';

class GlobalLoading {
  static final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  static void begin() {
    activeCount.value = activeCount.value + 1;
  }

  static void end() {
    final next = activeCount.value - 1;
    activeCount.value = next < 0 ? 0 : next;
  }
}


