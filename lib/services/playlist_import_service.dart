import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'music_search_service.dart';

class RawSongItem {
  final String title;
  final String artist;

  const RawSongItem({required this.title, this.artist = ''});

  @override
  String toString() => artist.isNotEmpty ? '$title - $artist' : title;
}

class PlaylistImportResult {
  final String playlistName;
  final String coverUrl;
  final List<Track> matchedTracks;
  final List<String> unmatchedSongs;
  final int totalParsed;

  const PlaylistImportResult({
    required this.playlistName,
    this.coverUrl = '',
    required this.matchedTracks,
    required this.unmatchedSongs,
    required this.totalParsed,
  });
}

class PlaylistImportService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Main entry point: imports from Spotify/YouTube/Apple Music URL or raw text list
  static Future<PlaylistImportResult> parseAndImport(
    String input, {
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      return const PlaylistImportResult(
        playlistName: 'Empty Playlist',
        matchedTracks: [],
        unmatchedSongs: [],
        totalParsed: 0,
      );
    }

    String playlistName = 'Imported Playlist';
    String coverUrl = '';
    List<RawSongItem> rawSongs = [];

    // 1. Check if input is a Spotify Link
    if (_isSpotifyLink(cleanInput)) {
      onProgress?.call(0, 1, 'Fetching Spotify playlist data...');
      final spotifyData = await _fetchSpotifyPlaylist(cleanInput);
      playlistName = spotifyData['name'] as String? ?? 'Spotify Playlist';
      coverUrl = spotifyData['cover'] as String? ?? '';
      rawSongs = spotifyData['songs'] as List<RawSongItem>? ?? [];
    }
    // 2. Check if input is a YouTube / YouTube Music Link
    else if (_isYouTubeLink(cleanInput)) {
      onProgress?.call(0, 1, 'Fetching YouTube playlist data...');
      final ytData = await _fetchYouTubePlaylist(cleanInput);
      playlistName = ytData['name'] as String? ?? 'YouTube Playlist';
      coverUrl = ytData['cover'] as String? ?? '';
      rawSongs = ytData['songs'] as List<RawSongItem>? ?? [];
    }
    // 3. Check if input is Apple Music Link
    else if (_isAppleMusicLink(cleanInput)) {
      onProgress?.call(0, 1, 'Fetching Apple Music playlist data...');
      final appleData = await _fetchAppleMusicPlaylist(cleanInput);
      playlistName = appleData['name'] as String? ?? 'Apple Music Playlist';
      coverUrl = appleData['cover'] as String? ?? '';
      rawSongs = appleData['songs'] as List<RawSongItem>? ?? [];
    }
    // 4. Fallback: Parse multiline text / song list
    else {
      playlistName = 'My Playlist';
      rawSongs = _parseTextSongList(cleanInput);
    }

    if (rawSongs.isEmpty) {
      // If parsing failed to extract tracks, treat as plain text search lines
      rawSongs = _parseTextSongList(cleanInput);
    }

    final total = rawSongs.length;
    final List<Track> matchedTracks = [];
    final List<String> unmatched = [];

    for (int i = 0; i < rawSongs.length; i++) {
      final item = rawSongs[i];
      onProgress?.call(i + 1, total, 'Matching "${item.title}"...');

      Track? resolved = await _resolveTrack(item);
      if (resolved != null) {
        matchedTracks.add(resolved);
      } else {
        unmatched.add(item.toString());
      }

      // Small throttling delay to avoid rate limiting
      if (i % 4 == 0) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    return PlaylistImportResult(
      playlistName: playlistName,
      coverUrl: coverUrl,
      matchedTracks: matchedTracks,
      unmatchedSongs: unmatched,
      totalParsed: total,
    );
  }

  static bool _isSpotifyLink(String url) {
    return url.contains('spotify.com') || url.contains('spotify.link');
  }

  static bool _isYouTubeLink(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  static bool _isAppleMusicLink(String url) {
    return url.contains('music.apple.com');
  }

  /// Fetches playlist information & track names from public Spotify URL
  static Future<Map<String, dynamic>> _fetchSpotifyPlaylist(String url) async {
    String name = 'Spotify Playlist';
    String cover = '';
    final List<RawSongItem> songs = [];

    try {
      // Step A: Extract ID and Type (playlist or album)
      final uri = Uri.parse(url);
      String id = '';
      bool isAlbum = url.contains('/album/');

      final segments = uri.pathSegments;
      final typeIndex = segments.indexWhere((s) => s == 'playlist' || s == 'album');
      if (typeIndex >= 0 && typeIndex + 1 < segments.length) {
        id = segments[typeIndex + 1];
      }

      if (id.isEmpty) {
        // Handle short URLs by following redirect
        final headRes = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
        final finalUrl = headRes.request?.url.toString() ?? url;
        final finalUri = Uri.parse(finalUrl);
        final finalSegments = finalUri.pathSegments;
        final fTypeIndex = finalSegments.indexWhere((s) => s == 'playlist' || s == 'album');
        if (fTypeIndex >= 0 && fTypeIndex + 1 < finalSegments.length) {
          id = finalSegments[fTypeIndex + 1];
          isAlbum = finalUrl.contains('/album/');
        }
      }

      // Step B: Use oEmbed to grab playlist title and author
      try {
        final oembedUrl = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}');
        final oembedRes = await http.get(oembedUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (oembedRes.statusCode == 200) {
          final data = jsonDecode(oembedRes.body) as Map<String, dynamic>;
          name = data['title'] as String? ?? name;
          cover = data['thumbnail_url'] as String? ?? '';
        }
      } catch (_) {}

      // Step C: Fetch Spotify Embed Page to extract songs without requiring Spotify API keys
      if (id.isNotEmpty) {
        final embedUrl = Uri.parse(
          isAlbum ? 'https://open.spotify.com/embed/album/$id' : 'https://open.spotify.com/embed/playlist/$id',
        );
        final embedRes = await http.get(embedUrl, headers: _headers).timeout(const Duration(seconds: 6));

        if (embedRes.statusCode == 200) {
          final html = embedRes.body;

          // Attempt 1: Parse __NEXT_DATA__
          final scriptMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', dotAll: true)
              .firstMatch(html);
          if (scriptMatch != null) {
            try {
              final jsonStr = scriptMatch.group(1);
              if (jsonStr != null) {
                final nextData = jsonDecode(jsonStr) as Map<String, dynamic>;
                final props = nextData['props']?['pageProps']?['state']?['data'];
                if (props != null) {
                  final entity = props['entity'] ?? props['playlist'] ?? props['album'];
                  if (entity != null) {
                    name = entity['name'] ?? entity['title'] ?? name;
                    final trackList = entity['trackList'] as List? ??
                        entity['tracks']?['items'] as List? ??
                        props['trackList'] as List?;
                    if (trackList != null) {
                      for (final t in trackList) {
                        final title = t['title'] ?? t['name'] ?? '';
                        String artist = '';
                        if (t['subtitle'] != null) {
                          artist = t['subtitle'].toString();
                        } else if (t['artists'] != null && t['artists'] is List) {
                          artist = (t['artists'] as List).map((a) => a['name'] ?? '').join(', ');
                        }
                        if (title.isNotEmpty) {
                          songs.add(RawSongItem(title: title.toString(), artist: artist));
                        }
                      }
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Spotify __NEXT_DATA__ parse error: $e');
            }
          }

          // Attempt 2: Regex extraction from embed HTML if JSON wasn't present
          if (songs.isEmpty) {
            final trackMatches = RegExp(r'"name":"([^"]+)".*?"artists":\[\{"name":"([^"]+)"', dotAll: true)
                .allMatches(html);
            for (final m in trackMatches) {
              final title = m.group(1)?.trim();
              final artist = m.group(2)?.trim() ?? '';
              if (title != null && title.isNotEmpty && !songs.any((s) => s.title == title)) {
                songs.add(RawSongItem(title: title, artist: artist));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify scrape error: $e');
    }

    return {'name': name, 'cover': cover, 'songs': songs};
  }

  /// Fetches playlist information from YouTube public playlist
  static Future<Map<String, dynamic>> _fetchYouTubePlaylist(String url) async {
    String name = 'YouTube Playlist';
    String cover = '';
    final List<RawSongItem> songs = [];

    try {
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final html = res.body;

        // Title
        final titleMatch = RegExp(r'<title>(.*?)<\/title>').firstMatch(html);
        if (titleMatch != null) {
          name = titleMatch.group(1)?.replaceAll('- YouTube', '').trim() ?? name;
        }

        // Extract video titles
        final titleRegex = RegExp(r'"title":\{"runs":\[\{"text":"([^"]+)"\}\]');
        final matches = titleRegex.allMatches(html);
        for (final m in matches) {
          final title = m.group(1)?.trim();
          if (title != null && title.isNotEmpty && title != 'Watch later' && title != 'Liked videos') {
            final parsed = _parseSingleTitle(title);
            if (!songs.any((s) => s.title == parsed.title)) {
              songs.add(parsed);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('YouTube scrape error: $e');
    }

    return {'name': name, 'cover': cover, 'songs': songs};
  }

  /// Fetches Apple Music playlist information
  static Future<Map<String, dynamic>> _fetchAppleMusicPlaylist(String url) async {
    String name = 'Apple Music Playlist';
    final List<RawSongItem> songs = [];

    try {
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final html = res.body;
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
        if (titleMatch != null) {
          name = titleMatch.group(1)?.trim() ?? name;
        }

        final trackMatches = RegExp(r'class="songs-list-row__song-name[^"]*">([^<]+)<.*?class="songs-list-row__link">([^<]+)<', dotAll: true)
            .allMatches(html);
        for (final m in trackMatches) {
          final title = m.group(1)?.trim() ?? '';
          final artist = m.group(2)?.trim() ?? '';
          if (title.isNotEmpty) {
            songs.add(RawSongItem(title: title, artist: artist));
          }
        }
      }
    } catch (_) {}

    return {'name': name, 'cover': '', 'songs': songs};
  }

  /// Parses multiline song text (e.g. copied from Spotify, Apple Music, or text notes)
  static List<RawSongItem> _parseTextSongList(String text) {
    final List<RawSongItem> items = [];
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Remove leading track numbers like "1. ", "01 - ", "[1] "
      line = line.replaceFirst(RegExp(r'^(\d+[\.\-\)]\s*|\[\d+\]\s*)'), '').trim();
      if (line.isEmpty) continue;

      items.add(_parseSingleTitle(line));
    }

    return items;
  }

  static RawSongItem _parseSingleTitle(String raw) {
    // If format is "Title - Artist" or "Artist - Title"
    if (raw.contains(' - ')) {
      final parts = raw.split(' - ');
      return RawSongItem(title: parts[0].trim(), artist: parts.length > 1 ? parts[1].trim() : '');
    }
    // If format is "Title by Artist"
    if (raw.contains(' by ')) {
      final parts = raw.split(' by ');
      return RawSongItem(title: parts[0].trim(), artist: parts.length > 1 ? parts[1].trim() : '');
    }
    // If format is "Title | Artist"
    if (raw.contains(' | ')) {
      final parts = raw.split(' | ');
      return RawSongItem(title: parts[0].trim(), artist: parts.length > 1 ? parts[1].trim() : '');
    }
    return RawSongItem(title: raw);
  }

  /// Resolves a single parsed song into a Decibel 320kbps Track
  static Future<Track?> _resolveTrack(RawSongItem item) async {
    try {
      final query = item.artist.isNotEmpty ? '${item.title} ${item.artist}' : item.title;
      var results = await MusicSearchService.searchSongs(query, limit: 3);

      if (results.isEmpty && item.artist.isNotEmpty) {
        // Fallback to title only if combined query gave no results
        results = await MusicSearchService.searchSongs(item.title, limit: 3);
      }

      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (_) {}
    return null;
  }
}
