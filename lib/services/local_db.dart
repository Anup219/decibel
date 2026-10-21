import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get instance async {
    return _db ??= await openDatabase(
      join(await getDatabasesPath(), 'decibel.db'),
      version: 2,
      onCreate: (db, v) async {
        // Shared catalog of normalized tracks
        await db.execute('''
          CREATE TABLE tracks (
            track_key TEXT PRIMARY KEY,
            artist_primary TEXT NOT NULL,
            artists_all TEXT,
            language TEXT,
            genre TEXT,
            mood TEXT,
            era TEXT,
            tag_confidence REAL DEFAULT 1.0,
            provider TEXT,
            provider_track_id TEXT,
            schema_version INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Play events table (status = 'open' during playback, 'closed' or 'interrupted' when ready to sync)
        await db.execute('''
          CREATE TABLE play_events (
            id TEXT PRIMARY KEY,
            track_key TEXT NOT NULL,
            seed_track_key TEXT,
            origin TEXT NOT NULL,
            listened_ms INTEGER NOT NULL DEFAULT 0,
            duration_ms INTEGER NOT NULL,
            liked INTEGER DEFAULT 0,
            added_to_playlist INTEGER DEFAULT 0,
            downloaded INTEGER DEFAULT 0,
            buffer_stall INTEGER DEFAULT 0,
            score REAL,
            score_parts TEXT,
            temperature REAL,
            model_version TEXT,
            hour_bucket TEXT,
            tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'open',
            ended_reason TEXT,
            occurred_at TEXT NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('CREATE INDEX idx_unsynced_status ON play_events(synced, status)');
        await db.execute('CREATE INDEX idx_occurred_at ON play_events(occurred_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE play_events ADD COLUMN tz_offset_minutes INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE play_events ADD COLUMN status TEXT NOT NULL DEFAULT 'closed'");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE play_events ADD COLUMN ended_reason TEXT");
          } catch (_) {}
          try {
            await db.execute("CREATE INDEX IF NOT EXISTS idx_unsynced_status ON play_events(synced, status)");
          } catch (_) {}
        }
      },
    );
  }
}
