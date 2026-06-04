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

/// AR high/low 임계값 변경 시 차트 참조선만 갱신 (AppSettingsBus와 분리).
class ChartThresholdBus {
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static void notify() { changed.value++; }
}

/// 언어 변경 시 Home·설정 등 UI만 선택적으로 재빌드 (AppSettingsBus와 분리).
class LocaleBus {
  static final ValueNotifier<String> language = ValueNotifier<String>('en');

  static void notify(String lang) {
    language.value = lang == 'ko' ? 'ko' : 'en';
  }
}


