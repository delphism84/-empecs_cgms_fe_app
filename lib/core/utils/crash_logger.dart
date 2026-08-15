import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 앱 전역 크래시/예외를 파일로 남겨 "튕김" 원인 스택을 사후 분석할 수 있게 한다.
///
/// - `FlutterError.onError`        : 위젯 빌드/렌더 등 프레임워크 동기 예외
/// - `PlatformDispatcher.onError`  : 잡히지 않은 비동기(Dart) 예외
/// - `runZonedGuarded`(main.dart)  : 그 외 zone 레벨 예외
///
/// 주의: 네이티브(BLE/sqlite SIGSEGV 등) 크래시는 Dart 핸들러로 잡히지 않으므로
/// 그 경우는 여전히 `adb logcat` 으로 확인해야 한다.
class CrashLogger {
  CrashLogger._();

  static File? _file;
  static bool _initing = false;

  /// 로그 파일 경로(있으면 반환). UI에서 "로그 보기/공유"에 쓸 수 있다.
  static File? get fileOrNull => _file;

  static Future<void> _ensureFile() async {
    if (_file != null || _initing) return;
    _initing = true;
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory logDir = Directory(p.join(dir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _file = File(p.join(logDir.path, 'crash.log'));
    } catch (_) {
      // path_provider 미지원(web 등) → 파일 로깅은 생략, debugPrint 만 유지
    } finally {
      _initing = false;
    }
  }

  /// 단일 예외를 타임스탬프와 함께 append. 실패해도 절대 throw 하지 않는다.
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String source = 'zone',
  }) async {
    final String ts = DateTime.now().toUtc().toIso8601String();
    debugPrint('[CrashLogger][$source] $error');
    try {
      await _ensureFile();
      final File? f = _file;
      if (f != null) {
        final String entry = '[$ts][$source] $error\n${stack ?? ''}\n\n';
        await f.writeAsString(entry, mode: FileMode.append, flush: true);
      }
    } catch (_) {
      // 로깅 자체 실패는 무시(앱 동작에 영향 없어야 함)
    }
  }

  /// FlutterError / PlatformDispatcher 전역 훅 설치. main() 초기에 1회 호출.
  static void install() {
    final FlutterExceptionHandler? prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // 디버그 콘솔에도 그대로 표시
      (prev ?? FlutterError.presentError)(details);
      unawaited(record(details.exception, details.stack, source: 'flutter'));
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(record(error, stack, source: 'platform'));
      return true; // 처리됨으로 표시(프로세스 종료 방지)
    };
  }
}
