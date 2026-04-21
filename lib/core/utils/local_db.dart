import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:helpcare/core/utils/debug_toast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
      version: 1,
      onCreate: (Database d, int version) async {
        await d.execute('''
          CREATE TABLE IF NOT EXISTS glucose_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time_ms INTEGER NOT NULL,
            value REAL NOT NULL,
            trid INTEGER,
            eqsn TEXT,
            user_id TEXT,
            UNIQUE(trid) ON CONFLICT IGNORE
          );
        ''');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_time ON glucose_points(time_ms DESC);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_trid ON glucose_points(trid DESC);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_eqsn ON glucose_points(eqsn);');
        await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_user ON glucose_points(user_id);');
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
        await d.execute('''
          CREATE TABLE IF NOT EXISTS glucose_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time_ms INTEGER NOT NULL,
            value REAL NOT NULL,
            trid INTEGER,
            eqsn TEXT,
            user_id TEXT,
            UNIQUE(trid) ON CONFLICT IGNORE
          );
        ''');
        // attempt to add missing columns on existing installs (ignore errors)
        try { await d.execute('ALTER TABLE glucose_points ADD COLUMN eqsn TEXT'); } catch (_) {}
        try { await d.execute('ALTER TABLE glucose_points ADD COLUMN user_id TEXT'); } catch (_) {}
        // create indexes; if column missing on legacy DB, skip with toast
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_time ON glucose_points(time_ms DESC);'); } catch (e) { DebugToastBus().show('DB: idx_glucose_time skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_trid ON glucose_points(trid DESC);'); } catch (e) { DebugToastBus().show('DB: idx_glucose_trid skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_eqsn ON glucose_points(eqsn);'); } catch (e) { DebugToastBus().show('DB: idx_glucose_eqsn skipped'); }
        try { await d.execute('CREATE INDEX IF NOT EXISTS idx_glucose_user ON glucose_points(user_id);'); } catch (e) { DebugToastBus().show('DB: idx_glucose_user skipped'); }
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


