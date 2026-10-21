import '../models/track.dart';
import 'providers/music_provider_registry.dart';

/// Service for catalog search and trending track discovery.
/// 
/// Queries are routed through the active [MusicProvider] configured in
/// [MusicProviderRegistry]. Decibel ships with standard public catalog support
/// and can be extended with any licensed audio source.
class MusicSearchService {
  MusicSearchService._();

  /// Searches tracks using the active music provider.
  /// Supports dynamic page offset so queries return fresh songs instead of the same top results.
  static Future<List<Track>> searchSongs(String query, {int limit = 40, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    try {
      final provider = MusicProviderRegistry.current;
      return await provider.searchTracks(query, limit: limit, page: page);
    } catch (_) {
      return [];
    }
  }

  /// Searches and aggregates trending tracks for each of the user's preferred languages.
  /// Rotates queries dynamically based on the day of the year so the picks update daily!
  static Future<List<Track>> searchTrendingByLanguages(
    List<String> languages, {
    int limitPerLang = 20,
    List<String>? favoriteArtists,
  }) async {
    final List<Track> aggregated = [];
    final Set<String> seenIds = {};
    final Set<String> seenTitles = {};

    final now = DateTime.now();
    final currentYear = now.year;
    final dayOfYear = now.difference(DateTime(currentYear, 1, 1)).inDays;
    // Dynamic seed that rotates every 30 minutes so picks refresh dynamically throughout the day
    final timeSeed = (now.hour * 2) + (now.minute >= 30 ? 1 : 0);

    // Dynamic rotation query pools that change each day and time period
    final languageQueryTemplates = [
      'Top {lang} Hits $currentYear',
      'Trending {lang} Songs',
      'Latest {lang} Hits $currentYear',
      '{lang} Viral 50',
      'Best of {lang} $currentYear',
      '{lang} Top Chartbusters',
      '{lang} Radio Hits',
    ];

    final artistQueryTemplates = [
      '{artist} hits',
      '{artist} top songs',
      '{artist} latest songs',
      '{artist} popular songs',
      '{artist} best hits',
    ];

    // 1. Fetch rotating songs for favorite artists
    if (favoriteArtists != null && favoriteArtists.isNotEmpty) {
      for (int i = 0; i < favoriteArtists.take(5).length; i++) {
        final artist = favoriteArtists[i];
        final queryTemplate = artistQueryTemplates[(dayOfYear + timeSeed + i) % artistQueryTemplates.length];
        final query = queryTemplate.replaceAll('{artist}', artist);
        final page = ((timeSeed + i) % 2) + 1; // rotate page 1 and 2
        try {
          final artistTracks = await searchSongs(query, limit: 12, page: page);
          // Pick a rotating window based on the time seed
          final offset = ((timeSeed + i) % 3) * 2;
          final picked = artistTracks.skip(offset).take(6);
          for (final t in (picked.isNotEmpty ? picked : artistTracks.take(6))) {
            final normalizedTitle = '${t.title.toLowerCase()} ${t.artist.toLowerCase()}';
            if (!seenIds.contains(t.id) && !seenTitles.contains(normalizedTitle)) {
              seenIds.add(t.id);
              seenTitles.add(normalizedTitle);
              aggregated.add(t);
            }
          }
        } catch (_) {}
      }
    }

    // 2. Fetch language trending tracks with time-based rotated queries & pages
    if (languages.isNotEmpty) {
      for (int i = 0; i < languages.length; i++) {
        final lang = languages[i];
        final queryTemplate = languageQueryTemplates[(dayOfYear + timeSeed + i) % languageQueryTemplates.length];
        final query = queryTemplate.replaceAll('{lang}', lang);
        final page = ((timeSeed + i) % 2) + 1;
        try {
          final tracks = await searchSongs(query, limit: limitPerLang, page: page);
          for (final t in tracks) {
            final normalizedTitle = '${t.title.toLowerCase()} ${t.artist.toLowerCase()}';
            if (!seenIds.contains(t.id) && !seenTitles.contains(normalizedTitle)) {
              seenIds.add(t.id);
              seenTitles.add(normalizedTitle);
              aggregated.add(t.language.isEmpty ? t.copyWith(language: lang) : t);
            }
          }
        } catch (_) {}
      }
    } else {
      final query = languageQueryTemplates[(dayOfYear + timeSeed) % languageQueryTemplates.length].replaceAll('{lang}', 'Trending');
      final defaultTracks = await searchSongs(query, limit: 40, page: (timeSeed % 2) + 1);
      for (final t in defaultTracks) {
        final normalizedTitle = '${t.title.toLowerCase()} ${t.artist.toLowerCase()}';
        if (!seenIds.contains(t.id) && !seenTitles.contains(normalizedTitle)) {
          seenIds.add(t.id);
          seenTitles.add(normalizedTitle);
          aggregated.add(t);
        }
      }
    }

    if (aggregated.isEmpty) {
      return searchSongs('Top Hits', limit: 40);
    }

    // Weight sorting: songs matching user's favorite artists bubble to the top,
    // while blending with fresh language tracks for the day
    if (favoriteArtists != null && favoriteArtists.isNotEmpty) {
      final favLower = favoriteArtists.map((a) => a.toLowerCase().trim()).toSet();
      aggregated.sort((a, b) {
        final aMatches = favLower.any((fa) => a.artist.toLowerCase().contains(fa));
        final bMatches = favLower.any((fa) => b.artist.toLowerCase().contains(fa));
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        return 0;
      });
    } else if (languages.length > 1) {
      aggregated.shuffle();
    }

    return aggregated;
  }
}
