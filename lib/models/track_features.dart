import 'dart:convert';
import 'track.dart';

class TrackFeatures {
  final String trackKey;
  final String artistPrimary;
  final List<String> artistsAll;
  final String? language;
  final String? genre;
  final String? mood;
  final String? era;
  final double tagConfidence;
  final String provider;
  final String providerTrackId;
  final int schemaVersion;

  const TrackFeatures({
    required this.trackKey,
    required this.artistPrimary,
    this.artistsAll = const [],
    this.language,
    this.genre,
    this.mood,
    this.era,
    this.tagConfidence = 1.0,
    this.provider = 'youtube',
    required this.providerTrackId,
    this.schemaVersion = 1,
  });

  /// Factory creating a normalized TrackFeatures instance from a runtime Track
  factory TrackFeatures.fromTrack(
    Track track, {
    String? language,
    String? genre,
    String? mood,
    String? era,
    double tagConfidence = 0.8,
  }) {
    final cleanArtist = track.artist.trim();
    // Split combined artist strings if present (e.g. "Artist1, Artist2 & Artist3")
    final splitArtists = cleanArtist
        .split(RegExp(r'[,&/]|\bfeat\.?\b|\bft\.?\b', caseSensitive: false))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    final primary = splitArtists.isNotEmpty ? splitArtists.first : (cleanArtist.isNotEmpty ? cleanArtist : 'Unknown Artist');
    final all = splitArtists.isNotEmpty ? splitArtists : [primary];

    // Build canonical provider-neutral track key: "artist_slug:title_slug"
    final artistSlug = _slugify(primary);
    final titleSlug = _slugify(track.title);
    final canonicalKey = '${artistSlug}_$titleSlug';

    final effectiveLang = (language != null && language.isNotEmpty)
        ? language
        : (track.language.isNotEmpty ? track.language : null);

    return TrackFeatures(
      trackKey: canonicalKey.isNotEmpty ? canonicalKey : track.id,
      artistPrimary: primary,
      artistsAll: all,
      language: effectiveLang,
      genre: genre,
      mood: mood,
      era: era,
      tagConfidence: tagConfidence,
      provider: 'youtube',
      providerTrackId: track.id,
      schemaVersion: 1,
    );
  }

  static String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '') // remove parentheticals
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')          // replace non-alphanumeric with underscore
        .replaceAll(RegExp(r'^_+|_+$'), '');             // trim underscores
  }

  /// Format for SQLite tracks table
  Map<String, Object?> toRow() => {
    'track_key': trackKey,
    'artist_primary': artistPrimary,
    'artists_all': jsonEncode(artistsAll),
    'language': language,
    'genre': genre,
    'mood': mood,
    'era': era,
    'tag_confidence': tagConfidence,
    'provider': provider,
    'provider_track_id': providerTrackId,
    'schema_version': schemaVersion,
    'synced': 0,
  };

  /// Format for Supabase tracks table upsert
  Map<String, dynamic> toRemote() => {
    'track_key': trackKey,
    'artist_primary': artistPrimary,
    'artists_all': artistsAll,
    'language': language,
    'genre': genre,
    'mood': mood,
    'era': era,
    'tag_confidence': tagConfidence,
    'provider': provider,
    'provider_track_id': providerTrackId,
    'schema_version': schemaVersion,
  };
}
