import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lyrics_line.dart';
import '../models/track.dart';

class LyricsService {
  static final Map<String, List<LyricsLine>> _lyricsCache = {};

  static Future<List<LyricsLine>> fetchLyrics(Track track) async {
    final cacheKey = '${track.artist} - ${track.title}'.toLowerCase().trim();
    if (_lyricsCache.containsKey(cacheKey)) {
      return _lyricsCache[cacheKey]!;
    }

    final cleanTitle = track.title.replaceAll(RegExp(r'\(.*?\)|\z.*?\]'), '').trim();
    final cleanArtist = track.artist.split(',').first.split('&').first.trim();

    // 1. Query LRCLIB for synced timestamps
    try {
      final endpoint = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(cleanArtist)}',
      );
      final response = await http.get(
        endpoint,
        headers: {'User-Agent': 'DECIBEL-Music-App/1.0.0'},
      ).timeout(const Duration(milliseconds: 4000));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final syncedLyrics = json['syncedLyrics']?.toString();
        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          final parsed = parseLrc(syncedLyrics);
          if (parsed.isNotEmpty) {
            _lyricsCache[cacheKey] = parsed;
            return parsed;
          }
        }

        final plainLyrics = json['plainLyrics']?.toString();
        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          final pseudo = _createPseudoTimings(plainLyrics);
          if (pseudo.isNotEmpty) {
            _lyricsCache[cacheKey] = pseudo;
            return pseudo;
          }
        }
      }
    } catch (_) {}

    return [];
  }

  static List<LyricsLine> parseLrc(String lrcText) {
    final List<LyricsLine> lines = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final line in lrcText.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        final ms = msStr.length == 2 ? int.parse(msStr) * 10 : int.parse(msStr);
        final totalMs = (min * 60 * 1000) + (sec * 1000) + ms;
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricsLine(timeMs: totalMs, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return lines;
  }

  static List<LyricsLine> _createPseudoTimings(String plainLyrics) {
    final lines = plainLyrics
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    const intervalMs = 5000;
    return List.generate(
      lines.length,
      (i) => LyricsLine(timeMs: i * intervalMs, text: lines[i]),
    );
  }
}
