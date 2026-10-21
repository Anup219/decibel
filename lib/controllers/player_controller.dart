import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mix_box.dart';
import '../models/track.dart';
import '../models/track_features.dart';
import '../services/decibel_audio_handler.dart';
import '../services/decibel_mix_engine.dart';
import '../services/download_service.dart';
import '../services/event_uploader.dart';
import '../services/full_song_stream_resolver.dart';
import '../services/lyrics_service.dart';
import '../services/playback_logger.dart';
import '../services/sync_scheduler.dart';

enum DecibelRepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DecibelAudioHandler? _audioHandler;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentQueueIndex = 0;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;

  bool _isShuffle = false;
  DecibelRepeatMode _repeatMode = DecibelRepeatMode.off;
  bool _isAutoplayEnabled = true;
  bool _isReplenishingQueue = false;
  bool _isHandlingTrackEnded = false;
  final List<int> _unplayedShuffleIndices = [];

  final Set<String> _likedTrackIds = {};
  final List<Track> _likedTracks = [];
  final Set<String> _downloadedTrackIds = {};
  final List<Track> _downloadedTracks = [];
  final Set<String> _downloadingTrackIds = {};
  final List<UserPlaylist> _playlists = [];

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentQueueIndex;

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;

  bool get isShuffle => _isShuffle;
  DecibelRepeatMode get repeatMode => _repeatMode;
  bool get isAutoplayEnabled => _isAutoplayEnabled;
  bool get isReplenishingQueue => _isReplenishingQueue;

  Set<String> get likedTrackIds => Set.unmodifiable(_likedTrackIds);
  List<Track> get likedTracks => List.unmodifiable(_likedTracks);
  Set<String> get downloadedTrackIds => Set.unmodifiable(_downloadedTrackIds);
  List<Track> get downloadedTracks => List.unmodifiable(_downloadedTracks);
  Set<String> get downloadingTrackIds => Set.unmodifiable(_downloadingTrackIds);
  List<UserPlaylist> get playlists => List.unmodifiable(_playlists);

  bool isTrackDownloaded(String id) => _downloadedTrackIds.contains(id);
  bool isDownloading(String id) => _downloadingTrackIds.contains(id);

  PlayerController({DecibelAudioHandler? audioHandler}) : _audioHandler = audioHandler {
    _initAudioHandlerCallbacks();
    _initAudioListeners();
    _loadPersistedData();
  }

  void _initAudioHandlerCallbacks() {
    final handler = _audioHandler;
    if (handler == null) return;
    handler.onPlay = togglePlayPause;
    handler.onPause = togglePlayPause;
    handler.onSkipNext = skipNext;
    handler.onSkipPrevious = skipPrevious;
    handler.onSeek = seekTo;
    handler.onStop = stop;
  }

  void _syncPlaybackState() {
    final handler = _audioHandler;
    if (handler == null) return;

    AudioProcessingState processingState;
    switch (_audioPlayer.processingState) {
      case ProcessingState.idle:
        processingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        processingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        processingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        processingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        processingState = AudioProcessingState.completed;
        break;
    }

    handler.updatePlaybackState(
      playing: _isPlaying,
      processingState: processingState,
      position: _currentPosition,
      bufferedPosition: _bufferedPosition,
      speed: _audioPlayer.speed,
      queueIndex: _currentQueueIndex,
    );
  }

  void _updateMediaItemMetadata() {
    final handler = _audioHandler;
    if (handler == null || _currentTrack == null) return;
    handler.updateMediaItem(
      MediaItem(
        id: _currentTrack!.id,
        album: _currentTrack!.album.isNotEmpty ? _currentTrack!.album : 'DECIBEL Music',
        title: _currentTrack!.title,
        artist: _currentTrack!.artist,
        artUri: _currentTrack!.artworkUrl.isNotEmpty ? Uri.tryParse(_currentTrack!.artworkUrl) : null,
        duration: _duration,
      ),
    );
    _syncQueue();
  }

  void _syncQueue() {
    final handler = _audioHandler;
    if (handler == null) return;
    handler.updateQueue(
      _queue.map((t) => MediaItem(
        id: t.id,
        album: t.album.isNotEmpty ? t.album : 'DECIBEL Music',
        title: t.title,
        artist: t.artist,
        artUri: t.artworkUrl.isNotEmpty ? Uri.tryParse(t.artworkUrl) : null,
      )).toList(),
    );
  }

  void _initAudioListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing && state.processingState != ProcessingState.completed;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
      _syncPlaybackState();

      if (!playing && _currentPosition.inMilliseconds > 0) {
        PlaybackLogger().checkpointPosition(_currentPosition.inMilliseconds, forceImmediate: true);
      }

      if (state.processingState == ProcessingState.buffering) {
        PlaybackLogger().markBufferStall(true);
      }

      if (state.processingState == ProcessingState.completed) {
        if (!_isHandlingTrackEnded) {
          _isHandlingTrackEnded = true;
          _handleTrackEnded().whenComplete(() {
            _isHandlingTrackEnded = false;
          });
        }
      }
    });

    DateTime lastSyncTime = DateTime.now();
    _audioPlayer.positionStream.listen((pos) {
      _currentPosition = pos;
      final now = DateTime.now();
      if (now.difference(lastSyncTime).inMilliseconds >= 800) {
        lastSyncTime = now;
        _syncPlaybackState();
      }
      if (pos.inSeconds > 0 && pos.inSeconds % 10 == 0) {
        PlaybackLogger().checkpointPosition(pos.inMilliseconds);
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        _updateMediaItemMetadata();
        _syncPlaybackState();
        notifyListeners();
      }
    });

    _audioPlayer.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      _syncPlaybackState();
      notifyListeners();
    });
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Liked songs
    final likedJson = prefs.getString('decibel_liked_tracks_list');
    if (likedJson != null) {
      try {
        final list = (jsonDecode(likedJson) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _likedTracks.clear();
        _likedTracks.addAll(list);
        _likedTrackIds.clear();
        _likedTrackIds.addAll(list.map((t) => t.id));
      } catch (_) {}
    }

    // Downloaded songs
    final dlJson = prefs.getString('decibel_downloaded_tracks');
    if (dlJson != null) {
      try {
        final list = (jsonDecode(dlJson) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        final List<Track> verified = [];
        for (final t in list) {
          final audioPath = t.localFilePath ?? await DownloadService.getAudioFilePath(t.id);
          if (DownloadService.isLocalFileValid(audioPath)) {
            final artPath = await DownloadService.getArtworkFilePath(t.id);
            final hasLocalArt = DownloadService.isLocalFileValid(artPath);
            verified.add(t.copyWith(
              localFilePath: audioPath,
              artworkUrl: hasLocalArt ? artPath : t.artworkUrl,
              streamUrl: audioPath,
            ));
          } else {
            verified.add(t);
          }
        }
        _downloadedTracks.clear();
        _downloadedTracks.addAll(verified);
        _downloadedTrackIds.clear();
        _downloadedTrackIds.addAll(verified.map((t) => t.id));
      } catch (_) {}
    }

    // Playlists
    final plJson = prefs.getString('decibel_user_playlists');
    if (plJson != null) {
      try {
        final list = (jsonDecode(plJson) as List)
            .map((e) => UserPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
        _playlists.clear();
        _playlists.addAll(list);
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> playTrack(
    Track track, {
    List<Track>? newQueue,
    PlaybackOrigin origin = PlaybackOrigin.recommended,
  }) async {
    // 1. Finalize prior playback session if one was active
    if (_currentTrack != null) {
      final wasSkipped = _currentPosition.inSeconds < 25;
      await PlaybackLogger().finalizeActiveSession(
        durationMs: _duration.inMilliseconds > 0 ? _duration.inMilliseconds : _currentTrack!.durationMs,
        listenedMs: _currentPosition.inMilliseconds,
        endedReason: wasSkipped ? 'skipped' : 'next',
      );
      SyncScheduler().onEventLogged();
    }

    final previousTrackKey = _currentTrack != null ? TrackFeatures.fromTrack(_currentTrack!).trackKey : null;

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentQueueIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentQueueIndex < 0) _currentQueueIndex = 0;
      if (_isShuffle) {
        _rebuildShuffleDeck();
      }
    } else if (_queue.isEmpty) {
      _queue = [track];
      _currentQueueIndex = 0;
    } else {
      final existingIndex = _queue.indexWhere((t) => t.id == track.id);
      if (existingIndex >= 0) {
        _currentQueueIndex = existingIndex;
      } else {
        _queue.insert(_currentQueueIndex + 1, track);
        _currentQueueIndex++;
      }
    }

    _currentTrack = track;
    _currentPosition = Duration.zero;
    _duration = Duration(milliseconds: track.durationMs);
    _updateMediaItemMetadata();
    _syncPlaybackState();
    notifyListeners();

    // 2. Start new telemetry session
    final trackFeatures = TrackFeatures.fromTrack(track);
    PlaybackLogger().onTrackStarted(
      track: trackFeatures,
      origin: origin,
      durationMs: track.durationMs,
      seedTrackKey: previousTrackKey,
      modelVersion: 'heuristic_v1',
    );

    // Record interaction in mix engine
    DecibelMixEngine.recordTrackPlayed(track);

    // Asynchronously pre-fetch synchronized lyrics
    LyricsService.fetchLyrics(track).then((l) {
      if (_currentTrack?.id == track.id && l.isNotEmpty) {
        _currentTrack = _currentTrack!.copyWith(lyrics: l);
        notifyListeners();
      }
    });

    // Proactively replenish upcoming queue if nearing the end
    if (_queue.length - _currentQueueIndex <= 4) {
      _replenishQueueIfNeeded(track);
    }

    // 1. Check if track has an offline downloaded file on disk (100% offline playback)
    String? localAudioPath = track.localFilePath;
    if (localAudioPath == null || !DownloadService.isLocalFileValid(localAudioPath)) {
      final potentialPath = await DownloadService.getAudioFilePath(track.id);
      if (DownloadService.isLocalFileValid(potentialPath)) {
        localAudioPath = potentialPath;
      }
    }

    if (localAudioPath != null && DownloadService.isLocalFileValid(localAudioPath)) {
      try {
        debugPrint('Playing track from verified offline file: $localAudioPath');
        final artUri = track.artworkUrl.isNotEmpty
            ? (track.artworkUrl.startsWith('http')
                ? Uri.tryParse(track.artworkUrl)
                : Uri.file(track.artworkUrl))
            : null;
        final audioSource = AudioSource.file(
          localAudioPath,
          tag: MediaItem(
            id: track.id,
            album: track.album.isNotEmpty ? track.album : 'DECIBEL Music',
            title: track.title,
            artist: track.artist,
            artUri: artUri,
          ),
        );
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(audioSource);
        await _audioPlayer.play();
        _consecutivePlaybackFailures = 0;
        _syncPlaybackState();
        _prefetchNextTrackStream();
        return;
      } catch (e) {
        debugPrint('Local playback error: $e');
        await _handlePlaybackFailure();
        return;
      }
    }

    // 2. Online streaming fallback: resolve full 320kbps audio stream if placeholder or preview
    String playableUrl = track.streamUrl;
    final isPreview = playableUrl.isEmpty ||
        playableUrl.contains('itunes.apple.com') ||
        playableUrl.contains('preview');

    if (isPreview) {
      final fullUrl = await FullSongStreamResolver.resolveFullAudioStream(track.title, track.artist);
      if (fullUrl != null && fullUrl.isNotEmpty) {
        playableUrl = fullUrl;
        _currentTrack = _currentTrack!.copyWith(streamUrl: fullUrl);
        // Update in queue
        if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
          _queue[_currentQueueIndex] = _currentTrack!;
        }
        _updateMediaItemMetadata();
        _syncPlaybackState();
      }
    }

    if (playableUrl.isNotEmpty && (playableUrl.startsWith('http') || playableUrl.startsWith('https'))) {
      try {
        final audioSource = AudioSource.uri(
          Uri.parse(playableUrl),
          tag: MediaItem(
            id: track.id,
            album: track.album.isNotEmpty ? track.album : 'DECIBEL Music',
            title: track.title,
            artist: track.artist,
            artUri: track.artworkUrl.isNotEmpty ? Uri.tryParse(track.artworkUrl) : null,
          ),
        );
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(audioSource);
        await _audioPlayer.play();
        _consecutivePlaybackFailures = 0;
        _syncPlaybackState();
        _prefetchNextTrackStream();
      } catch (e) {
        debugPrint('Playback error: $e');
        await _handlePlaybackFailure();
      }
    } else {
      debugPrint('Playable URL resolution failed for: ${track.title}');
      await _handlePlaybackFailure();
    }
  }

  int _consecutivePlaybackFailures = 0;

  /// Fail-Safe auto-skip on network or stream failure (Spotify / YouTube Music standard)
  Future<void> _handlePlaybackFailure() async {
    _consecutivePlaybackFailures++;
    if (_consecutivePlaybackFailures >= 4) {
      debugPrint('Too many consecutive stream failures. Pausing playback.');
      _consecutivePlaybackFailures = 0;
      await stop();
      return;
    }
    debugPrint('Auto-advancing to next track due to stream error (attempt $_consecutivePlaybackFailures)...');
    await Future.delayed(const Duration(milliseconds: 300));
    await skipNext();
  }

  /// Gapless background prefetch: pre-resolves upcoming track stream while current track is playing
  void _prefetchNextTrackStream() {
    final nextIdx = _currentQueueIndex + 1;
    if (nextIdx < _queue.length) {
      final nextTrack = _queue[nextIdx];
      final isPreview = nextTrack.streamUrl.isEmpty ||
          nextTrack.streamUrl.contains('itunes.apple.com') ||
          nextTrack.streamUrl.contains('preview');
      if (isPreview) {
        FullSongStreamResolver.resolveFullAudioStream(nextTrack.title, nextTrack.artist).then((url) {
          if (url != null && url.isNotEmpty && nextIdx < _queue.length && _queue[nextIdx].id == nextTrack.id) {
            _queue[nextIdx] = nextTrack.copyWith(streamUrl: url);
          }
        });
      }
    }
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    await playTrack(tracks[safeIndex], newQueue: tracks);
  }

  /// Starts playback of the given playlist/mix with immediate shuffle order
  Future<void> playQueueShuffled(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final shuffled = List<Track>.from(tracks)..shuffle();
    _isShuffle = true;
    _rebuildShuffleDeck();
    await playTrack(shuffled.first, newQueue: shuffled);
  }

  /// Plays a single searched song and immediately builds an infinite randomized radio queue behind it
  Future<void> playTrackFromSearch(Track track, {List<Track>? searchContext}) async {
    await playTrack(track, newQueue: [track], origin: PlaybackOrigin.search);
    await _replenishQueueIfNeeded(track, force: true);
  }

  void addToQueue(Track track) {
    if (_queue.isEmpty) {
      playTrack(track);
      return;
    }
    _queue.removeWhere((t) => t.id == track.id);
    _queue.add(track);
    _syncQueue();
    notifyListeners();
  }

  void playNext(Track track) {
    if (_queue.isEmpty) {
      playTrack(track);
      return;
    }
    _queue.removeWhere((t) => t.id == track.id);
    final insertIndex = (_currentQueueIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    _syncQueue();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) {
      if (_queue.isNotEmpty) {
        await playTrack(_queue.first);
      }
      return;
    }

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      // Fix bug: if song completed or is at the end, seek to zero before playing
      if (_audioPlayer.processingState == ProcessingState.completed ||
          (_duration > Duration.zero && _currentPosition >= _duration - const Duration(milliseconds: 600))) {
        await _audioPlayer.seek(Duration.zero);
      } else if (_audioPlayer.processingState == ProcessingState.idle) {
        await playTrack(_currentTrack!);
        return;
      }
      await _audioPlayer.play();
    }
    _syncPlaybackState();
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _currentPosition = position;
    _syncPlaybackState();
    notifyListeners();
  }

  void _rebuildShuffleDeck() {
    _unplayedShuffleIndices.clear();
    final indices = List.generate(_queue.length, (i) => i)..remove(_currentQueueIndex);
    indices.shuffle();
    _unplayedShuffleIndices.addAll(indices);
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      if (_unplayedShuffleIndices.isEmpty) {
        _rebuildShuffleDeck();
      }
      if (_unplayedShuffleIndices.isNotEmpty) {
        final nextIdx = _unplayedShuffleIndices.removeAt(0);
        if (nextIdx < _queue.length) {
          await playTrack(_queue[nextIdx]);
          if (_unplayedShuffleIndices.length <= 2) {
            _replenishQueueIfNeeded(_queue[nextIdx]);
          }
          return;
        }
      }
    }

    // Implicit Feedback based on play duration (YouTube Music completion / skip model)
    if (_currentTrack != null) {
      final origin = _currentOrigin ?? PlaybackOrigin.recommended;
      if (_currentPosition.inSeconds < 15) {
        DecibelMixEngine.recordQuickSkip(_currentTrack!, origin: origin);
      } else if (_currentPosition.inSeconds >= 45 ||
          (_duration > Duration.zero &&
              _currentPosition.inMilliseconds >= _duration.inMilliseconds * 0.6)) {
        DecibelMixEngine.recordPositiveEngagement(_currentTrack!, origin: origin);
      }
    }

    final nextIndex = _currentQueueIndex + 1;
    if (nextIndex < _queue.length) {
      await playTrack(_queue[nextIndex]);
      // If nearing the end of active queue, prefetch more
      if (nextIndex >= _queue.length - 4) {
        _replenishQueueIfNeeded(_queue[nextIndex]);
      }
    } else {
      // End of user queue -> Trigger Continuous Autoplay
      await _triggerContinuousAutoplay();
    }
  }

  Future<void> skipPrevious() async {
    if (_currentPosition.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (_queue.isEmpty) return;
    final prevIndex = _currentQueueIndex - 1 < 0 ? _queue.length - 1 : _currentQueueIndex - 1;
    await playTrack(_queue[prevIndex]);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _rebuildShuffleDeck();
    } else {
      _unplayedShuffleIndices.clear();
    }
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case DecibelRepeatMode.off:
        _repeatMode = DecibelRepeatMode.all;
        break;
      case DecibelRepeatMode.all:
        _repeatMode = DecibelRepeatMode.one;
        break;
      case DecibelRepeatMode.one:
        _repeatMode = DecibelRepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void toggleAutoplay() {
    _isAutoplayEnabled = !_isAutoplayEnabled;
    notifyListeners();
  }

  Future<void> _handleTrackEnded() async {
    if (_queue.isEmpty) return;

    if (_currentTrack != null) {
      await PlaybackLogger().finalizeActiveSession(
        durationMs: _duration.inMilliseconds > 0 ? _duration.inMilliseconds : _currentTrack!.durationMs,
        listenedMs: _duration.inMilliseconds > 0 ? _duration.inMilliseconds : _currentTrack!.durationMs,
        endedReason: 'completed',
      );
      SyncScheduler().onEventLogged();
      DecibelMixEngine.recordPositiveEngagement(_currentTrack!, origin: _currentOrigin ?? PlaybackOrigin.recommended);
    }

    switch (_repeatMode) {
      case DecibelRepeatMode.one:
        await seekTo(Duration.zero);
        await _audioPlayer.play();
        break;
      case DecibelRepeatMode.all:
        final nextIdx = (_currentQueueIndex + 1);
        if (nextIdx < _queue.length) {
          await playTrack(_queue[nextIdx]);
        } else if (_isAutoplayEnabled) {
          await _triggerContinuousAutoplay();
        } else {
          await playTrack(_queue.first);
        }
        break;
      case DecibelRepeatMode.off:
        await skipNext();
        break;
    }
  }

  /// Automatically replenishes upcoming queue with fresh scored recommendations
  Future<void> _replenishQueueIfNeeded(Track track, {bool force = false}) async {
    if (!_isAutoplayEnabled) return;
    if (_isReplenishingQueue && !force) return;
    if (!force && _queue.length - _currentQueueIndex > 4) return;

    _isReplenishingQueue = true;
    try {
      final existingIds = _queue.map((t) => t.id).toSet();
      final existingTitles = _queue.map((t) => t.title).toSet();

      final recommended = await DecibelMixEngine.getAutoplayRecommendations(
        track,
        excludeIds: existingIds,
        excludeTitles: existingTitles,
      );

      if (recommended.isNotEmpty) {
        final startIndex = _queue.length;
        _queue.addAll(recommended);
        if (_isShuffle) {
          final newIndices = List.generate(recommended.length, (i) => startIndex + i)..shuffle();
          _unplayedShuffleIndices.addAll(newIndices);
        }
        _syncQueue();
        notifyListeners();
        _prefetchNextTrackStream();
      }
    } catch (_) {
    } finally {
      _isReplenishingQueue = false;
    }
  }

  /// Continuous non-stop playback when user presses Next or queue finishes
  Future<void> _triggerContinuousAutoplay() async {
    final track = _currentTrack;
    if (track == null) return;

    if (!_isAutoplayEnabled) {
      if (_queue.isNotEmpty) await playTrack(_queue.first);
      return;
    }

    _isReplenishingQueue = true;
    notifyListeners();

    try {
      final existingIds = _queue.map((t) => t.id).toSet();
      final existingTitles = _queue.map((t) => t.title).toSet();

      final recommended = await DecibelMixEngine.getAutoplayRecommendations(
        track,
        excludeIds: existingIds,
        excludeTitles: existingTitles,
      );

      if (recommended.isNotEmpty) {
        final startIndex = _queue.length;
        _queue.addAll(recommended);
        if (_isShuffle) {
          final newIndices = List.generate(recommended.length, (i) => startIndex + i)..shuffle();
          _unplayedShuffleIndices.addAll(newIndices);
        }
        _syncQueue();
        notifyListeners();
        await playTrack(_queue[startIndex]);
      } else {
        // Robust fallback: Pick tracks from liked songs that aren't the current track
        final fallbackPool = _likedTracks.where((t) => t.id != track.id).toList();
        if (fallbackPool.isNotEmpty) {
          fallbackPool.shuffle();
          final nextBatch = fallbackPool.take(5).toList();
          final startIndex = _queue.length;
          _queue.addAll(nextBatch);
          _syncQueue();
          notifyListeners();
          await playTrack(_queue[startIndex]);
        } else if (_queue.length > 1) {
          await playTrack(_queue.first);
        }
      }
    } finally {
      _isReplenishingQueue = false;
      notifyListeners();
    }
  }

  Future<bool> toggleDownload(Track track) async {
    final isDownloaded = _downloadedTrackIds.contains(track.id);
    if (isDownloaded) {
      _downloadedTrackIds.remove(track.id);
      _downloadedTracks.removeWhere((t) => t.id == track.id);
      notifyListeners();
      await DownloadService.deleteDownloadedTrack(track.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'decibel_downloaded_tracks',
        jsonEncode(_downloadedTracks.map((t) => t.toJson()).toList()),
      );
      return false;
    } else {
      _downloadingTrackIds.add(track.id);
      notifyListeners();

      try {
        final downloadedTrack = await DownloadService.downloadTrack(track);
        if (downloadedTrack != null) {
          _downloadedTrackIds.add(track.id);
          _downloadedTracks.removeWhere((t) => t.id == track.id);
          _downloadedTracks.insert(0, downloadedTrack);
          PlaybackLogger().markDownloaded(true);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'decibel_downloaded_tracks',
            jsonEncode(_downloadedTracks.map((t) => t.toJson()).toList()),
          );
          notifyListeners();
          return true;
        } else {
          return false;
        }
      } finally {
        _downloadingTrackIds.remove(track.id);
        notifyListeners();
      }
    }
  }

  Future<void> toggleLike(Track track) async {
    final isLiked = _likedTrackIds.contains(track.id);
    if (isLiked) {
      _likedTrackIds.remove(track.id);
      _likedTracks.removeWhere((t) => t.id == track.id);
    } else {
      _likedTrackIds.add(track.id);
      _likedTracks.insert(0, track);
      PlaybackLogger().markLiked(true);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'decibel_liked_tracks_list',
      jsonEncode(_likedTracks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    final newPl = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      imageUrl: '',
      trackCount: 0,
      tracks: const [],
    );
    _playlists.insert(0, newPl);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'decibel_user_playlists',
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }

  Future<UserPlaylist> saveImportedPlaylist(String name, List<Track> tracks, {String? coverUrl, String sourcePlatform = 'import'}) async {
    final playlistName = name.trim().isNotEmpty ? name.trim() : 'Imported Playlist';
    final firstArtwork = tracks.isNotEmpty ? tracks.first.artworkUrl : '';
    final newPl = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: playlistName,
      imageUrl: coverUrl != null && coverUrl.isNotEmpty
          ? coverUrl
          : firstArtwork,
      trackCount: tracks.length,
      tracks: tracks,
    );
    _playlists.insert(0, newPl);
    notifyListeners();

    // Log playlist import telemetry anonymously
    final matchedTrackKeys = tracks.map((t) => TrackFeatures.fromTrack(t).trackKey).toList();
    EventUploader.logPlaylistImport(
      sourcePlatform: sourcePlatform,
      matchedTrackKeys: matchedTrackKeys,
      unmatchedCount: 0,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'decibel_user_playlists',
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
    return newPl;
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = _playlists[index];
      if (pl.tracks.any((t) => t.id == track.id)) return;
      final updatedTracks = [track, ...pl.tracks];
      _playlists[index] = UserPlaylist(
        id: pl.id,
        name: pl.name,
        imageUrl: track.artworkUrl.isNotEmpty ? track.artworkUrl : pl.imageUrl,
        trackCount: updatedTracks.length,
        tracks: updatedTracks,
      );
      PlaybackLogger().markAddedToPlaylist(true);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'decibel_user_playlists',
        jsonEncode(_playlists.map((p) => p.toJson()).toList()),
      );
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'decibel_user_playlists',
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = _playlists[index];
      _playlists[index] = UserPlaylist(
        id: pl.id,
        name: clean,
        imageUrl: pl.imageUrl,
        trackCount: pl.trackCount,
        tracks: pl.tracks,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'decibel_user_playlists',
        jsonEncode(_playlists.map((p) => p.toJson()).toList()),
      );
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = _playlists[index];
      final updatedTracks = pl.tracks.where((t) => t.id != trackId).toList();
      _playlists[index] = UserPlaylist(
        id: pl.id,
        name: pl.name,
        imageUrl: updatedTracks.isNotEmpty ? updatedTracks.first.artworkUrl : pl.imageUrl,
        trackCount: updatedTracks.length,
        tracks: updatedTracks,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'decibel_user_playlists',
        jsonEncode(_playlists.map((p) => p.toJson()).toList()),
      );
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _syncPlaybackState();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
