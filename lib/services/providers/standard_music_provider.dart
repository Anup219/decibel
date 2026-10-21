import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/track.dart';
import '../artist_preference_service.dart';
import 'music_provider.dart';

/// Standard, open-source compliant music catalog provider.
/// 
/// Uses public preview and metadata search APIs (iTunes Search API)
/// without requiring scrapers, proprietary decryption, or unlicensed mirrors.
class StandardMusicProvider implements MusicProvider {
  @override
  String get name => 'Standard Public Catalog';

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 40, int page = 1}) async {
    if (query.trim().isEmpty) return [];

    final safePage = page < 1 ? 1 : page;
    final offset = (safePage - 1) * limit;
    final encodedQuery = Uri.encodeComponent(query.trim());

    try {
      final endpoint = Uri.parse(
        'https://itunes.apple.com/search?term=$encodedQuery&entity=song&limit=$limit&offset=$offset',
      );
      final response = await http.get(endpoint).timeout(const Duration(milliseconds: 5000));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final List<Track> tracks = [];
          for (final item in results) {
            if (item is! Map<String, dynamic>) continue;
            final trackName = item['trackName'] as String?;
            final artistName = item['artistName'] as String?;
            final previewUrl = item['previewUrl'] as String?;
            if (trackName == null || artistName == null || previewUrl == null) continue;

            final artwork = (item['artworkUrl100'] as String? ?? '')
                .replaceAll('100x100bb', '600x600bb');
            final trackId = item['trackId']?.toString() ??
                'itunes_${artistName}_$trackName'.hashCode.abs().toString();
            final durationMs = (item['trackTimeMillis'] as num?)?.toInt() ?? 30000;

            tracks.add(Track(
              id: trackId,
              title: trackName,
              artist: artistName,
              album: item['collectionName'] as String? ?? 'Single',
              artworkUrl: artwork,
              streamUrl: previewUrl,
              duration: Duration(milliseconds: durationMs),
              origin: 'itunes',
            ));
          }
          return tracks;
        }
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<String?> resolveStreamUrl(String title, String artist) async {
    final results = await searchTracks('$title $artist', limit: 1);
    if (results.isNotEmpty && results.first.streamUrl.isNotEmpty) {
      return results.first.streamUrl;
    }
    return null;
  }

  @override
  Future<List<ArtistInfo>> searchArtists(String query) async {
    // Standard provider delegates artist resolution to public metadata services
    return const [];
  }
}
