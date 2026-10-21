import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'controllers/player_controller.dart';
import 'screens/splash_screen.dart';
import 'services/artist_preference_service.dart';
import 'services/decibel_audio_handler.dart';
import 'services/decibel_mix_engine.dart';
import 'services/event_uploader.dart';
import 'services/language_preference_service.dart';
import 'services/playback_logger.dart';
import 'services/sync_scheduler.dart';
import 'services/theme_preference_service.dart';
import 'services/user_profile_service.dart';
import 'config/api_config.dart';
import 'theme/decibel_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Theme and User Profile preferences first to configure system UI
  await ThemePreferenceService.init();
  await UserProfileService.init();

  // Edge to edge system navigation style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ThemePreferenceService.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: DecibelColors.background,
      systemNavigationBarIconBrightness: ThemePreferenceService.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize Android background notification player with full previous/play/pause/next controls
  DecibelAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => DecibelAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.decibel.decibel.channel.audio',
        androidNotificationChannelName: 'DECIBEL Music Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        notificationColor: DecibelColors.purple,
      ),
    );
  } catch (e) {
    debugPrint('AudioService init error: $e');
  }

  // Initialize Language, Artist Preferences and DECIBEL Mix Engine background state
  await LanguagePreferenceService.init();
  await ArtistPreferenceService.init();
  await DecibelMixEngine.init();
  await PlaybackLogger().recoverInterruptedSessions();

  // Initialize Supabase backend if configured via environment
  if (ApiConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: ApiConfig.supabaseUrl,
        anonKey: ApiConfig.supabaseAnonKey,
      );
      await EventUploader.ensureSignedIn();
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }

  // Start data collection sync scheduler
  SyncScheduler().initialize();

  runApp(DecibelApp(audioHandler: audioHandler));
}

class DecibelApp extends StatefulWidget {
  final DecibelAudioHandler? audioHandler;
  const DecibelApp({super.key, this.audioHandler});

  @override
  State<DecibelApp> createState() => _DecibelAppState();
}

class _DecibelAppState extends State<DecibelApp> with WidgetsBindingObserver {
  late final PlayerController _playerController;

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController(audioHandler: widget.audioHandler);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _playerController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _playerController),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemePreferenceService.themeModeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'DECIBEL',
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: DecibelTypography.bodyFont,
              brightness: Brightness.light,
              scaffoldBackgroundColor: DecibelColors.lightBackground,
              primaryColor: DecibelColors.purple,
              colorScheme: const ColorScheme.light(
                primary: DecibelColors.purple,
                surface: DecibelColors.lightSurface,
                onPrimary: Colors.white,
                onSurface: DecibelColors.lightTextPrimary,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: DecibelColors.lightSurface,
                modalBackgroundColor: DecibelColors.lightSurface,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: DecibelTypography.bodyFont,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: DecibelColors.darkBackground,
              primaryColor: DecibelColors.purple,
              colorScheme: const ColorScheme.dark(
                primary: DecibelColors.purple,
                surface: DecibelColors.darkSurface,
                onPrimary: Colors.white,
                onSurface: DecibelColors.darkTextPrimary,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: DecibelColors.darkSurface,
                modalBackgroundColor: DecibelColors.darkSurface,
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
