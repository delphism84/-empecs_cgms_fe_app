import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:helpcare/core/utils/debug_toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// v3 마이그레이션에서 (eqsn,time_ms) 중복으로 합쳐진 행 수. 0이 아니면 과거 백필이
/// 전부 같은 시각으로 기록돼 있었다는 증거 → QA dump 로 노출한다.
int lastMigrationDroppedRows = 0;

String _glucoseCreateSql(String table) => '''
  CREATE TABLE IF NOT EXISTS $table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    time_ms INTEGER NOT NULL,
    value REAL NOT NULL,
    trid INTEGER,
    eqsn TEXT,
    user_id TEXT,
    src TEXT,
    UNIQUE(eqsn, time_ms) ON CONFLICT IGNORE
  );
''';

Future<void> _createGlucoseIndexes(Database d) async {
  await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_time ON glucose_points(time_ms DESC);');
  await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_trid ON glucose_points(trid DESC);');
  await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_eqsn ON glucose_points(eqsn);');
  await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_user ON glucose_points(user_id);');
  await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_src ON glucose_points(src);');
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  final Object? v = rows.first.values.first;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

class LocalDb {
  LocalDb._internal();
  static final LocalDb _instance = LocalDb._internal();
  factory LocalDb() => _instance;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String path;
    if (kIsWeb) {
      path = 'cgms_local.db';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, 'cgms_local.db');
    }
    return openDatabase(
      path,
      version: 3,
      onUpgrade: (Database d, int oldVersion, int newVersion) async {
        // v2: glucose_points UNIQUE(trid) → UNIQUE(trid, eqsn).
        // 전역 trid 유일성은 16비트 wrap·센서 교체(시드) 시 신규 혈당을 ON CONFLICT IGNORE로 조용히 버렸음.
        //
        // v3: UNIQUE(trid, eqsn) → UNIQUE(eqsn, time_ms) + src 컬럼.
        // trid 는 기기 값이 아니라 앱이 만든 전역 16비트 카운터라 유일키로 쓸 수 없다.
        //  · lastTrid 가 0으로 초기화되면 신규 판독이 trid=1,2,3… 을 다시 받아 기존 행과 전부 충돌 → 영구 폐기
        //  · 서버 동기화가 과거 센서 trid 를 현재 eqsn 으로 stamped 저장하면 (trid,eqsn) 보호막도 무력화
        // 시계열의 자연 유일키인 (센서, 측정시각)으로 바꿔 두 경로 모두 차단한다.
        // src: 'ble'(기기 실측) / 'srv'(서버 캐시) / 'seed'(QA) — 워터마크 계산에서 srv/seed 를 제외하기 위함.
        if (oldVersion < 3) {
          try {
            try { await d.execute('ALTER TABLE glucose_points ADD COLUMN eqsn TEXT'); } catch (_) {}
            try { await d.execute('ALTER TABLE glucose_points ADD COLUMN user_id TEXT'); } catch (_) {}
            try { await d.execute('ALTER TABLE glucose_points ADD COLUMN src TEXT'); } catch (_) {}
            await d.execute('DROP TABLE IF EXISTS glucose_points_v3');
            await d.execute(_glucoseCreateSql('glucose_points_v3'));
            // 백필이 전부 DateTime.now() 로 기록돼 (eqsn,time_ms) 가 겹치는 행이 있을 수 있다.
            // 같은 시각 중복은 차트상 구분 불가능한 행이므로 첫 행만 남긴다(개수는 기록).
            await d.execute('''
              INSERT OR IGNORE INTO glucose_points_v3 (id, time_ms, value, trid, eqsn, user_id, src)
              SELECT id, time_ms, value, trid, eqsn, user_id, COALESCE(src, 'ble') FROM glucose_points;
            ''');
            final int before = _firstInt(await d.rawQuery('SELECT COUNT(*) AS c FROM glucose_points'));
            final int after = _firstInt(await d.rawQuery('SELECT COUNT(*) AS c FROM glucose_points_v3'));
            await d.execute('DROP TABLE glucose_points');
            await d.execute('ALTER TABLE glucose_points_v3 RENAME TO glucose_points');
            await _createGlucoseIndexes(d);
            lastMigrationDroppedRows = before - after;
            if (lastMigrationDroppedRows > 0) {
              DebugToastBus().show('DB: v3 dedup dropped $lastMigrationDroppedRows rows');
            }
          } catch (e) {
            DebugToastBus().show('DB: glucose v3 migration skipped');
          }
        }
      },
      onCreate: (Database d, int version) async {
        await d.execute(_glucoseCreateSql('glucose_points'));
        await _createGlucoseIndexes(d);
        // events table with evid sequence and optional server id (sid)
        await d.execute('''
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time_ms INTEGER NOT NULL,
            type TEXT NOT NULL,
            memo TEXT,
            evid INTEGER,
            sid TEXT,
            eqsn TEXT,
            user_id TEXT,
            UNIQUE(evid) ON CONFLICT IGNORE,
            UNIQUE(sid) ON CONFLICT IGNORE
          );
        ''');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_events_time ON events(time_ms DESC);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_events_evid ON events(evid DESC);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_events_eqsn ON events(eqsn);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_id);');
      },
      onOpen: (Database d) async {
        // ensure schema exists even if DB pre-existed without the table (older app versions)
        await d.execute(_glucoseCreateSql('glucose_points'));
        // attempt to add missing columns on existing installs (ignore errors)
        try { await d.execute('ALTER TABLE glucose_points ADD COLUMN eqsn TEXT'); } catch (_) {}
        try { await d.execute('ALTER TABLE glucose_points ADD COLUMN user_id TEXT'); } catch (_) {}
        try { await d.execute('ALTER TABLE glucose_points ADD COLUMN src TEXT'); } catch (_) {}
        // create indexes; if column missing on legacy DB, skip with toast
        try { await _createGlucoseIndexes(d); } catch (e) { DebugToastBus().show('DB: glucose index skipped'); }
        await d.execute('''
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time_ms INTEGER NOT NULL,
            type TEXT NOT NULL,
            memo TEXT,
            evid INTEGER,
            sid TEXT,
            eqsn TEXT,
            user_id TEXT,
            UNIQUE(evid) ON CONFLICT IGNORE,
            UNIQUE(sid) ON CONFLICT IGNORE
          );
        ''');
        try { await d.execute('ALTER TABLE events ADD COLUMN eqsn TEXT'); } catch (_) {}
        try { await d.execute('ALTER TABLE events ADD COLUMN user_id TEXT'); } catch (_) {}
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_events_time ON events(time_ms DESC);'); } catch (e) { DebugToastBus().show('DB: idx_events_time skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_events_evid ON events(evid DESC);'); } catch (e) { DebugToastBus().show('DB: idx_events_evid skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_events_eqsn ON events(eqsn);'); } catch (e) { DebugToastBus().show('DB: idx_events_eqsn skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_id);'); } catch (e) { DebugToastBus().show('DB: idx_events_user skipped'); }
      },
    );
  }

  Future<void> wipe() async {
    try {
      if (_db != null) {
        try { await _db!.close(); } catch (_) {}
        _db = null;
      }
      final String path;
      if (kIsWeb) {
        path = 'cgms_local.db';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        path = p.join(dir.path, 'cgms_local.db');
      }
      await deleteDatabase(path);
    } catch (_) {}
  }
}


