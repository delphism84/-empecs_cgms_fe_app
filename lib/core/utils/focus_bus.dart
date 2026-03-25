import 'package:flutter/foundation.dart';

class GlucoseFocus {
  static final ValueNotifier<DateTime?> focusTime = ValueNotifier<DateTime?>(null);
  static void focus(DateTime time) {
    focusTime.value = time;
  }
}

class HomeTab {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);
  static void go(int i) {
    index.value = i;
  }
}

class AppSettingsBus {
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static void notify() { changed.value++; }
}


