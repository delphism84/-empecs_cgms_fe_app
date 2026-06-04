import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Server sync / API timing logs (logcat: adb logcat | findstr ApiSync).
void apiSyncLog(String message) {
  final String line = '[ApiSync] $message';
  developer.log(line, name: 'ApiSync');
  debugPrint(line);
}

const int kApiSyncSlowMs = 2000;

void apiSyncLogHttp({
  required String method,
  required String path,
  required int elapsedMs,
  int? statusCode,
  Object? error,
  bool globalLoading = false,
  int? bodyBytes,
}) {
  final String status = statusCode != null ? 'status=$statusCode' : 'status=-';
  final String slow = elapsedMs >= kApiSyncSlowMs ? ' SLOW' : '';
  final String load = globalLoading ? ' globalLoading=Y' : '';
  final String size = bodyBytes != null ? ' body=${bodyBytes}B' : '';
  if (error != null) {
    apiSyncLog('$method $path FAIL ${elapsedMs}ms$load$size err=$error');
    return;
  }
  apiSyncLog('$method $path ok $status ${elapsedMs}ms$load$size$slow');
}
