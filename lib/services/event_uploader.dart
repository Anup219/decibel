import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'local_db.dart';

class EventUploader {
  static final EventUploader _instance = EventUploader._internal();
  factory EventUploader() => _instance;
  EventUploader._internal();

  bool _running = false;
  DateTime? _startedAt;
  DateTime? _lastFlushTime;
  DateTime? get lastFlushTime => _lastFlushTime;

  /// Check if Supabase client is configured and initialized
  static bool get isConfigured {
    try {
      return Supabase.instance.client.supabaseUrl.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Trigger anonymous sign-in if needed
  static Future<void> ensureSignedIn() async {
    if (!isConfigured) return;
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously().timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Record consent and create/update the installs row in Supabase
  static Future<void> recordConsent({
    required List<String> languages,
    required List<String> favArtists,
    required String appVersion,
    String? deviceModel,
    String? osVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Always persist consent locally immediately so user is never blocked or re-prompted
    await prefs.setBool('consent_given', true);

    if (!isConfigured) return;

    try {
      await ensureSignedIn();

      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await client.from('installs').upsert({
        'id': uid,
        'consent_at': nowUtc,
        'last_seen_at': nowUtc,
        'app_version': appVersion,
        'device_model': deviceModel,
        'os_version': osVersion,
        'languages': languages,
        'fav_artists': favArtists,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Update user taste preferences on the installs row
  static Future<void> updatePreferences({
    List<String>? languages,
    List<String>? favArtists,
  }) async {
    if (!isConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    final consent = prefs.getBool('consent_given') ?? false;
    if (!consent) return;

    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final updates = <String, dynamic>{
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (languages != null) updates['languages'] = languages;
    if (favArtists != null) updates['fav_artists'] = favArtists;

    try {
      await client.from('installs').update(updates).eq('id', uid);
    } catch (_) {}
  }

  /// Log playlist import (matched track keys only)
  static Future<void> logPlaylistImport({
    required String sourcePlatform,
    required List<String> matchedTrackKeys,
    required int unmatchedCount,
  }) async {
    if (!isConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    final consent = prefs.getBool('consent_given') ?? false;
    if (!consent) return;

    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await client.from('playlist_imports').insert({
        'id': const Uuid().v4(),
        'install_id': uid,
        'source_platform': sourcePlatform,
        'track_keys': matchedTrackKeys,
        'matched': matchedTrackKeys.length,
        'unmatched': unmatchedCount,
      });
    } catch (_) {}
  }

  /// Delete all remote data for this install and wipe local event history
  static Future<void> deleteMyData() async {
    if (isConfigured) {
      try {
        final client = Supabase.instance.client;
        await client.rpc('delete_my_data').timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final db = await LocalDb.instance;
    await db.delete('play_events');
    await db.delete('tracks');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_given', false);
  }

  /// Flush unsynced play events to Supabase with auto-stale override and timeout
  Future<void> flush() async {
    final stale = _startedAt != null &&
        DateTime.now().difference(_startedAt!) > const Duration(minutes: 2);
    if (_running && !stale) return;

    if (!isConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    final consent = prefs.getBool('consent_given') ?? false;
    if (!consent) return;

    _running = true;
    _startedAt = DateTime.now();

    try {
      await _doFlush().timeout(const Duration(seconds: 60));
    } catch (e) {
      debugPrint('EventUploader.flush error or timeout: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _doFlush() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await ensureSignedIn();
      if (client.auth.currentSession == null) return;
    }

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) return;

    final db = await LocalDb.instance;
    final uid = client.auth.currentUser!.id;

    // Update last_seen_at on installs for operational activity tracking
    try {
      await client.from('installs').update({
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid).timeout(const Duration(seconds: 5));
    } catch (_) {}

    while (true) {
      // Only upload closed and interrupted rows (never open checkpointing sessions)
      final events = await db.query(
        'play_events',
        where: "synced = 0 AND status IN ('closed', 'interrupted')",
        orderBy: 'occurred_at ASC',
        limit: 200,
      );
      if (events.isEmpty) break;

      // 1. Sync tracks first (foreign key dependency)
      final keys = events.map((e) => e['track_key'] as String).toSet().toList();
      final placeholders = List.filled(keys.length, '?').join(',');
      final tracks = await db.query(
        'tracks',
        where: 'track_key IN ($placeholders)',
        whereArgs: keys,
      );

      if (tracks.isNotEmpty) {
        await client.from('tracks').upsert(
          tracks.map(_trackToRemote).toList(),
          onConflict: 'track_key',
          ignoreDuplicates: true,
        ).timeout(const Duration(seconds: 25));
      }

      // 2. Sync events idempotently by id
      await client.from('play_events').upsert(
        events.map((e) => _eventToRemote(e, uid)).toList(),
        onConflict: 'id',
        ignoreDuplicates: true,
      ).timeout(const Duration(seconds: 25));

      // 3. Mark synced locally
      final ids = events.map((e) => e['id'] as String).toList();
      final idPlaceholders = List.filled(ids.length, '?').join(',');
      await db.update(
        'play_events',
        {'synced': 1},
        where: 'id IN ($idPlaceholders)',
        whereArgs: ids,
      );
    }

    // 4. Local Pruning: Delete synced rows older than 30 days
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete(
      'play_events',
      where: 'synced = 1 AND occurred_at < ?',
      whereArgs: [thirtyDaysAgo],
    );

    // 5. Cap synced rows at 5,000 maximum to keep SQLite fast and lean
    final syncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM play_events WHERE synced = 1'),
    ) ?? 0;
    if (syncedCount > 5000) {
      await db.rawDelete('''
        DELETE FROM play_events WHERE id IN (
          SELECT id FROM play_events WHERE synced = 1 ORDER BY occurred_at ASC LIMIT ?
        )
      ''', [syncedCount - 5000]);
    }

    _lastFlushTime = DateTime.now();
  }

  Map<String, dynamic> _trackToRemote(Map<String, Object?> r) => {
    'track_key': r['track_key'],
    'artist_primary': r['artist_primary'],
    'artists_all': r['artists_all'] == null
        ? null
        : List<String>.from(jsonDecode(r['artists_all'] as String)),
    'language': r['language'],
    'genre': r['genre'],
    'mood': r['mood'],
    'era': r['era'],
    'tag_confidence': r['tag_confidence'],
    'provider': r['provider'],
    'provider_track_id': r['provider_track_id'],
    'schema_version': r['schema_version'],
  };

  Map<String, dynamic> _eventToRemote(Map<String, Object?> r, String uid) => {
    'id': r['id'],
    'install_id': uid,
    'track_key': r['track_key'],
    'seed_track_key': r['seed_track_key'],
    'origin': r['origin'],
    'listened_ms': r['listened_ms'],
    'duration_ms': r['duration_ms'],
    'liked': r['liked'] == 1,
    'added_to_playlist': r['added_to_playlist'] == 1,
    'downloaded': r['downloaded'] == 1,
    'buffer_stall': r['buffer_stall'] == 1,
    'score': r['score'],
    'score_parts': r['score_parts'] == null
        ? null
        : jsonDecode(r['score_parts'] as String),
    'temperature': r['temperature'],
    'model_version': r['model_version'],
    'hour_bucket': r['hour_bucket'],
    'tz_offset_minutes': r['tz_offset_minutes'] ?? 0,
    'status': r['status'] ?? 'closed',
    'ended_reason': r['ended_reason'],
    'occurred_at': r['occurred_at'],
    'schema_version': r['schema_version'],
  };
}
