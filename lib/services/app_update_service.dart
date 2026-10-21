import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// In-app update checker for sideloaded (non-Play Store) APK distribution.
///
/// Fetches a lightweight version manifest JSON from a public URL (e.g. GitHub Releases)
/// and prompts the user to download the latest APK if a newer build is available.
///
/// HOST a `version.json` file at [_versionManifestUrl] with this structure:
/// ```json
/// {
///   "version": "1.1.0",
///   "build": 2,
///   "download_url": "https://github.com/yourname/decibel/releases/download/v1.1.0/decibel.apk",
///   "release_notes": "Bug fixes and performance improvements"
/// }
/// ```
class AppUpdateService {
  /// The URL where your version.json is hosted.
  /// Replace this with your actual GitHub Releases or hosting URL.
  static const String _versionManifestUrl =
      'https://raw.githubusercontent.com/YOUR_USERNAME/decibel/main/version.json';

  /// The app's current build number — must match pubspec.yaml version build number.
  /// Update this every time you release a new APK.
  static const int currentBuildNumber = 1;
  static const String currentVersion = '1.0.0';

  static const String _keySkippedBuild = 'decibel_skipped_update_build';
  static const String _keyLastChecked = 'decibel_update_last_checked_ms';
  static const Duration _checkInterval = Duration(hours: 12);

  static UpdateInfo? _cachedInfo;

  /// Checks for updates. Returns [UpdateInfo] if an update is available, null otherwise.
  /// Throttled to once per [_checkInterval] to avoid hammering the server.
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastChecked = prefs.getInt(_keyLastChecked) ?? 0;

      // Throttle: only check every 12 hours unless forced
      if (!force && (now - lastChecked) < _checkInterval.inMilliseconds) {
        return null;
      }

      await prefs.setInt(_keyLastChecked, now);

      final response = await http
          .get(Uri.parse(_versionManifestUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = (data['build'] as num?)?.toInt() ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final downloadUrl = data['download_url'] as String? ?? '';
      final releaseNotes = data['release_notes'] as String? ?? '';

      // No update needed
      if (remoteBuild <= currentBuildNumber) return null;

      // User already chose to skip this specific build
      final skippedBuild = prefs.getInt(_keySkippedBuild) ?? 0;
      if (skippedBuild >= remoteBuild) return null;

      _cachedInfo = UpdateInfo(
        version: remoteVersion,
        build: remoteBuild,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
      );
      return _cachedInfo;
    } catch (e) {
      debugPrint('AppUpdateService: update check failed: $e');
      return null;
    }
  }

  /// Marks the given build number as "skipped" — won't prompt again for this version.
  static Future<void> skipBuild(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySkippedBuild, build);
  }
}

class UpdateInfo {
  final String version;
  final int build;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Shows the update dialog. Call this from the splash/home screen after checking.
class AppUpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onDownload;
  final VoidCallback onSkip;

  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.onDownload,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1C2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF885FEE), Color(0xFFA483F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFFF5F4FA),
                        ),
                      ),
                      Text(
                        'Version ${info.version} is ready',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          color: Color(0xFFA19EAF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "What's new",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF9E7FFF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.releaseNotes,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: Color(0xFFA19EAF),
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFA19EAF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF885FEE), Color(0xFFA483F1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF885FEE).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded,
                            size: 18, color: Colors.white),
                        label: const Text(
                          'Download Update',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
