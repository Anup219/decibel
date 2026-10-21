import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/artist_preference_service.dart';
import '../services/event_uploader.dart';
import '../services/language_preference_service.dart';
import '../theme/decibel_colors.dart';

class ConsentDialog extends StatefulWidget {
  final VoidCallback? onConsentComplete;

  const ConsentDialog({super.key, this.onConsentComplete});

  /// Static helper to check and present dialog if consent has not yet been requested
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final consentSet = prefs.containsKey('consent_given');
    if (!consentSet && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const ConsentDialog(),
      );
    }
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _isSubmitting = false;

  Future<void> _handleConsent(bool agreed) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (agreed) {
        String deviceModel = 'Unknown Device';
        String osVersion = 'Unknown OS';

        try {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final android = await deviceInfo.androidInfo;
            deviceModel = '${android.manufacturer} ${android.model}'.trim();
            osVersion = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
          } else if (Platform.isIOS) {
            final ios = await deviceInfo.iosInfo;
            deviceModel = ios.utsname.machine;
            osVersion = 'iOS ${ios.systemVersion}';
          }
        } catch (_) {}

        // Read actual app version from pubspec at runtime
        String appVersion = '1.0.0';
        try {
          final info = await PackageInfo.fromPlatform();
          appVersion = '${info.version}+${info.buildNumber}';
        } catch (_) {}

        // Record consent locally and to remote with 3-second safeguard
        await EventUploader.recordConsent(
          languages: LanguagePreferenceService.preferredLanguages,
          favArtists: ArtistPreferenceService.favoriteArtists,
          appVersion: appVersion,
          deviceModel: deviceModel,
          osVersion: osVersion,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      } else {
        await prefs.setBool('consent_given', false);
      }
    } catch (_) {
      // In case of any unexpected exception, ensure consent flag is written
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('consent_given', agreed);
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onConsentComplete?.call();
      }
    }
  }

  bool _showTechDetails = false;

  @override
  Widget build(BuildContext context) {
    final isDark = DecibelColors.isDark;
    final surfaceColor = DecibelColors.surface;
    final textColor = DecibelColors.textPrimary;
    final secondaryTextColor = DecibelColors.textSecondary;
    final cardBgColor = isDark ? const Color(0xFF1B192A) : const Color(0xFFF2EFFB);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DecibelColors.purple.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.6 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: DecibelColors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined, color: DecibelColors.purple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy & Anonymous Telemetry',
                        style: TextStyle(
                          fontFamily: DecibelTypography.headingFont,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recommendation Engine Training',
                        style: TextStyle(
                          fontFamily: DecibelTypography.bodyFont,
                          fontSize: 11,
                          color: DecibelColors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DECIBEL uses anonymous listening interactions to train recommendation models without user tracking or advertising.',
                      style: TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        fontSize: 12.5,
                        height: 1.45,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 1: Collected data
                    _buildSectionCard(
                      icon: Icons.check_circle_outline,
                      iconColor: isDark ? const Color(0xFF4DBB99) : const Color(0xFF1E8E68),
                      title: 'Data Collected (Anonymous)',
                      bgColor: cardBgColor,
                      borderColor: borderColor,
                      items: [
                        'Playback Actions: Song duration listened, completion status, skips, and favorites.',
                        'Playback Origin: Source category (Search, Recommended Mixes, or Radio).',
                        'Music Preferences: Selected language preferences and favorite artist tags.',
                        'App Reliability: Device model and operating system version for audio engine stability.',
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Section 2: Excluded data
                    _buildSectionCard(
                      icon: Icons.cancel_outlined,
                      iconColor: isDark ? const Color(0xFFEA88A8) : const Color(0xFFD32F2F),
                      title: 'Data Never Collected',
                      bgColor: cardBgColor,
                      borderColor: borderColor,
                      items: [
                        'Identity: No names, emails, phone numbers, or account credentials.',
                        'Search Terms: Raw search query text is never transmitted or recorded.',
                        'Microphone & Audio: No audio recordings or ambient sound capture.',
                        'Location & Files: No GPS coordinates, device files, or contacts access.',
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Section 3: Deletion rights
                    _buildSectionCard(
                      icon: Icons.lock_outline,
                      iconColor: DecibelColors.purple,
                      title: 'Data Control & Deletion',
                      bgColor: cardBgColor,
                      borderColor: borderColor,
                      items: [
                        'Ephemeral ID: Events are tied to an anonymous installation identifier.',
                        'Data Deletion: Use "Delete My Data" in Library settings to purge all records.',
                        'Local Storage: Events are buffered locally and only sync when connected.',
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Expandable Technical Details
                    GestureDetector(
                      onTap: () => setState(() => _showTechDetails = !_showTechDetails),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showTechDetails ? 'Hide Technical Specifications' : 'View Technical Specifications',
                              style: TextStyle(
                                fontFamily: DecibelTypography.headingFont,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Icon(
                              _showTechDetails ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showTechDetails) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F0E18) : const Color(0xFFE8E4F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Database Schema:\n'
                          '- installs (id uuid, consent_at, device_model, os_version, languages[], fav_artists[])\n'
                          '- play_events (id uuid, install_id, track_key, listened_ms, duration_ms, liked, origin, hour_bucket)\n'
                          '- tracks (track_key, artist_primary, language, genre, tag_confidence)\n'
                          '- playlist_imports (matched track keys; external URLs discarded)\n\n'
                          'Security: Postgres Row Level Security (RLS) policies enforced. Authenticated via anonymous JWT.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            height: 1.45,
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => _handleConsent(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _handleConsent(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DecibelColors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Accept & Continue',
                            style: TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color bgColor,
    required Color borderColor,
    required List<String> items,
  }) {
    final textColor = DecibelColors.textPrimary;
    final secondaryTextColor = DecibelColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '- ',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        fontSize: 11.5,
                        height: 1.35,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
