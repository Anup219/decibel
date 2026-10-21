import 'providers/music_provider_registry.dart';

/// Stream resolver for commercial audio tracks.
/// 
/// Uses the configured [MusicProvider] (via [MusicProviderRegistry]) to locate
/// and resolve high-quality audio streams, with an in-memory bounded cache.
class FullSongStreamResolver {
  FullSongStreamResolver._();

  // In-memory bounded cache (< 1ms repeat plays, max 200 items)
  static final Map<String, String> _streamCache = {};
  static const int _maxCacheSize = 200;

  /// Resolves an audio stream URL using the active pluggable provider
  static Future<String?> resolveFullAudioStream(String title, String artist) async {
    final cacheKey = '$artist - $title'.toLowerCase().trim();
    if (_streamCache.containsKey(cacheKey)) {
      return _streamCache[cacheKey];
    }

    try {
      final provider = MusicProviderRegistry.current;
      final url = await provider.resolveStreamUrl(title, artist);
      if (url != null && url.isNotEmpty) {
        _putCache(cacheKey, url);
        return url;
      }
    } catch (_) {}

    return null;
  }

  static void _putCache(String key, String url) {
    if (_streamCache.length >= _maxCacheSize) {
      _streamCache.remove(_streamCache.keys.first);
    }
    _streamCache[key] = url;
  }

  static void clearCache() {
    _streamCache.clear();
  }
}
