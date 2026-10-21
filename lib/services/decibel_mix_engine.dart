import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mix_box.dart';
import '../models/track.dart';
import 'artist_preference_service.dart';
import 'language_preference_service.dart';
import 'music_search_service.dart';
import 'playback_logger.dart';

class DecibelMixEngine {
  static const String _keyRecentlyPlayed = 'recent_played_tracks';
  static const String _keyBox1Shuffled = 'box1_shuffled';
  static const String _keyArtistCounts = 'artist_counts';
  static const String _keyLanguageCounts = 'language_counts';
  static const String _keyDislikedTracks = 'decibel_disliked_tracks';
  static const String _keyDislikedArtists = 'decibel_disliked_artists';
  static const String _keyQuickSkips = 'decibel_quick_skips';
  static const String _keyCompletions = 'decibel_completions';
  static const String _keyBox2Tracks = 'decibel_box2_tracks';
  static const String _keyBox3Tracks = 'decibel_box3_tracks';
  static const String _keyBox4Tracks = 'decibel_box4_tracks';
  static const String _keyLastMixRefresh = 'decibel_last_mix_refresh_time';

  static final List<Track> _recentlyPlayed = [];
  static final List<Track> _box1Tracks = [];
  static List<Track> _box2Tracks = [];
  static List<Track> _box3Tracks = [];
  static List<Track> _box4Tracks = [];

  static final Map<String, int> _artistCounts = {};
  static final Map<String, int> _languageCounts = {};
  static final Map<String, int> _quickSkips = {};
  static final Map<String, int> _completions = {};
  static final Set<String> _dislikedTrackIds = {};
  static final Set<String> _dislikedArtists = {};

  static int _playsSinceLastRefresh = 0;
  static bool _isRefreshingMixes = false;

