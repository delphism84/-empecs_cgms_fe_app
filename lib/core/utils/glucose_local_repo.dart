import 'dart:async';
import 'package:helpcare/core/utils/local_db.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:sqflite/sqflite.dart';

class GlucoseLocalRepo {
  GlucoseLocalRepo._internal();
  static final GlucoseLocalRepo _instance = GlucoseLocalRepo._internal();
  factory GlucoseLocalRepo() => _instance;

  final StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _stream.stream;

  Future<void> addPoint({required DateTime time, required double value, int? trid, String? eqsn, String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    await db.insert('glucose_points', {
      'time_ms': time.toUtc().millisecondsSinceEpoch,
      'value': value,
      'trid': trid,
      if (eqsn != null) 'eqsn': eqsn,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    _stream.add({'op': 'add', 'time': time, 'value': value, 'trid': trid, if (eqsn != null) 'eqsn': eqsn, if (userId != null) 'userId': userId});
  }

  Future<void> addPointsBatch({
    required List<DateTime> times,
    required List<double> values,
    required List<int?> trids,
    String? eqsn,
    String? userId,
  }) async {
    if (times.isEmpty) return;
    final int n = times.length;
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    await db.transaction((txn) async {
      final Batch b = txn.batch();
      for (int i = 0; i < n; i++) {
        b.insert('glucose_points', {
          'time_ms': times[i].toUtc().millisecondsSinceEpoch,
          'value': values[i],
          'trid': trids[i],
          if (eqsn != null) 'eqsn': eqsn,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await b.commit(noResult: true);
    });
    _stream.add({'op': 'add-batch', 'count': times.length, if (eqsn != null) 'eqsn': eqsn, if (userId != null) 'userId': userId});
  }

  Future<List<Map<String, dynamic>>> range({required DateTime from, required DateTime to, int limit = 2000, String? eqsn, String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Map<String, dynamic>> rows = await db.query(
      'glucose_points',
      columns: ['time_ms', 'value', 'trid'],
      where: (eqsn != null && eqsn.isNotEmpty)
          ? 'time_ms BETWEEN ? AND ? AND eqsn = ? AND (user_id = ? OR user_id IS NULL)'
          : 'time_ms BETWEEN ? AND ? AND (user_id = ? OR user_id IS NULL)',
      whereArgs: (eqsn != null && eqsn.isNotEmpty)
          ? [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, eqsn, userId ?? '']
          : [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, userId ?? ''],
      orderBy: 'time_ms ASC',
      limit: limit,
    );
    return rows;
  }

  Future<int> maxTrid({String? eqsn, String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Map<String, Object?>> res = (eqsn != null && eqsn.isNotEmpty)
        ? await db.rawQuery('SELECT MAX(trid) AS max_trid FROM glucose_points WHERE eqsn = ? AND (user_id = ? OR user_id IS NULL)', [eqsn, userId])
        : await db.rawQuery('SELECT MAX(trid) AS max_trid FROM glucose_points WHERE (user_id = ? OR user_id IS NULL)', [userId]);
    final Object? v = res.isNotEmpty ? res.first['max_trid'] : null;
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> clearForEqsn(String eqsn, {String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    await db.transaction((txn) async {
      await txn.delete(
        'glucose_points',
        where: '(eqsn = ? OR (eqsn IS NULL AND ? = \'\')) AND (user_id = ? OR user_id IS NULL)',
        whereArgs: [eqsn, eqsn, userId ?? ''],
      );
    });
    _stream.add({'op': 'clear', 'eqsn': eqsn, if (userId != null) 'userId': userId});
  }

  Future<String?> _inferUserId() async {
    try {
      final st = await SettingsStorage.load();
      final String uid = (st['lastUserId'] as String? ?? '').trim();
      if (uid.isNotEmpty) return uid;
      return 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  Future<void> clear() async {
    final db = await LocalDb().db;
    await db.transaction((txn) async {
      await txn.delete('glucose_points');
      // reset autoincrement counter (optional)
      try {
        await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name='glucose_points'");
      } catch (_) {}
    });
    _stream.add({'op': 'clear'});
  }

  Future<int> count() async {
    final db = await LocalDb().db;
    final List<Map<String, Object?>> res = await db.rawQuery('SELECT COUNT(*) AS c FROM glucose_points');
    final Object? v = res.isNotEmpty ? res.first['c'] : null;
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<List<String>> listDaysDesc() async {
    final db = await LocalDb().db;
    // SQLite localtime; day string like 2025-10-28
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y-%m-%d', datetime(time_ms/1000, 'unixepoch', 'localtime')) AS d FROM glucose_points ORDER BY d DESC"
    );
    return rows.map((r) => (r['d'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
  }

  /// 날짜별 로컬 포인트 요약(내림차순): day, count, min/max time_ms
  Future<List<Map<String, dynamic>>> listDayCountsDesc() async {
    final db = await LocalDb().db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT "
      "  strftime('%Y-%m-%d', datetime(time_ms/1000, 'unixepoch', 'localtime')) AS d, "
      "  COUNT(*) AS c, "
      "  MIN(time_ms) AS min_ms, "
      "  MAX(time_ms) AS max_ms "
      "FROM glucose_points "
      "GROUP BY d "
      "ORDER BY d DESC"
    );
    return rows.map((r) {
      final String day = (r['d'] as String?) ?? '';
      final int count = (r['c'] is int) ? (r['c'] as int) : ((r['c'] as num?)?.toInt() ?? 0);
      final int minMs = (r['min_ms'] is int) ? (r['min_ms'] as int) : ((r['min_ms'] as num?)?.toInt() ?? 0);
      final int maxMs = (r['max_ms'] is int) ? (r['max_ms'] as int) : ((r['max_ms'] as num?)?.toInt() ?? 0);
      return {'day': day, 'count': count, 'minMs': minMs, 'maxMs': maxMs};
    }).where((m) => (m['day'] as String).isNotEmpty).toList();
  }

  /// 이전 데이터(센서별 기간) 목록: eqsn 별 min/max/count
  Future<List<Map<String, dynamic>>> listEqsnRanges({String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT eqsn AS eqsn, MIN(time_ms) AS min_ms, MAX(time_ms) AS max_ms, COUNT(*) AS c "
      "FROM glucose_points "
      "WHERE eqsn IS NOT NULL AND eqsn != '' AND (user_id = ? OR user_id IS NULL) "
      "GROUP BY eqsn "
      "ORDER BY max_ms DESC",
      [userId ?? ''],
    );
    return rows.map((r) {
      final String eqsn = (r['eqsn'] as String?) ?? '';
      final int fromMs = (r['min_ms'] as int?) ?? 0;
      final int toMs = (r['max_ms'] as int?) ?? 0;
      final int count = (r['c'] as int?) ?? 0;
      return {'eqsn': eqsn, 'fromMs': fromMs, 'toMs': toMs, 'count': count};
    }).where((m) => (m['eqsn'] as String).isNotEmpty).toList();
  }
}


