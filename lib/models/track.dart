import 'lyrics_line.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String artworkUrl;
  final String streamUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final List<LyricsLine> lyrics;
  final String language;
  final String? localFilePath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.artworkUrl,
    required this.streamUrl,
    this.primaryColorHex = '#1DB954',
    this.secondaryColorHex = '#121212',
    this.lyrics = const [],
    this.language = '',
    this.localFilePath,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artworkUrl,
    String? streamUrl,
    String? primaryColorHex,
    String? secondaryColorHex,
    List<LyricsLine>? lyrics,
    String? language,
    String? localFilePath,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      lyrics: lyrics ?? this.lyrics,
      language: language ?? this.language,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'artworkUrl': artworkUrl,
    'streamUrl': streamUrl,
    'primaryColorHex': primaryColorHex,
    'secondaryColorHex': secondaryColorHex,
    'lyrics': lyrics.map((l) => l.toJson()).toList(),
    'language': language,
    'localFilePath': localFilePath,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Unknown Title',
    artist: json['artist'] as String? ?? 'Unknown Artist',
    album: json['album'] as String? ?? 'Single',
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 180000,
    artworkUrl: json['artworkUrl'] as String? ?? '',
    streamUrl: json['streamUrl'] as String? ?? '',
    primaryColorHex: json['primaryColorHex'] as String? ?? '#1DB954',
    secondaryColorHex: json['secondaryColorHex'] as String? ?? '#121212',
    lyrics: (json['lyrics'] as List<dynamic>?)
            ?.map((e) => LyricsLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    language: json['language'] as String? ?? '',
    localFilePath: json['localFilePath'] as String?,
  );
}
