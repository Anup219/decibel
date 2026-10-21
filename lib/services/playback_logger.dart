import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/track_features.dart';
import 'local_db.dart';

enum PlaybackOrigin { search, recommended, baseline, radio }

class PlaybackLogger {
  static final PlaybackLogger _instance = PlaybackLogger._internal();
  factory PlaybackLogger() => _instance;
  PlaybackLogger._internal();

  final _uuid = const Uuid();
  String? _currentSessionId;
  TrackFeatures? _currentTrack;
  PlaybackOrigin? _currentOrigin;
  String? _currentSeedTrackKey;
  int _currentDurationMs = 0;
  int _lastCheckpointedMs = 0;
  DateTime _lastCheckpointWriteTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool _currentLiked = false;
  bool _currentAddedToPlaylist = false;
  bool _currentDownloaded = false;
  bool _currentBufferStall = false;

  void markLiked(bool value) {
    _currentLiked = value;
    checkpointPosition(_lastCheckpointedMs, forceImmediate: true);
  }

  void markAddedToPlaylist(bool value) {
    _currentAddedToPlaylist = value;
    checkpointPosition(_lastCheckpointedMs, forceImmediate: true);
  }

  void markDownloaded(bool value) {
    _currentDownloaded = value;
    checkpointPosition(_lastCheckpointedMs, forceImmediate: true);
  }

  void markBufferStall(bool value) {
    _currentBufferStall = value;
    checkpointPosition(_lastCheckpointedMs, forceImmediate: true);
  }

  /// On track start: insert a row directly into play_events with status = 'open' and listened_ms = 0
  Future<void> onTrackStarted({
    required TrackFeatures track,
    required PlaybackOrigin origin,
    required int durationMs,
    String? seedTrackKey,
    double? score,
    Map<String, dynamic>? scoreParts,
    double? temperature,
    String? modelVersion,
  }) async {
    // If a session was already open, close it cleanly first
    if (_currentSessionId != null) {
      await finalizeActiveSession(
        durationMs: _currentDurationMs > 0 ? _currentDurationMs : durationMs,
        listenedMs: _lastCheckpointedMs,
        endedReason: 'next',
      );
    }

    if (durationMs <= 0) return;

    final sessionId = _uuid.v4();
    final now = DateTime.now();
    _currentSessionId = sessionId;
    _currentTrack = track;
    _currentOrigin = origin;
    _currentSeedTrackKey = seedTrackKey;
    _currentDurationMs = durationMs;
    _lastCheckpointedMs = 0;
    _lastCheckpointWriteTime = now;
    _currentLiked = false;
    _currentAddedToPlaylist = false;
    _currentDownloaded = false;
    _currentBufferStall = false;

    // Version score_parts inside the payload with {"v": 1, ...}
    Map<String, dynamic>? versionedScoreParts;
    if (scoreParts != null) {
      versionedScoreParts = Map<String, dynamic>.from(scoreParts);
      versionedScoreParts['v'] = versionedScoreParts['v'] ?? 1;
    } else if (score != null) {
      versionedScoreParts = {'v': 1, 'score': score};
    }

    try {
      final db = await LocalDb.instance;
      // 1. Ensure track exists in local catalog
      await db.insert('tracks', track.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

      // 2. Insert row with status = 'open' and listened_ms = 0
      await db.insert(
        'play_events',
        {
          'id': sessionId,
          'track_key': track.trackKey,
          'seed_track_key': seedTrackKey,
          'origin': origin.name,
          'listened_ms': 0,
          'duration_ms': durationMs,
          'liked': 0,
          'added_to_playlist': 0,
          'downloaded': 0,
          'buffer_stall': 0,
          'score': score,
          'score_parts': versionedScoreParts == null ? null : jsonEncode(versionedScoreParts),
          'temperature': temperature,
          'model_version': modelVersion ?? 'v1',
          'hour_bucket': _hourBucket(now),
          'tz_offset_minutes': now.timeZoneOffset.inMinutes,
          'status': 'open',
          'ended_reason': null,
          'occurred_at': now.toUtc().toIso8601String(),
          'schema_version': 1,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('PlaybackLogger.onTrackStarted error: $e');
    }
  }

  /// Checkpoints listened_ms every ~10s and on pause / app pause
  Future<void> checkpointPosition(int positionMs, {bool forceImmediate = false}) async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;

    _lastCheckpointedMs = positionMs;
    final now = DateTime.now();

    // Throttle checkpoint writes to at most once every 8 seconds unless forceImmediate
    if (!forceImmediate && now.difference(_lastCheckpointWriteTime).inSeconds < 8) {
      return;
    }
    _lastCheckpointWriteTime = now;

    try {
      final db = await LocalDb.instance;
      await db.update(
        'play_events',
        {
          'listened_ms': positionMs,
          'liked': _currentLiked ? 1 : 0,
          'added_to_playlist': _currentAddedToPlaylist ? 1 : 0,
          'downloaded': _currentDownloaded ? 1 : 0,
          'buffer_stall': _currentBufferStall ? 1 : 0,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [sessionId, 'open'],
      );
    } catch (e) {
      debugPrint('PlaybackLogger.checkpointPosition error: $e');
    }
  }

  /// On track leave: sets final listened_ms and status = 'closed' with ended_reason ('completed', 'skipped', 'next', 'unknown')
  Future<void> finalizeActiveSession({
    required int durationMs,
    required int listenedMs,
    String endedReason = 'unknown',
  }) async {
    final sessionId = _currentSessionId;
    _currentSessionId = null;
    _currentTrack = null;
    _currentOrigin = null;

    if (sessionId == null || durationMs <= 0) return;

    final effectiveListenedMs = listenedMs.clamp(0, durationMs * 2);

    try {
      final db = await LocalDb.instance;
      await db.update(
        'play_events',
        {
          'listened_ms': effectiveListenedMs,
          'duration_ms': durationMs,
          'liked': _currentLiked ? 1 : 0,
          'added_to_playlist': _currentAddedToPlaylist ? 1 : 0,
          'downloaded': _currentDownloaded ? 1 : 0,
          'buffer_stall': _currentBufferStall ? 1 : 0,
          'status': 'closed',
          'ended_reason': endedReason,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('PlaybackLogger.finalizeActiveSession error: $e');
    }
  }

  /// On app start: convert any leftover 'open' rows to 'interrupted', keeping the last checkpoint value
  Future<void> recoverInterruptedSessions() async {
    try {
      final db = await LocalDb.instance;
      final count = await db.update(
        'play_events',
        {
          'status': 'interrupted',
          'ended_reason': 'unknown',
        },
        where: 'status = ?',
        whereArgs: ['open'],
      );
      if (count > 0) {
        debugPrint('Recovered $count interrupted playback sessions from previous launch.');
      }
    } catch (e) {
      debugPrint('PlaybackLogger.recoverInterruptedSessions error: $e');
    }
  }

  static String _hourBucket(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 22) return 'evening';
    return 'night';
  }
}
