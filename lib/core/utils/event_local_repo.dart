import 'dart:async';
import 'package:helpcare/core/utils/local_db.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:sqflite/sqflite.dart';

class EventLocalRepo {
  EventLocalRepo._internal();
  static final EventLocalRepo _instance = EventLocalRepo._internal();
  factory EventLocalRepo() => _instance;

  Future<int> _nextEvid() async {
    final Map<String, dynamic> st = await SettingsStorage.load();
    int last = (st['lastEvid'] as int? ?? 0);
    last = (last + 1) & 0x7FFFFFFF;
    st['lastEvid'] = last;
    await SettingsStorage.save(st);
    return last;
  }

  Future<void> addOrUpdate({
    required DateTime time,
    required String type,
    String? memo,
    int? evid,
    String? sid,
    String? eqsn,
    String? userId,
  }) async {
    final Database db = await LocalDb().db;
    userId ??= await _inferUserId();
    final Map<String, Object?> row = {
      'time_ms': time.toUtc().millisecondsSinceEpoch,
      'type': type,
      if (memo != null) 'memo': memo,
    };
    // prefer sid uniqueness if provided
    if (sid != null && sid.isNotEmpty) {
      row['sid'] = sid;
      // fetch or assign evid if not given
      if (evid == null) {
        final List<Map<String, Object?>> prev = await db.query('events', columns: ['evid'], where: 'sid = ?', whereArgs: [sid], limit: 1);
        if (prev.isNotEmpty) {
          evid = (prev.first['evid'] as int?) ?? evid;
        }
      }
    }
    row['evid'] = evid ?? await _nextEvid();
    if (eqsn != null && eqsn.isNotEmpty) row['eqsn'] = eqsn;
    if (userId != null && userId.isNotEmpty) row['user_id'] = userId;

    await db.insert('events', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> range({required DateTime from, required DateTime to, int limit = 1000, String? eqsn, String? userId}) async {
    final Database db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Map<String, Object?>> rows = await db.query(
      'events',
      columns: ['time_ms', 'type', 'memo', 'evid', 'sid'],
      where: (eqsn != null && eqsn.isNotEmpty)
          ? 'time_ms BETWEEN ? AND ? AND eqsn = ? AND (user_id = ? OR user_id IS NULL)'
          : 'time_ms BETWEEN ? AND ? AND (user_id = ? OR user_id IS NULL)',
      whereArgs: (eqsn != null && eqsn.isNotEmpty)
          ? [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, eqsn, userId ?? '']
          : [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, userId ?? ''],
      orderBy: 'time_ms ASC',
      limit: limit,
    );
    return rows.cast<Map<String, dynamic>>();
  }

  Future<int> maxEvid({String? eqsn, String? userId}) async {
    final Database db = await LocalDb().db;
    userId ??= await _inferUserId();
    final List<Map<String, Object?>> res = (eqsn != null && eqsn.isNotEmpty)
        ? await db.rawQuery('SELECT MAX(evid) AS max_evid FROM events WHERE eqsn = ? AND (user_id = ? OR user_id IS NULL)', [eqsn, userId])
        : await db.rawQuery('SELECT MAX(evid) AS max_evid FROM events WHERE (user_id = ? OR user_id IS NULL)', [userId]);
    final Object? v = res.isNotEmpty ? res.first['max_evid'] : null;
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> deleteBySid(String sid) async {
    final Database db = await LocalDb().db;
    await db.delete('events', where: 'sid = ?', whereArgs: [sid]);
  }

  Future<void> deleteByEvid(int evid) async {
    final Database db = await LocalDb().db;
    await db.delete('events', where: 'evid = ?', whereArgs: [evid]);
  }

  Future<int> deleteByAny(String idOrEvid) async {
    final Database db = await LocalDb().db;
    int n = await db.delete('events', where: 'sid = ?', whereArgs: [idOrEvid]);
    if (n == 0) {
      final int? evid = int.tryParse(idOrEvid);
      if (evid != null) {
        n = await db.delete('events', where: 'evid = ?', whereArgs: [evid]);
      }
    }
    return n;
  }

  Future<void> truncateBefore(DateTime cutoff) async {
    final Database db = await LocalDb().db;
    await db.transaction((txn) async {
      await txn.delete('events', where: 'time_ms < ?', whereArgs: [cutoff.millisecondsSinceEpoch]);
      try {
        await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name='events'");
      } catch (_) {}
    });
  }

  Future<void> clear() async {
    final Database db = await LocalDb().db;
    await db.transaction((txn) async {
      await txn.delete('events');
      try {
        await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name='events'");
      } catch (_) {}
    });
  }

  Future<void> clearForEqsn(String eqsn, {String? userId}) async {
    final Database db = await LocalDb().db;
    userId ??= await _inferUserId();
    await db.transaction((txn) async {
      await txn.delete('events', where: '(eqsn = ? OR (eqsn IS NULL AND ? = \'\')) AND (user_id = ? OR user_id IS NULL)', whereArgs: [eqsn, eqsn, userId ?? '']);
    });
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
}