  static final ValueNotifier<List<DecibelMixBox>> mixBoxesNotifier =
      ValueNotifier<List<DecibelMixBox>>([]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load persisted state
    final recentJson = prefs.getString(_keyRecentlyPlayed);
    if (recentJson != null) {
      try {
        final list = (jsonDecode(recentJson) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _recentlyPlayed.addAll(list);
      } catch (_) {}
    }

    final box1Json = prefs.getString(_keyBox1Shuffled);
    if (box1Json != null) {
      try {
        final list = (jsonDecode(box1Json) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _box1Tracks.addAll(deduplicateTracks(list));
      } catch (_) {}
    }

    // Load persisted boxes for instant UI rendering
    final box2Json = prefs.getString(_keyBox2Tracks);
    if (box2Json != null) {
      try {
        final list = (jsonDecode(box2Json) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _box2Tracks = deduplicateTracks(list);
      } catch (_) {}
    }

    final box3Json = prefs.getString(_keyBox3Tracks);
    if (box3Json != null) {
      try {
        final list = (jsonDecode(box3Json) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _box3Tracks = deduplicateTracks(list);
      } catch (_) {}
    }

    final box4Json = prefs.getString(_keyBox4Tracks);
    if (box4Json != null) {
      try {
        final list = (jsonDecode(box4Json) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        _box4Tracks = deduplicateTracks(list);
      } catch (_) {}
    }

    final artistJson = prefs.getString(_keyArtistCounts);
    if (artistJson != null) {
      try {
        final map = (jsonDecode(artistJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        _artistCounts.addAll(map);
      } catch (_) {}
    }

    final langJson = prefs.getString(_keyLanguageCounts);
    if (langJson != null) {
      try {
        final map = (jsonDecode(langJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        _languageCounts.addAll(map);
      } catch (_) {}
    }

    final dislikedT = prefs.getStringList(_keyDislikedTracks);
    if (dislikedT != null) {
      _dislikedTrackIds.addAll(dislikedT);
    }

    final dislikedA = prefs.getStringList(_keyDislikedArtists);
    if (dislikedA != null) {
      _dislikedArtists.addAll(dislikedA);
    }

    final skipsJson = prefs.getString(_keyQuickSkips);
    if (skipsJson != null) {
      try {
        final map = (jsonDecode(skipsJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        _quickSkips.addAll(map);
      } catch (_) {}
    }

    final completionsJson = prefs.getString(_keyCompletions);
    if (completionsJson != null) {
      try {
        final map = (jsonDecode(completionsJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        _completions.addAll(map);
      } catch (_) {}
    }

    // Emit cached boxes immediately so home screen is instant
    _emitBoxes();

    // Auto-listen to language & artist preference changes to automatically refresh mixes
    LanguagePreferenceService.preferredLanguagesNotifier.addListener(() {
      refreshMixes(force: true);
    });
    ArtistPreferenceService.favoriteArtistsNotifier.addListener(() {
      refreshMixes(force: true);
    });

    // Automatically refresh mixes if empty or if stale (> 4 hours)
    final lastRefresh = prefs.getInt(_keyLastMixRefresh) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = (now - lastRefresh) > const Duration(hours: 4).inMilliseconds;

    if (_box2Tracks.isEmpty || _box3Tracks.isEmpty || _box4Tracks.isEmpty || isStale) {
      refreshMixes(force: isStale);
    }
  }

  static void recordTrackPlayed(Track track) {
    // 1. Update recently played queue
    _recentlyPlayed.removeWhere((t) => t.id == track.id || areSameSong(t, track));
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 40) {
      _recentlyPlayed.removeLast();
    }

    // 2. Update box 1 shuffled pool
    _box1Tracks.removeWhere((t) => t.id == track.id || areSameSong(t, track));
    _box1Tracks.insert(0, track);
    if (_box1Tracks.length > 40) {
      _box1Tracks.removeLast();
    }

    // 3. Affinity metrics
    final artist = track.artist.trim();
    if (artist.isNotEmpty) {
      _artistCounts[artist] = (_artistCounts[artist] ?? 0) + 1;
    }

    final lang = LanguagePreferenceService.detectTrackLanguage(track);
    _languageCounts[lang] = (_languageCounts[lang] ?? 0) + 1;

    _persistState();
    _emitBoxes();

    // 4. Automatically update mixes after every 4 songs played to evolve with user taste
    _playsSinceLastRefresh++;
    if (_playsSinceLastRefresh >= 4) {
      _playsSinceLastRefresh = 0;
      refreshMixes();
    }
  }

  static Future<void> refreshForLanguagePreferenceChange() async {
    await refreshMixes(force: true);
  }

  /// Automatically generates and updates all "Made for You" mix playlists
  static Future<void> refreshMixes({bool force = false}) async {
    if (_isRefreshingMixes) return;
    _isRefreshingMixes = true;

    try {
      final preferredLangs = LanguagePreferenceService.preferredLanguages;
      final mainLang = preferredLangs.isNotEmpty ? preferredLangs.first : 'Trending';
      final favArtists = ArtistPreferenceService.favoriteArtists;
      final topArtist = favArtists.isNotEmpty ? favArtists.first : _getTopArtist();

      // Top listened artists sorted by play count
      final topListened = _artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtistsPool = [
        ...favArtists,
        ...topListened.map((e) => e.key).where((a) => !isArtistBlocked(a)),
      ].take(4).toList();

      final futures = <Future>[];

      // Box 2: Daily Mix - personalized blend of user's top artists + main language hits
      futures.add(() async {
        final List<Track> dailyMix = [];
        final int year = DateTime.now().year;

        // Query top hits from user's favorite / top listened artists
        for (final artist in topArtistsPool.take(2)) {
          final res = await MusicSearchService.searchSongs('$artist hits', limit: 20);
          dailyMix.addAll(res);
        }

        // Blend with fresh language hits
        final langHits = await MusicSearchService.searchSongs('Top $mainLang Hits $year', limit: 25);
        dailyMix.addAll(langHits);

        if (dailyMix.isNotEmpty) {
          dailyMix.shuffle();
          _box2Tracks = deduplicateTracks(dailyMix).take(40).toList();
        }
      }());

      // Box 3: Artist Mix - dynamically centered on user's primary favorite or most listened artist
      futures.add(() async {
        final List<Track> artistMix = [];

        if (topArtist != 'Global Top Artists' && !isArtistBlocked(topArtist)) {
          final directHits = await MusicSearchService.searchSongs('$topArtist hits', limit: 25);
          artistMix.addAll(directHits);
          final radioHits = await MusicSearchService.searchSongs('$topArtist top songs', limit: 20);
          artistMix.addAll(radioHits);
        } else if (preferredLangs.length > 1) {
          final lHits = await MusicSearchService.searchSongs('Top ${preferredLangs[1]} Hits ${DateTime.now().year}', limit: 40);
          artistMix.addAll(lHits);
        } else {
          final chillHits = await MusicSearchService.searchSongs('Top Acoustic Hits ${DateTime.now().year}', limit: 40);
          artistMix.addAll(chillHits);
        }

        if (artistMix.isNotEmpty) {
          _box3Tracks = deduplicateTracks(artistMix).take(40).toList();
        }
      }());

      // Box 4: Release Radar - fresh releases matching user's languages and favorite artists
      futures.add(() async {
        final int year = DateTime.now().year;
        final radarQuery = topArtistsPool.isNotEmpty
            ? '${topArtistsPool.first} & Fresh $mainLang $year'
            : 'Fresh Releases $mainLang $year';
        final radar = await MusicSearchService.searchSongs(radarQuery, limit: 40);
        if (radar.isNotEmpty) {
          _box4Tracks = deduplicateTracks(radar).take(40).toList();
        }
      }());

      await Future.wait(futures.map((f) => f.catchError((_) async {})));

      final deduped1 = deduplicateTracks(_box1Tracks);
      _box1Tracks
        ..clear()
        ..addAll(deduped1);
      _box2Tracks = deduplicateTracks(_box2Tracks);
      _box3Tracks = deduplicateTracks(_box3Tracks);
      _box4Tracks = deduplicateTracks(_box4Tracks);

      _persistState();
      _emitBoxes();
    } catch (_) {
    } finally {
      _isRefreshingMixes = false;
    }
  }

  static void _emitBoxes() {
    final deduped1 = deduplicateTracks(_box1Tracks);
    _box1Tracks
      ..clear()
      ..addAll(deduped1);
    _box2Tracks = deduplicateTracks(_box2Tracks);
    _box3Tracks = deduplicateTracks(_box3Tracks);
    _box4Tracks = deduplicateTracks(_box4Tracks);

    final favArtists = ArtistPreferenceService.favoriteArtists;
    final topArtist = favArtists.isNotEmpty ? favArtists.first : _getTopArtist();
    final preferredLangs = LanguagePreferenceService.preferredLanguages;
    final topLang = preferredLangs.isNotEmpty ? preferredLangs.join(' & ') : _getTopLanguage();

    final box1 = DecibelMixBox(
      id: 'box_recently_played',
      title: 'Recently played',
      subtitle: '${_box1Tracks.length} songs • Auto-updated',
      cadenceBadge: 'Live',
      gradientColors: const [Color(0xFF0077B6), Color(0xFF023E8A)],
      tracks: List.unmodifiable(_box1Tracks),
    );

    final box2 = DecibelMixBox(
      id: 'box_mix_1',
      title: 'Daily Mix',
      subtitle: '$topLang picks for you',
      cadenceBadge: 'Daily Mix',
      gradientColors: const [Color(0xFF8338EC), Color(0xFF3A0CA3)],
      tracks: List.unmodifiable(_box2Tracks),
    );

    final box3 = DecibelMixBox(
      id: 'box_mix_2',
      title: topArtist != 'Global Top Artists' ? '$topArtist Mix' : 'Artist Mix',
      subtitle: topArtist != 'Global Top Artists' ? '$topArtist & radio' : 'Recommended Artists',
      cadenceBadge: 'Artist Mix',
      gradientColors: const [Color(0xFFFF006E), Color(0xFF9E0059)],
      tracks: List.unmodifiable(_box3Tracks),
    );

    final box4 = DecibelMixBox(
      id: 'box_radar',
      title: 'Release Radar',
      subtitle: 'Fresh $topLang releases',
      cadenceBadge: 'Weekly',
      gradientColors: const [Color(0xFF06D6A0), Color(0xFF118AB2)],
      tracks: List.unmodifiable(_box4Tracks),
    );

    mixBoxesNotifier.value = [box1, box2, box3, box4];
  }

  static Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyRecentlyPlayed,
      jsonEncode(_recentlyPlayed.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _keyBox1Shuffled,
      jsonEncode(_box1Tracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _keyBox2Tracks,
      jsonEncode(_box2Tracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _keyBox3Tracks,
      jsonEncode(_box3Tracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _keyBox4Tracks,
      jsonEncode(_box4Tracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setInt(_keyLastMixRefresh, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_keyArtistCounts, jsonEncode(_artistCounts));
    await prefs.setString(_keyLanguageCounts, jsonEncode(_languageCounts));
    await prefs.setString(_keyQuickSkips, jsonEncode(_quickSkips));
    await prefs.setString(_keyCompletions, jsonEncode(_completions));
    await prefs.setStringList(_keyDislikedTracks, _dislikedTrackIds.toList());
    await prefs.setStringList(_keyDislikedArtists, _dislikedArtists.toList());
  }

  /// Unified Signal Weighting Engine:
  /// - Search completions: positive update at 0.5x normal reward
  /// - Search skips: 0.0x (no update / penalty at all)
  /// - Recommended / radio / baseline plays: 1.0x full reward & penalty
  static double signalWeight(PlaybackOrigin origin, {required bool isCompletion}) {
    if (origin == PlaybackOrigin.search) {
      return isCompletion ? 0.5 : 0.0;
    }
    return 1.0;
  }

  /// Implicit Positive Signal: User listened to more than 60% of the song or completed it
  static void recordPositiveEngagement(
    Track track, {
    PlaybackOrigin origin = PlaybackOrigin.recommended,
  }) {
    final weight = signalWeight(origin, isCompletion: true);
    if (weight <= 0.0) return;

    final artist = extractPrimaryArtist(track.artist).trim();
    final artistIncrement = (2 * weight).round().clamp(1, 4);
    if (artist.isNotEmpty) {
      _completions[artist.toLowerCase()] = (_completions[artist.toLowerCase()] ?? 0) + 1;
      _artistCounts[artist] = (_artistCounts[artist] ?? 0) + artistIncrement;
    }
    final lang = LanguagePreferenceService.detectTrackLanguage(track);
    final langIncrement = (2 * weight).round().clamp(1, 4);
    _languageCounts[lang] = (_languageCounts[lang] ?? 0) + langIncrement;
    _persistState();
  }

  /// Implicit Negative Signal: User quickly skipped within the first 15 seconds
  static void recordQuickSkip(
    Track track, {
    PlaybackOrigin origin = PlaybackOrigin.recommended,
  }) {
    final weight = signalWeight(origin, isCompletion: false);
    if (weight <= 0.0) return; // Search skips produce no negative profile penalty

    final artist = extractPrimaryArtist(track.artist).trim();
    if (artist.isNotEmpty) {
      _quickSkips[artist.toLowerCase()] = (_quickSkips[artist.toLowerCase()] ?? 0) + 1;
      // Softly reduce affinity
      final current = _artistCounts[artist] ?? 1;
      if (current > 1) {
        _artistCounts[artist] = current - 1;
      }
    }
    _persistState();
  }

  static Future<void> recordTuneMyTaste(Track track, {required bool recommendMore}) async {
    final artist = extractPrimaryArtist(track.artist);
    final lang = LanguagePreferenceService.detectTrackLanguage(track);

    if (recommendMore) {
      if (artist.isNotEmpty) {
        _artistCounts[artist] = (_artistCounts[artist] ?? 0) + 4;
      }
      _languageCounts[lang] = (_languageCounts[lang] ?? 0) + 3;
    } else {
      _dislikedTrackIds.add(track.id);
      _dislikedTrackIds.add(track.title.toLowerCase().trim());
      if (artist.isNotEmpty) {
        _artistCounts[artist] = ((_artistCounts[artist] ?? 1) - 3).clamp(0, 9999);
      }
    }
    await _persistState();
    _emitBoxes();
  }

  static Future<void> blockArtist(String artistName) async {
    final clean = artistName.toLowerCase().trim();
    if (clean.isNotEmpty) {
      _dislikedArtists.add(clean);
      _artistCounts.remove(artistName);
      await _persistState();
      _emitBoxes();
    }
  }

  static bool isTrackDisliked(String id, String title) {
    return _dislikedTrackIds.contains(id) ||
        _dislikedTrackIds.contains(title.toLowerCase().trim());
  }

  static bool isArtistBlocked(String artist) {
    final clean = artist.toLowerCase().trim();
    for (final b in _dislikedArtists) {
      if (clean.contains(b) || b.contains(clean)) return true;
    }
    return false;
  }

  static String _getTopArtist() {
    if (_artistCounts.isEmpty) return 'Global Top Artists';
    var maxCount = -1;
    var top = 'Global Top Artists';
    for (final entry in _artistCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        top = entry.key;
      }
    }
    return top;
  }

  static String _getTopLanguage() {
    if (_languageCounts.isEmpty) return 'Trending';
    var maxCount = -1;
    var top = 'Trending';
    for (final entry in _languageCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        top = entry.key;
      }
    }
    return top;
  }

  /// Extracts the primary artist name, stripping guest appearances and delimiters
  static String extractPrimaryArtist(String rawArtist) {
    if (rawArtist.trim().isEmpty) return '';
    // Split by comma, &, ft., feat., with, /
    final parts = rawArtist.split(RegExp(r'[,&/]|(\bft\.?\b)|(\bfeat\.?\b)|(\bwith\b)', caseSensitive: false));
    return parts.first.trim();
  }

  /// Weighted Candidate Scoring Engine (Spotify BaRT & YouTube Music Hybrid)
  static double scoreTrack(Track candidate, Track currentTrack) {
    if (isTrackDisliked(candidate.id, candidate.title) || isArtistBlocked(candidate.artist)) {
      return -9999.0;
    }

    double score = 0.0;
    final primaryCurrentArtist = extractPrimaryArtist(currentTrack.artist).toLowerCase();
    final candidateArtist = candidate.artist.toLowerCase();
    final primaryCandidateArtist = extractPrimaryArtist(candidate.artist).toLowerCase();
    final favArtists = ArtistPreferenceService.favoriteArtists;

    // 1. Current Artist Continuity (+35 points if same artist, +20 if co-artist)
    if (primaryCurrentArtist.isNotEmpty && primaryCandidateArtist == primaryCurrentArtist) {
      score += 35.0;
    } else if (primaryCurrentArtist.isNotEmpty && candidateArtist.contains(primaryCurrentArtist)) {
      score += 20.0;
    }

    // 2. Favorite Artists Boost (+40 points for direct favorite artist)
    for (int i = 0; i < favArtists.length; i++) {
      final fav = favArtists[i].toLowerCase();
      if (candidateArtist.contains(fav)) {
        score += 40.0 - (i * 1.5).clamp(0.0, 15.0);
        break;
      }
    }

    // 3. User Historical Play Affinity (up to +25 points)
    final playCount = _artistCounts[candidate.artist.trim()] ?? 0;
    score += (playCount * 3.0).clamp(0.0, 25.0);

    // 4. Implicit Completion Bonus (+15 points)
    final completionCount = _completions[primaryCandidateArtist] ?? 0;
    score += (completionCount * 2.5).clamp(0.0, 15.0);

    // 5. Implicit Quick-Skip Penalty (-25 points)
    final skipCount = _quickSkips[primaryCandidateArtist] ?? 0;
    score -= (skipCount * 5.0).clamp(0.0, 25.0);

    // 6. Language Match Priority (+25 points)
    if (LanguagePreferenceService.matchesUserPreferences(candidate)) {
      score += 25.0;
      final preferred = LanguagePreferenceService.preferredLanguages;
      if (preferred.isNotEmpty &&
          candidate.language.toLowerCase() == preferred.first.toLowerCase()) {
        score += 10.0;
      }
    } else {
      // Language doesn't match: unless it is a favorite artist, penalize heavily
      final isFav = favArtists.any((f) => candidateArtist.contains(f.toLowerCase()));
      if (!isFav) {
        score -= 50.0;
      }
    }

    // 7. Anti-Repetition Fatigue Penalty (Spotify standard)
    // Strongly penalizes songs played within the last 25 tracks
    final recentIndex = _recentlyPlayed.indexWhere((t) => t.id == candidate.id || areSameSong(t, candidate));
    if (recentIndex >= 0 && recentIndex < 25) {
      score -= (80.0 - (recentIndex * 2.5));
    }

    // 8. Controlled Serendipity & Exploration (Dynamic noise factor 0.0 to 12.0)
    final hash = ((candidate.id.hashCode.abs() + DateTime.now().minute) % 100) / 8.0;
    score += hash;

    return score;
  }

  /// Robust Title Normalizer (Spotify / Apple Music / YouTube Music standard):
  /// Strips version tags, film labels, lofi tags, acoustic tags, remix labels,
  /// featured artists, and video metadata so different versions of the same song
  /// resolve to an identical canonical title.
  static String canonicalTitle(String title, {String? album, String? artist}) {
    if (title.trim().isEmpty) return '';
    String clean = title;

    // 0. Decode common HTML entities
    clean = clean
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // 1. YouTube/Streaming metadata delimiters: take part before first pipe or bullet
    if (clean.contains('|')) {
      final beforePipe = clean.split('|').first.trim();
      if (beforePipe.isNotEmpty) clean = beforePipe;
    }
    if (clean.contains('•')) {
      final beforeBullet = clean.split('•').first.trim();
      if (beforeBullet.isNotEmpty) clean = beforeBullet;
    }
    if (clean.contains('~')) {
      final beforeTilde = clean.split('~').first.trim();
      if (beforeTilde.isNotEmpty) clean = beforeTilde;
    }

    clean = clean.toLowerCase();

    // 2. Remove all bracketed contents: round (), square [], curly {}, and Asian brackets 【】 （）
    clean = clean.replaceAll(RegExp(r'\([^\)]*\)'), '');
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    clean = clean.replaceAll(RegExp(r'\{[^\}]*\}'), '');
    clean = clean.replaceAll(RegExp(r'【[^】]*】'), '');
    clean = clean.replaceAll(RegExp(r'（[^）]*）'), '');

    // 3. Strip album/movie subtitle if present after hyphen or colon (e.g. "Song - Movie Name")
    if (album != null && album.trim().isNotEmpty) {
      final cleanAlbum = album.toLowerCase().trim();
      if (cleanAlbum.length >= 3) {
        clean = clean.replaceAll(RegExp(r'[\-\:\/]\s*' + RegExp.escape(cleanAlbum) + r'.*$', caseSensitive: false), '');
      }
    }

    // 4. Strip suffixes after hyphen, colon, slash, or dash:
    // e.g. "- Official Video", "- Lofi Mix", "- Remix", "- From Movie", "- Slowed & Reverb"
    clean = clean.replaceAll(
      RegExp(
        r'[\-\–\—\:\/]\s*(from\b|film\b|movie\b|soundtrack\b|ost\b|audio\b|video\b|official\b|music\s+video\b|full\s+(song|video)\b|lyric(al)?\b|lofi\b|remix\b|reprise\b|acoustic\b|unplugged\b|slowed\b|reverb\b|sped\s+up\b|speed\s+up\b|cover\b|bonus\b|edit\b|mix\b|version\b|extended\b|radio\b|club\b|dance\b|instrumental\b|karaoke\b|live\b|original\b|feat\b|ft\b|with\b).*$',
        caseSensitive: false,
      ),
      '',
    );

    // 5. Strip trailing standalone version/descriptor words even without hyphens
    // e.g. "Kesariya Lofi", "Song Remix", "Song Acoustic", "Song Slowed Reverb"
    clean = clean.replaceAll(
      RegExp(
        r'\b(lofi(\s+(flip|mix|version|edit))?|slowed(\s+(and|\&)\s+reverb)?|reverb|sped\s+up|speed\s+up|remix(ed)?|reprise|acoustic(\s+version)?|unplugged|instrumental|karaoke|extended(\s+(mix|version))?|club\s+mix|radio\s+edit|dance(\s+mix)?|original\s+mix|live(\s+(version|performance|session))?|film\s+version|female(\s+version)?|male(\s+version)?|sad(\s+version)?|8d(\s+audio)?|full\s+song|full\s+video(\s+song)?|official(\s+(video|audio|music\s+video))?|music\s+video|lyric(al)?(\s+video)?|audio(\s+song)?|video(\s+song)?|cover|bonus\s+track|edit|mix|version)\b.*$',
        caseSensitive: false,
      ),
      '',
    );

    // 6. Strip featured artists e.g. "feat. Drake", "ft Lil Baby"
    clean = clean.replaceAll(
      RegExp(r'\b(feat\.?|ft\.?|featuring|with)\s+.*$', caseSensitive: false),
      '',
    );

    // 7. Remove non-alphanumeric characters except spaces
    clean = clean.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    // 8. Collapse whitespace
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 9. If everything got stripped, fallback to basic alphanumeric of original title
    if (clean.isEmpty) {
      clean = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return clean;
  }

  /// Checks whether two tracks represent the same song (even if different versions, remixes, or releases)
  static bool areSameSong(Track a, Track b) {
    if (a.id == b.id) return true;

    final cA = canonicalTitle(a.title, album: a.album, artist: a.artist);
    final cB = canonicalTitle(b.title, album: b.album, artist: b.artist);

    if (cA.isEmpty || cB.isEmpty) return false;

    // 1. Direct exact canonical title match (e.g. "kesariya" == "kesariya")
    if (cA == cB) return true;

    // 2. One title is a prefix/variant of the other with overlapping artist
    final isPrefixMatch = (cA.length >= 4 && cB.length >= 4) &&
        (cA.startsWith('$cB ') || cB.startsWith('$cA '));

    if (isPrefixMatch) {
      final pA = extractPrimaryArtist(a.artist).toLowerCase();
      final pB = extractPrimaryArtist(b.artist).toLowerCase();
      if (pA.isNotEmpty && pB.isNotEmpty) {
        if (pA == pB || pA.contains(pB) || pB.contains(pA)) return true;
      }
    }

    return false;
  }

  /// Deduplicates a list of tracks so that no song appears multiple times
  /// (eliminating duplicate IDs, identical canonical titles, and alternate versions/remixes).
  static List<Track> deduplicateTracks(List<Track> tracks) {
    final List<Track> unique = [];
    final Set<String> seenIds = {};
    final Set<String> seenCanonical = {};

    for (final track in tracks) {
      if (seenIds.contains(track.id)) continue;

      final cTitle = canonicalTitle(track.title, album: track.album, artist: track.artist);
      if (cTitle.isNotEmpty && seenCanonical.contains(cTitle)) continue;

      // Check against already accepted tracks for prefix/variant match
      bool isDuplicate = false;
      for (final accepted in unique) {
        if (areSameSong(track, accepted)) {
          isDuplicate = true;
          break;
        }
      }
      if (isDuplicate) continue;

      seenIds.add(track.id);
      if (cTitle.isNotEmpty) seenCanonical.add(cTitle);
      unique.add(track);
    }

    return unique;
  }

  /// Robust Autoplay Recommendations Engine:
  /// NEVER loops to the same song or alternate versions of it.
  /// Ranks upcoming songs strictly by user preferences with instant local fallback!
  static Future<List<Track>> getAutoplayRecommendations(
    Track currentTrack, {
    Set<String>? excludeIds,
    Set<String>? excludeTitles,
  }) async {
    // Exclude recently played songs (last 25 tracks) so they NEVER replay in the same session
    final recentHistoryTracks = _recentlyPlayed.take(25);
    final seenIds = <String>{
      currentTrack.id,
      ...?excludeIds,
      ..._dislikedTrackIds,
      for (final t in recentHistoryTracks) t.id,
    };
    
    // Canonical title deduplication set
    final currentCanonical = canonicalTitle(currentTrack.title, album: currentTrack.album, artist: currentTrack.artist);
    final seenCanonicalTitles = <String>{
      if (currentCanonical.isNotEmpty) currentCanonical,
      if (excludeTitles != null)
        for (final t in excludeTitles)
          if (canonicalTitle(t).isNotEmpty) canonicalTitle(t),
      for (final t in recentHistoryTracks)
        if (canonicalTitle(t.title, album: t.album, artist: t.artist).isNotEmpty)
          canonicalTitle(t.title, album: t.album, artist: t.artist),
    };

    final primaryArtist = extractPrimaryArtist(currentTrack.artist);
    final preferredLangs = LanguagePreferenceService.preferredLanguages;
    final favArtists = ArtistPreferenceService.favoriteArtists;

    // Fetch candidate batches concurrently in parallel with rotated queries & dynamic pagination
    final futures = <Future<List<Track>>>[];
    final now = DateTime.now();
    final seed = now.minute + now.second;
    final int autoplayYear = now.year;

    // 1. Primary Query: Rotated templates and page offsets so top 5 don't repeat
    if (primaryArtist.isNotEmpty && !isArtistBlocked(primaryArtist)) {
      final artistTemplates = [
        '$primaryArtist popular songs',
        '$primaryArtist latest hits',
        '$primaryArtist hits',
        '$primaryArtist best songs',
        '$primaryArtist radio',
      ];
      final q1 = artistTemplates[seed % artistTemplates.length];
      final page1 = (seed % 3) + 1; // page 1, 2, or 3
      futures.add(MusicSearchService.searchSongs(q1, limit: 12, page: page1));
    }

    // 2. Co-Occurrence / Related Radio Seed
    final langStr = currentTrack.language.isNotEmpty ? currentTrack.language : '';
    final moodTemplates = [
      '$primaryArtist $langStr',
      '$primaryArtist viral hits $autoplayYear',
      '$primaryArtist acoustic',
      '$primaryArtist melodic $langStr',
    ];
    final q2 = moodTemplates[(seed + 1) % moodTemplates.length];
    final page2 = ((seed + 1) % 2) + 1;
    futures.add(MusicSearchService.searchSongs(q2, limit: 10, page: page2));

    // 3. Favorite Artists Queries with dynamic templates
    for (int i = 0; i < favArtists.take(3).length; i++) {
      final fav = favArtists[i];
      if (fav.toLowerCase() != primaryArtist.toLowerCase() && !isArtistBlocked(fav)) {
        final favTemplates = ['$fav hits', '$fav best songs', '$fav latest'];
        final qFav = favTemplates[(seed + i) % favTemplates.length];
        futures.add(MusicSearchService.searchSongs(qFav, limit: 6, page: ((seed + i) % 2) + 1));
      }
    }

    // 4. Language-targeted Query
    for (int i = 0; i < preferredLangs.take(2).length; i++) {
      final lang = preferredLangs[i];
      final langTemplates = [
        'Top $lang Songs $autoplayYear',
        'Trending $lang Hits',
        'Viral $lang $autoplayYear',
      ];
      final qLang = langTemplates[(seed + i) % langTemplates.length];
      futures.add(MusicSearchService.searchSongs(qLang, limit: 8, page: ((seed + i) % 2) + 1));
    }

    try {
      final resultsList = await Future.wait(
        futures.map((f) => f.catchError((_) => <Track>[])),
      ).timeout(const Duration(seconds: 4), onTimeout: () => []);

      for (final batch in resultsList) {
        for (final t in batch) {
          final cTitle = canonicalTitle(t.title, album: t.album, artist: t.artist);
          if (seenIds.contains(t.id)) continue;
          if (cTitle.isNotEmpty && seenCanonicalTitles.contains(cTitle)) continue;
          if (isTrackDisliked(t.id, t.title) || isArtistBlocked(t.artist)) continue;
          if (areSameSong(t, currentTrack)) continue;
          if (candidates.any((existing) => areSameSong(existing, t))) continue;

          seenIds.add(t.id);
          if (cTitle.isNotEmpty) seenCanonicalTitles.add(cTitle);
          candidates.add(t);
        }
      }
    } catch (_) {}

    // 5. Offline / Fast Local Fallback Pool from Mix Boxes if network returned empty
    if (candidates.isEmpty) {
      final fallbackPool = [..._box1Tracks, ..._box2Tracks, ..._box3Tracks, ..._recentlyPlayed];
      for (final t in fallbackPool) {
        final cTitle = canonicalTitle(t.title, album: t.album, artist: t.artist);
        if (!seenIds.contains(t.id) &&
            cTitle.isNotEmpty &&
            !seenCanonicalTitles.contains(cTitle) &&
            !areSameSong(t, currentTrack) &&
            !candidates.any((existing) => areSameSong(existing, t)) &&
            !isArtistBlocked(t.artist) &&
            !isTrackDisliked(t.id, t.title)) {
          seenIds.add(t.id);
          seenCanonicalTitles.add(cTitle);
          candidates.add(t);
        }
      }
    }

    // Filter out languages that user doesn't want (unless the artist matches favorite or current)
    final filtered = candidates.where((t) {
      if (isArtistBlocked(t.artist) || isTrackDisliked(t.id, t.title)) return false;

      final isCurrentArtist = primaryArtist.isNotEmpty &&
          t.artist.toLowerCase().contains(primaryArtist.toLowerCase());
      if (isCurrentArtist) return true;

      final isFavArtist = favArtists.any((f) => t.artist.toLowerCase().contains(f.toLowerCase()));
      if (isFavArtist) return true;

      return LanguagePreferenceService.matchesUserPreferences(t);
    }).toList();

    // 6. Rank candidate tracks by Composite Taste Score in descending order
    filtered.sort((a, b) => scoreTrack(b, currentTrack).compareTo(scoreTrack(a, currentTrack)));

    final pool = filtered.isNotEmpty ? filtered : candidates;
    if (pool.length > 1) {
      // Randomize the order among the top recommended songs so playback feels dynamic and non-repetitive
      final topPool = pool.take(15).toList()..shuffle();
      return [...topPool, ...pool.skip(15)];
    }
    return pool;
  }
}
