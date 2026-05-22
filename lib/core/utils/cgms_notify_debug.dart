import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// CGMS notify ? UI ?? ??? (logcat: `adb logcat -s CgmsNotifyDbg flutter`)
void cgmsNotifyLog(String message) {
  final String line = '[CgmsNotifyDbg] $message';
  developer.log(line, name: 'CgmsNotifyDbg');
  debugPrint(line);
}
