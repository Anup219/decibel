import '../../models/track.dart';
import '../artist_preference_service.dart';

/// Pluggable interface for music catalog, search, and stream resolution.
/// 
/// Decibel does not ship with proprietary or unlicensed audio streaming extractors.
/// Integrate your own licensed provider (e.g. Spotify Web API, Apple MusicKit,
/// Jamendo, Subsonic, or personal media server) by implementing this interface.
abstract class MusicProvider {
  String get name;

  /// Search catalog tracks matching the query
  Future<List<Track>> searchTracks(String query, {int limit = 40, int page = 1});

  /// Resolve full audio stream URL for playback
  Future<String?> resolveStreamUrl(String title, String artist);

  /// Search artists in the catalog
  Future<List<ArtistInfo>> searchArtists(String query) async => const [];
}
