import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../services/artist_preference_service.dart';
import '../services/language_preference_service.dart';
import '../theme/decibel_colors.dart';
import 'introduction_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
    _proceedAfterDelay();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _proceedAfterDelay() async {
    // Run splash delay and update check concurrently
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      AppUpdateService.checkForUpdate(),
    ]);

    if (!mounted) return;

    final updateInfo = results[1] as UpdateInfo?;

    // Show update dialog if a new build is available
    if (updateInfo != null && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AppUpdateDialog(
          info: updateInfo,
          onDownload: () async {
            Navigator.of(context).pop();
            final uri = Uri.tryParse(updateInfo.downloadUrl);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          onSkip: () async {
            await AppUpdateService.skipBuild(updateInfo.build);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      );
    }

    if (!mounted) return;

    final hasLanguages = LanguagePreferenceService.hasConfigured;
    final hasArtists = ArtistPreferenceService.hasConfigured;

    if (!hasLanguages || !hasArtists) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const IntroductionScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DecibelColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: DecibelColors.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Official DECIBEL brand icon
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: DecibelColors.purple.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'DECIBEL',
                style: TextStyle(
                  fontFamily: DecibelTypography.headingFont,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: DecibelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Feel every note.',
                style: TextStyle(
                  fontFamily: DecibelTypography.bodyFont,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: DecibelColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
