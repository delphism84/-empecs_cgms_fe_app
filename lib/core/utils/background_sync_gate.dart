import 'dart:async';

import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/warmup_state.dart';

/// Defers heavy background I/O only while SC_01_06 warmup UI is visible.
/// Separate from SN-based alarm suppression in [SensorWarmupService].
class BackgroundSyncGate {
  BackgroundSyncGate._();

  static final List<Future<void> Function()> _pending = <Future<void> Function()>[];
  static final Set<String> _pendingKeys = <String>{};
  static bool _flushScheduled = false;

  static bool get blocksHeavySync => WarmupState.isWarmupNow;

  static Future<void> yieldToUi({int milliseconds = 16}) async {
    if (milliseconds <= 0) {
      await Future<void>.delayed(Duration.zero);
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
  }

  static void notifyUiWarmupEnded() {
    runWhenUnblocked(() async {
      IngestQueueService().kickUpload();
    }, dedupeKey: 'ingestKick');
    if (_pending.isEmpty) return;
    if (_flushScheduled) return;
    _flushScheduled = true;
    unawaited(_flushPendingLoop());
  }

  static Future<void> _flushPendingLoop() async {
    try {
      while (_pending.isNotEmpty && !blocksHeavySync) {
        final Future<void> Function() fn = _pending.removeAt(0);
        await yieldToUi();
        try {
          await fn();
        } catch (_) {}
      }
    } finally {
      _flushScheduled = false;
    }
  }

  static void runWhenUnblocked(Future<void> Function() fn, {String? dedupeKey}) {
    if (!blocksHeavySync) {
      unawaited(_runDetached(fn));
      return;
    }
    if (dedupeKey != null) {
      final String key = dedupeKey;
      if (_pendingKeys.contains(key)) return;
      _pendingKeys.add(key);
      _pending.add(() async {
        _pendingKeys.remove(key);
        await fn();
      });
    } else {
      _pending.add(fn);
    }
  }

  static Future<void> _runDetached(Future<void> Function() fn) async {
    await yieldToUi(milliseconds: 0);
    try {
      await fn();
    } catch (_) {}
  }
}
