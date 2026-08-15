import 'dart:async';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/local_db.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:sqflite/sqflite.dart';

/// 혈당 행의 출처. 워터마크(`lastTrid`) 계산은 기기 실측(`ble`)만 신뢰한다.
/// 서버 캐시(`srv`)를 섞으면 과거 센서의 trid 가 현재 센서 워터마크를 밀어 올려
/// 이후 신규 판독이 전부 "이미 올린 것"으로 취급돼 업로드가 영구 차단된다.
class GlucoseSrc {
  GlucoseSrc._();
  static const String ble = 'ble';
  static const String server = 'srv';
  static const String seed = 'seed';
}

class GlucoseLocalRepo {
  GlucoseLocalRepo._internal();
  static final GlucoseLocalRepo _instance = GlucoseLocalRepo._internal();
  factory GlucoseLocalRepo() => _instance;

  final StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _stream.stream;

  /// 저장이 UNIQUE 충돌로 무시된 누적 횟수(프로세스 수명). QA dump 로 노출한다.
  int droppedInserts = 0;
  /// 마지막으로 폐기된 행의 요약(진단용).
  String lastDropInfo = '';

  /// 저장 결과. rowId==0 이면 UNIQUE 충돌로 **무시**된 것 — 예전에는 이 사실이
  /// 아무 데도 남지 않아 "그냥 갱신이 안 됨"으로만 보였다.
  Future<bool> addPoint({
    required DateTime time,
    required double value,
    int? trid,
    String? eqsn,
    String? userId,
    String src = GlucoseSrc.ble,
  }) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final int rowId = await db.insert('glucose_points', {
      'time_ms': time.toUtc().millisecondsSinceEpoch,
      'value': value,
      'trid': trid,
      'src': src,
      if (eqsn != null) 'eqsn': eqsn,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final bool stored = rowId > 0;
    if (!stored) {
      droppedInserts++;
      lastDropInfo = 'eqsn=$eqsn t=${time.toUtc().toIso8601String()} v=$value trid=$trid src=$src';
      // 무음 폐기 금지: 로그와 누적 카운터로 남긴다(QA `dump` 로 조회).
      // 화면 토스트는 쓰지 않는다 — 중복이 연속으로 들어오면 사용자 화면을 도배한다.
      unawaited(BleLogService().add('DB', 'glucose insert IGNORED ($lastDropInfo) total=$droppedInserts'));
    }
    _stream.add({'op': 'add', 'time': time, 'value': value, 'trid': trid, 'stored': stored, if (eqsn != null) 'eqsn': eqsn, if (userId != null) 'userId': userId});
    return stored;
  }

  /// 배치 저장. 반환값은 **실제로 저장된 행 수**(무시된 행은 제외).
  Future<int> addPointsBatch({
    required List<DateTime> times,
    required List<double> values,
    required List<int?> trids,
    String? eqsn,
    String? userId,
    String src = GlucoseSrc.ble,
  }) async {
    if (times.isEmpty) return 0;
    final int n = times.length;
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Object?> results = await db.transaction((txn) async {
      final Batch b = txn.batch();
      for (int i = 0; i < n; i++) {
        b.insert('glucose_points', {
          'time_ms': times[i].toUtc().millisecondsSinceEpoch,
          'value': values[i],
          'trid': trids[i],
          'src': src,
          if (eqsn != null) 'eqsn': eqsn,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return b.commit();
    });
    int stored = 0;
    for (final Object? r in results) {
      if (r is int && r > 0) stored++;
    }
    final int dropped = n - stored;
    if (dropped > 0) {
      droppedInserts += dropped;
      lastDropInfo = 'batch eqsn=$eqsn dropped=$dropped/$n src=$src';
      unawaited(BleLogService().add('DB', 'glucose batch IGNORED $dropped/$n (eqsn=$eqsn src=$src) total=$droppedInserts'));
    }
    _stream.add({'op': 'add-batch', 'count': times.length, 'stored': stored, if (eqsn != null) 'eqsn': eqsn, if (userId != null) 'userId': userId});
    return stored;
  }

  /// 로그인 사용자(`lastUserId` 있음)는 익명(NULL) 행을 제외해 이전 게스트/다른 계정 데이터가 섞이지 않게 한다.
  bool _strictUserScope(String uid) => uid.isNotEmpty && uid != 'guest';

  Future<List<Map<String, dynamic>>> range({required DateTime from, required DateTime to, int limit = 2000, String? eqsn, String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final String uid = userId ?? '';
    final bool strict = _strictUserScope(uid);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<Map<String, dynamic>> rows = await db.query(
      'glucose_points',
      columns: ['time_ms', 'value', 'trid'],
      where: (eqsn != null && eqsn.isNotEmpty)
          ? 'time_ms BETWEEN ? AND ? AND eqsn = ? AND $userClause'
          : 'time_ms BETWEEN ? AND ? AND $userClause',
      whereArgs: (eqsn != null && eqsn.isNotEmpty)
          ? [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, eqsn, uid]
          : [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, uid],
      orderBy: 'time_ms ASC',
      limit: limit,
    );
    return rows;
  }

  /// 최근 혈당 1건 (잠금 배너 등)
  Future<Map<String, dynamic>?> latestPoint({String? eqsn}) async {
    final db = await LocalDb().db;
    final String userId = (await _inferUserId()) ?? '';
    final bool strict = _strictUserScope(userId);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<Map<String, dynamic>> rows = await db.query(
      'glucose_points',
      columns: ['time_ms', 'value'],
      where: (eqsn != null && eqsn.isNotEmpty)
          ? 'eqsn = ? AND $userClause'
          : userClause,
      whereArgs: (eqsn != null && eqsn.isNotEmpty) ? [eqsn, userId] : [userId],
      orderBy: 'time_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 최근 N건 (시간 내림차순, [0]=최신)
  Future<List<Map<String, dynamic>>> latestN({int n = 2, String? eqsn}) async {
    if (n <= 0) return const [];
    final db = await LocalDb().db;
    final String userId = (await _inferUserId()) ?? '';
    final bool strict = _strictUserScope(userId);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<Map<String, dynamic>> rows = await db.query(
      'glucose_points',
      columns: ['time_ms', 'value'],
      where: (eqsn != null && eqsn.isNotEmpty)
          ? 'eqsn = ? AND $userClause'
          : userClause,
      whereArgs: (eqsn != null && eqsn.isNotEmpty) ? [eqsn, userId] : [userId],
      orderBy: 'time_ms DESC',
      limit: n,
    );
    return rows;
  }

  /// AR_01_08 잠금화면: 최신값 vs 직전값 (↑ / ↓ / →). 한 건뿐이면 →.
  /// [eqsn]이 null/빈 문자열이면 동일 사용자의 최근 포인트 전체에서 비교(로컬 `LOCAL` 태그 혼재 대비).
  Future<String> lockScreenTrendArrow({String? eqsn}) async {
    final String? q = (eqsn != null && eqsn.trim().isNotEmpty) ? eqsn.trim() : null;
    final List<Map<String, dynamic>> rows = await latestN(n: 2, eqsn: q);
    if (rows.length < 2) return '→';
    final double vNew = (rows[0]['value'] as num).toDouble();
    final double vPrev = (rows[1]['value'] as num).toDouble();
    if (vNew > vPrev) return '↑';
    if (vNew < vPrev) return '↓';
    return '→';
  }

  /// [src]를 주면 해당 출처의 행만 본다. 워터마크 계산은 반드시 `GlucoseSrc.ble`로
  /// 좁혀야 한다 — 서버에서 내려온 과거 센서의 trid 가 섞이면 워터마크가 부풀어
  /// 이후 신규 판독이 전부 "이미 전송됨"으로 취급된다.
  Future<int> maxTrid({String? eqsn, String? userId, String? src}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final String uid = userId ?? '';
    final bool strict = _strictUserScope(uid);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<String> where = <String>[userClause];
    final List<Object?> args = <Object?>[uid];
    if (eqsn != null && eqsn.isNotEmpty) {
      where.add('eqsn = ?');
      args.add(eqsn);
    }
    if (src != null && src.isNotEmpty) {
      // 레거시 행(src NULL)은 기기 실측으로 간주 — v3 이전에는 서버 캐시가 구분되지 않았다.
      where.add(src == GlucoseSrc.ble ? '(src = ? OR src IS NULL)' : 'src = ?');
      args.add(src);
    }
    final List<Map<String, Object?>> res = await db.rawQuery(
      'SELECT MAX(trid) AS max_trid FROM glucose_points WHERE ${where.join(' AND ')}',
      args,
    );
    final Object? v = res.isNotEmpty ? res.first['max_trid'] : null;
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// 현재 사용자/센서 기준 로컬 데이터 기간 요약.
  /// - fromMs/toMs는 UTC epoch milliseconds.
  Future<Map<String, dynamic>> rangeBounds({String? eqsn, String? userId}) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final String uid = userId ?? '';
    final bool strict = _strictUserScope(uid);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<Map<String, Object?>> res = (eqsn != null && eqsn.isNotEmpty)
        ? await db.rawQuery(
            'SELECT COUNT(*) AS c, MIN(time_ms) AS min_ms, MAX(time_ms) AS max_ms FROM glucose_points WHERE eqsn = ? AND $userClause',
            [eqsn, uid],
          )
        : await db.rawQuery(
            'SELECT COUNT(*) AS c, MIN(time_ms) AS min_ms, MAX(time_ms) AS max_ms FROM glucose_points WHERE $userClause',
            [uid],
          );
    final row = res.isNotEmpty ? res.first : const <String, Object?>{};
    final int count = (row['c'] as num?)?.toInt() ?? 0;
    final int? minMs = (row['min_ms'] as num?)?.toInt();
    final int? maxMs = (row['max_ms'] as num?)?.toInt();
    return {
      'count': count,
      'fromMs': minMs,
      'toMs': maxMs,
    };
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

  /// [afterTrid] 초과 trid 행 — 서버 미전송 백로그 복구용 (시간 오름차순).
  /// 서버에서 내려받아 캐시한 행(`src='srv'`)은 되돌려 보낼 필요가 없으므로 제외한다.
  Future<List<Map<String, dynamic>>> rowsAfterTrid({
    required int afterTrid,
    int limit = 500,
    String? eqsn,
    String? userId,
  }) async {
    final db = await LocalDb().db;
    userId ??= await _inferUserId();
    final String uid = userId ?? '';
    final bool strict = _strictUserScope(uid);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<String> where = <String>[
      'trid IS NOT NULL',
      'trid > ?',
      "(src IS NULL OR src = '${GlucoseSrc.ble}')",
      userClause,
    ];
    final List<Object?> args = <Object?>[afterTrid, uid];
    if (eqsn != null && eqsn.isNotEmpty) {
      where.add('eqsn = ?');
      args.add(eqsn);
    }
    final List<Map<String, dynamic>> rows = await db.query(
      'glucose_points',
      columns: ['time_ms', 'value', 'trid'],
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'trid ASC',
      limit: limit,
    );
    return rows;
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
    final String uid = userId ?? '';
    final bool strict = _strictUserScope(uid);
    final String userClause = strict ? 'user_id = ?' : '(user_id = ? OR user_id IS NULL)';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT eqsn AS eqsn, MIN(time_ms) AS min_ms, MAX(time_ms) AS max_ms, COUNT(*) AS c "
      "FROM glucose_points "
      "WHERE eqsn IS NOT NULL AND eqsn != '' AND $userClause "
      "GROUP BY eqsn "
      "ORDER BY max_ms DESC",
      [uid],
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


