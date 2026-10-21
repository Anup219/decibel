import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'full_song_stream_resolver.dart';

class DownloadService {
  static const String _folderName = 'decibel_downloads';

  /// Returns the local directory path where offline songs are saved
  static Future<Directory> getDownloadsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(docsDir.path, _folderName));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Sanitizes track ID for safe local filename
  static String _safeFileName(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Returns the expected local audio file path for a track ID
  static Future<String> getAudioFilePath(String trackId) async {
    final dir = await getDownloadsDirectory();
    return p.join(dir.path, '${_safeFileName(trackId)}.m4a');
  }

  /// Returns the expected local artwork file path for a track ID
  static Future<String> getArtworkFilePath(String trackId) async {
    final dir = await getDownloadsDirectory();
    return p.join(dir.path, '${_safeFileName(trackId)}_art.jpg');
  }

  /// Checks if a track's audio file actually exists on device storage with valid size
  static Future<bool> isTrackDownloaded(String trackId) async {
    try {
      final path = await getAudioFilePath(trackId);
      final file = File(path);
      if (await file.exists()) {
        final length = await file.length();
        // Valid audio file should be larger than 50KB
        return length > 50 * 1024;
      }
    } catch (_) {}
    return false;
  }

  /// Synchronously or quickly checks if a given file path exists and is valid
  static bool isLocalFileValid(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      return file.existsSync() && file.lengthSync() > 50 * 1024;
    } catch (_) {
      return false;
    }
  }

  /// Downloads high-quality 320kbps audio bytes and artwork to device storage
  static Future<Track?> downloadTrack(
    Track track, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await getDownloadsDirectory();
      final audioPath = p.join(dir.path, '${_safeFileName(track.id)}.m4a');
      final tempAudioPath = '$audioPath.tmp';
      final artworkPath = p.join(dir.path, '${_safeFileName(track.id)}_art.jpg');

      // 1. Resolve full 320kbps stream URL if not already a direct commercial link
      String streamUrl = track.streamUrl;
      final isPreview = streamUrl.isEmpty ||
          streamUrl.contains('itunes.apple.com') ||
          streamUrl.contains('preview');

      if (isPreview) {
        debugPrint('Resolving full 320kbps stream for download: ${track.title}...');
        final resolved = await FullSongStreamResolver.resolveFullAudioStream(
          track.title,
          track.artist,
        );
        if (resolved != null && resolved.isNotEmpty) {
          streamUrl = resolved;
        }
      }

      if (streamUrl.isEmpty) {
        debugPrint('Download error: Unable to resolve stream URL for "${track.title}"');
        return null;
      }

      // 2. Stream audio bytes from resolved mirror into temporary file
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(streamUrl));
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

        final response = await client.send(request);
        if (response.statusCode != 200 && response.statusCode != 206) {
          debugPrint('Download failed with HTTP ${response.statusCode}');
          return null;
        }

        final contentLength = response.contentLength ?? 0;
        final tempFile = File(tempAudioPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final sink = tempFile.openWrite();
        int receivedBytes = 0;

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            onProgress(receivedBytes / contentLength);
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        // Verify valid file size
        final finalSize = await tempFile.length();
        if (finalSize < 50 * 1024) {
          debugPrint('Downloaded file was too small ($finalSize bytes)');
          if (await tempFile.exists()) await tempFile.delete();
          return null;
        }

        // Rename temp file to permanent .m4a
        final finalFile = File(audioPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(audioPath);
      } finally {
        client.close();
      }

      // 3. Cache artwork locally for offline display
      String localArtwork = track.artworkUrl;
      if (track.artworkUrl.isNotEmpty && track.artworkUrl.startsWith('http')) {
        try {
          final artResp = await http
              .get(Uri.parse(track.artworkUrl))
              .timeout(const Duration(seconds: 6));
          if (artResp.statusCode == 200 && artResp.bodyBytes.length > 500) {
            final artFile = File(artworkPath);
            await artFile.writeAsBytes(artResp.bodyBytes);
            localArtwork = artworkPath;
          }
        } catch (_) {}
      }

      debugPrint('Song successfully downloaded to: $audioPath');

      return track.copyWith(
        localFilePath: audioPath,
        artworkUrl: localArtwork,
        streamUrl: audioPath,
      );
    } catch (e) {
      debugPrint('Error downloading song: $e');
      return null;
    }
  }

  /// Deletes downloaded audio and artwork files from disk
  static Future<void> deleteDownloadedTrack(String trackId) async {
    try {
      final audioPath = await getAudioFilePath(trackId);
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      final artPath = await getArtworkFilePath(trackId);
      final artFile = File(artPath);
      if (await artFile.exists()) {
        await artFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  /// Returns size in bytes of a downloaded track
  static Future<int> getDownloadedTrackSize(String trackId) async {
    try {
      final path = await getAudioFilePath(trackId);
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Calculates total size of all downloads in bytes
  static Future<int> getTotalDownloadsSizeBytes() async {
    try {
      final dir = await getDownloadsDirectory();
      int total = 0;
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
