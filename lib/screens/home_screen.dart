import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/player_controller.dart';
import '../models/mix_box.dart';
import '../models/track.dart';
import '../services/artist_preference_service.dart';
import '../services/decibel_mix_engine.dart';
import '../services/language_preference_service.dart';
import '../services/music_search_service.dart';
import '../services/theme_preference_service.dart';
import '../services/user_profile_service.dart';
import '../theme/decibel_colors.dart';
import '../widgets/edit_name_dialog.dart';
import '../widgets/language_preference_card.dart';
import '../widgets/mix_box_card.dart';
import '../widgets/decibel_components.dart';
import '../widgets/track_tile.dart';
import 'introduction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  List<Track> _trendingTracks = [];
  bool _isLoadingTrending = true;
  bool _isPreferenceCardDismissed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    LanguagePreferenceService.preferredLanguagesNotifier.addListener(_onPreferencesChanged);
    ArtistPreferenceService.favoriteArtistsNotifier.addListener(_onPreferencesChanged);
    _loadTrending();
  }

  @override
  void dispose() {
    LanguagePreferenceService.preferredLanguagesNotifier.removeListener(_onPreferencesChanged);
    ArtistPreferenceService.favoriteArtistsNotifier.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onPreferencesChanged() {
    if (mounted) {
      _loadTrending(force: true);
      DecibelMixEngine.refreshMixes(force: true);
    }
  }

  static const String _keyDailyPicksDate = 'decibel_daily_picks_date';
  static const String _keyDailyPicksCache = 'decibel_daily_picks_cache';
  static const String _keyDailyPicksLangs = 'decibel_daily_picks_langs';

  Future<void> _loadTrending({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTrending = true;
    });

    try {
      final langs = LanguagePreferenceService.preferredLanguages;
      final favArtists = ArtistPreferenceService.favoriteArtists;
      final now = DateTime.now();
      // Rotate cache every 3 hours so morning, afternoon, and evening get distinct fresh songs
      final bucketStr = '${now.year}-${now.month}-${now.day}-H${now.hour ~/ 3}';
      final prefs = await SharedPreferences.getInstance();

      final cachedBucket = prefs.getString(_keyDailyPicksDate);
      final cachedLangs = prefs.getString(_keyDailyPicksLangs);
      final currentLangsStr = langs.join(',');

      if (!force && cachedBucket == bucketStr && cachedLangs == currentLangsStr) {
        final cachedJson = prefs.getString(_keyDailyPicksCache);
        if (cachedJson != null) {
          try {
            final list = (jsonDecode(cachedJson) as List)
                .map((e) => Track.fromJson(e as Map<String, dynamic>))
                .toList();
            if (list.isNotEmpty && mounted) {
              setState(() {
                _trendingTracks = DecibelMixEngine.deduplicateTracks(list);
                _isLoadingTrending = false;
              });
              return;
            }
          } catch (_) {}
        }
      }

      final tracks = await MusicSearchService.searchTrendingByLanguages(
        langs,
        limitPerLang: 10,
        favoriteArtists: favArtists,
      );

      final deduped = DecibelMixEngine.deduplicateTracks(tracks);

      if (deduped.isNotEmpty) {
        await prefs.setString(_keyDailyPicksDate, bucketStr);
        await prefs.setString(_keyDailyPicksLangs, currentLangsStr);
        await prefs.setString(
          _keyDailyPicksCache,
          jsonEncode(deduped.map((t) => t.toJson()).toList()),
        );
      }

      if (mounted) {
        setState(() {
          _trendingTracks = deduped;
          _isLoadingTrending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  final Map<String, List<Track>> _topPicksCache = {};

  List<_TopPickPlaylistData> _getDailyTopPicks() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    final focusQueries = [
      'Focus Deep Work Lo-Fi Beats',
      'Focus Study Piano Instrumental',
      'Calm Focus Electronic Ambient',
      'Focus Binaural Concentration Study',
      'Deep Work Chillstep Focus Beats',
      'Focus Classical Acoustic Study',
      'Ambient Soundscapes Work Focus',
    ];
    final chillQueries = [
      'Chill Acoustic Evening Vibes',
      'Chill Sunset Lounge Lo-Fi',
      'Calm Indie Acoustic Chill',
      'Relaxing Ambient Chill Beats',
      'Midnight Chill R&B Soul',
      'Coffeehouse Acoustic Chill Songs',
      'Smooth Chillhop Instrumental',
    ];
    final energyQueries = [
      'High Energy Upbeat Dance Hits',
      'Workout Motivation Cardio EDM',
      'Power Pop High Energy Anthems',
      'Fast Beats Dance Party Hits',
      'Gym Workout Bass Motivation',
      'Viral Upbeat Dance Party',
      'Electropop High Energy Bangers',
    ];
    final romanceQueries = [
      'Romantic Love Melodies Acoustic',
      'Soulful Romantic Love Ballads',
      'Sweet Acoustic Love Duets',
      'Romantic Candlelight Melodies',
      'Heartfelt Love Hits',
      'Romantic Lo-Fi Love Beats',
      'Acoustic Passionate Love Songs',
    ];

    return [
      _TopPickPlaylistData(
        key: 'focus_daily',
        title: 'Focus',
        description: 'Deep Work & Lo-Fi',
        icon: Icons.psychology_rounded,
        gradientColors: const [Color(0xFF38236E), Color(0xFF1B0F38)],
        query: focusQueries[dayOfYear % focusQueries.length],
      ),
      _TopPickPlaylistData(
        key: 'chill_daily',
        title: 'Chill',
        description: 'Relax Acoustic Vibes',
        icon: Icons.spa_rounded,
        gradientColors: const [Color(0xFF134E43), Color(0xFF092923)],
        query: chillQueries[dayOfYear % chillQueries.length],
      ),
      _TopPickPlaylistData(
        key: 'energy_daily',
        title: 'Energy',
        description: 'Upbeat Hits & Workout',
        icon: Icons.bolt_rounded,
        gradientColors: const [Color(0xFF741830), Color(0xFF380814)],
        query: energyQueries[dayOfYear % energyQueries.length],
      ),
      _TopPickPlaylistData(
        key: 'romance_daily',
        title: 'Romance',
        description: 'Sweet Love Melodies',
        icon: Icons.favorite_rounded,
        gradientColors: const [Color(0xFF6B184E), Color(0xFF350624)],
        query: romanceQueries[dayOfYear % romanceQueries.length],
      ),
    ];
  }

  Future<List<Track>> _getTopPickTracks(String key, String query) async {
    if (_topPicksCache.containsKey(key) && _topPicksCache[key]!.isNotEmpty) {
      return _topPicksCache[key]!;
    }
    final tracks = await MusicSearchService.searchSongs(query, limit: 40);
    if (tracks.isNotEmpty) {
      _topPicksCache[key] = tracks;
    }
    return tracks;
  }

  void _playTopPick(_TopPickPlaylistData data) async {
    final controller = context.read<PlayerController>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading ${data.title} Top Pick (40 songs)...'),
        backgroundColor: DecibelColors.surface,
        duration: const Duration(milliseconds: 1400),
      ),
    );
    final tracks = await _getTopPickTracks(data.key, data.query);
    if (tracks.isNotEmpty && mounted) {
      controller.playQueue(tracks);
    }
  }

  void _openTopPickDetail(_TopPickPlaylistData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TopPickDetailSheet(
        data: data,
        loadTracks: () => _getTopPickTracks(data.key, data.query),
      ),
    );
  }

  void _playMoment(String genre, String query) async {
    final controller = context.read<PlayerController>();
    final tracks = await MusicSearchService.searchSongs(query, limit: 40);
    if (tracks.isNotEmpty && mounted) {
      controller.playQueue(tracks);
    }
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Settings & Preferences', style: DecibelTypography.sectionHeading),
              const SizedBox(height: 12),
              // User Profile Name Tile
              ValueListenableBuilder<String>(
                valueListenable: UserProfileService.userNameNotifier,
                builder: (context, name, _) {
                  final display = name.trim().isEmpty ? 'Not set (Guest)' : name.trim();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const SonoraUserAvatar(size: 38),
                    title: const Text('Your Name',
                        style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      display,
                      style: const TextStyle(fontSize: 12, color: DecibelColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.edit_rounded, size: 18, color: DecibelColors.purple),
                    onTap: () {
                      Navigator.pop(ctx);
                      EditNameDialog.show(context);
                    },
                  );
                },
              ),
              // Theme Toggle Tile (Dark/Light)
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemePreferenceService.themeModeNotifier,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DecibelColors.purple.withOpacity(0.12),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: DecibelColors.purple,
                        size: 20,
                      ),
                    ),
                    title: const Text('Appearance Theme',
                        style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      isDark ? 'Decibel Dark Theme (Active)' : 'Light Theme (Active)',
                      style: const TextStyle(fontSize: 12, color: DecibelColors.textSecondary),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: DecibelColors.purple,
                      onChanged: (val) {
                        ThemePreferenceService.toggleTheme();
                      },
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DecibelColors.purple.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.translate, color: DecibelColors.purple, size: 20),
                ),
                title: const Text('Music Languages',
                    style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  LanguagePreferenceService.preferredLanguages.join(', '),
                  style: const TextStyle(fontSize: 12, color: DecibelColors.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: DecibelColors.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  LanguagePreferenceCard.showAsBottomSheet(
                    context,
                    onSaved: () {
                      _loadTrending(force: true);
                      DecibelMixEngine.refreshMixes(force: true);
                    },
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DecibelColors.purple.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.favorite_outline, color: DecibelColors.purple, size: 20),
                ),
                title: const Text('Favorite Artists',
                    style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  ArtistPreferenceService.favoriteArtists.isEmpty
                      ? 'Select your artists'
                      : ArtistPreferenceService.favoriteArtists.take(3).join(', ') +
                          (ArtistPreferenceService.favoriteArtists.length > 3
                              ? ' +${ArtistPreferenceService.favoriteArtists.length - 3} more'
                              : ''),
                  style: const TextStyle(fontSize: 12, color: DecibelColors.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: DecibelColors.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IntroductionScreen(
                        isEditingFromSettings: true,
                        onComplete: () {
                          _loadTrending(force: true);
                          DecibelMixEngine.refreshMixes(force: true);
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DecibelColors.purple.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: DecibelColors.purple, size: 20),
                ),
                title: const Text('Privacy & Telemetry',
                    style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.w600)),
                subtitle: const Text('Review anonymous data collection & permissions',
                    style: TextStyle(fontSize: 12, color: DecibelColors.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: DecibelColors.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => const ConsentDialog(),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showMixBoxDetails(DecibelMixBox box, PlayerController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: DecibelColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: box.gradientColors.first.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: box.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            box.cadenceBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          box.title,
                          style: const TextStyle(
                            fontFamily: DecibelTypography.headingFont,
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          box.subtitle,
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 44,
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      controller.playQueue(box.tracks);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${box.tracks.length} Tracks',
                      style: const TextStyle(
                          color: DecibelColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    icon: const Icon(Icons.shuffle, size: 16, color: DecibelColors.purple),
                    label: const Text('Shuffle', style: TextStyle(color: DecibelColors.purple)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      controller.playQueueShuffled(box.tracks);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: box.tracks.length,
                itemBuilder: (context, i) {
                  final track = box.tracks[i];
                  return TrackTile(
                    track: track,
                    onTap: () {
                      Navigator.pop(ctx);
                      controller.playTrack(track, newQueue: box.tracks);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<PlayerController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: DecibelColors.purple,
        backgroundColor: DecibelColors.surface,
        onRefresh: () async {
          await Future.wait([
            _loadTrending(force: true),
            DecibelMixEngine.refreshMixes(force: true),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Top Greeting & Avatar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => EditNameDialog.show(context),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: UserProfileService.userNameNotifier,
                              builder: (context, name, _) {
                                final displayName = name.trim().isEmpty ? 'Friend' : name.trim();
                                return Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${_getGreeting()}, $displayName',
                                        style: DecibelTypography.greetingTitle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFF4AD39),
                                      size: 18,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Let’s play something beautiful',
                              style: TextStyle(
                                fontFamily: DecibelTypography.bodyFont,
                                color: DecibelColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SonoraUserAvatar(
                      size: 38,
                      onTap: _showSettingsDialog,
                    ),
                  ],
                ),
              ),
            ),

            // Curated for you "Sunrise Acoustic" hero card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: SonoraSunriseHeroCard(
                  eyebrow: 'CURATED FOR YOU',
                  title: 'Sunrise\nAcoustic',
                  description: 'Warm guitars to start\nyour day right.',
                  onPlay: () => _playMoment('Acoustic', 'Sunrise Acoustic Chill Guitar'),
                ),
              ),
            ),

            // "For your moment" chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text('For your moment', style: DecibelTypography.sectionHeading),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    SonoraMomentCard(
                      title: 'Focus',
                      detail: 'Deep Work',
                      gradientColors: const [Color(0xFF221C3B), Color(0xFF18152B)],
                      borderColor: const Color(0xFF3B2E60),
                      onTap: () => _playMoment('Focus', 'Deep focus ambient study work'),
                    ),
                    SonoraMomentCard(
                      title: 'Chill',
                      detail: 'Lo-Fi Vibes',
                      gradientColors: const [Color(0xFF132D2D), Color(0xFF0D1F1F)],
                      borderColor: const Color(0xFF1E4D4B),
                      onTap: () => _playMoment('Chill', 'Lofi beats chill vibes relax'),
                    ),
                    SonoraMomentCard(
                      title: 'Energy',
                      detail: 'Upbeat Hits',
                      gradientColors: const [Color(0xFF381D29), Color(0xFF26131C)],
                      borderColor: const Color(0xFF58263D),
                      onTap: () => _playMoment('Energy', 'Upbeat workout dance pop high energy'),
                    ),
                    SonoraMomentCard(
                      title: 'Romance',
                      detail: 'Date Night',
                      gradientColors: const [Color(0xFF321A37), Color(0xFF211124)],
                      borderColor: const Color(0xFF52275A),
                      onTap: () => _playMoment('Romance', 'Romantic love songs date night acoustic'),
                    ),
                  ],
                ),
              ),
            ),

            // Today's Top Pick Playlists (Focus, Chill, Energy, Romance - Updated Daily • 40 Songs)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Top Pick Playlists', style: DecibelTypography.sectionHeading),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DecibelColors.purple.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DecibelColors.purple.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 10, color: DecibelColors.purple),
                          SizedBox(width: 4),
                          Text(
                            'UPDATED DAILY • 40 SONGS',
                            style: TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              color: DecibelColors.purple,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _getDailyTopPicks().map((data) {
                    return GestureDetector(
                      onTap: () => _openTopPickDetail(data),
                      child: Container(
                        width: 148,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: data.gradientColors,
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: data.gradientColors.first.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Watermark icon
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: Opacity(
                                opacity: 0.12,
                                child: Icon(
                                  data.icon,
                                  size: 74,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DAILY PICK',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Icon(data.icon, color: Colors.white.withOpacity(0.7), size: 18),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      data.title,
                                      style: const TextStyle(
                                        fontFamily: DecibelTypography.headingFont,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data.description,
                                      style: const TextStyle(
                                        fontFamily: DecibelTypography.bodyFont,
                                        fontSize: 9.5,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '40 songs',
                                      style: TextStyle(
                                        fontFamily: DecibelTypography.bodyFont,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white60,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _playTopPick(data),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: data.gradientColors.first,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // "New & Notable" Albums / Releases Section (Live Dynamic Songs)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SonoraSectionHeading(
                  title: 'New & Notable',
                  onSeeAll: () {
                    if (_trendingTracks.isNotEmpty) {
                      controller.playQueue(_trendingTracks);
                    }
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 145,
                child: _trendingTracks.isNotEmpty
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _trendingTracks.length.clamp(0, 10),
                        itemBuilder: (context, index) {
                          final track = _trendingTracks[index];
                          return SonoraAlbumCard(
                            artwork: track.artworkUrl,
                            title: track.title,
                            artist: track.artist,
                            isNew: index < 3,
                            onTap: () => controller.playTrack(track, newQueue: _trendingTracks),
                          );
                        },
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          SonoraAlbumCard(
                            artwork: '',
                            title: 'Trending Mix',
                            artist: 'DECIBEL',
                            isNew: true,
                            onTap: () => _playMoment('Trending', 'Top Hits 2024'),
                          ),
                          SonoraAlbumCard(
                            artwork: '',
                            title: 'Daily Radar',
                            artist: 'For You',
                            onTap: () => _playMoment('Radar', 'New Music Friday'),
                          ),
                        ],
                      ),
              ),
            ),

            // "Because you listened" Section (Dynamic User Recommendation)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SonoraSectionHeading(
                  title: controller.likedTracks.isNotEmpty
                      ? 'Because you liked ${controller.likedTracks.first.title}'
                      : 'Because you listened',
                  onSeeAll: () {
                    if (controller.likedTracks.isNotEmpty) {
                      controller.playQueue(controller.likedTracks);
                    }
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Builder(
                  builder: (context) {
                    final recTrack1 = controller.likedTracks.isNotEmpty
                        ? controller.likedTracks.first
                        : (_trendingTracks.isNotEmpty ? _trendingTracks.first : null);
                    final recTrack2 = controller.likedTracks.length > 1
                        ? controller.likedTracks[1]
                        : (_trendingTracks.length > 1 ? _trendingTracks[1] : null);

                    return Column(
                      children: [
                        if (recTrack1 != null) ...[
                          SonoraRecommendationTile(
                            artwork: recTrack1.artworkUrl.isNotEmpty ? recTrack1.artworkUrl : 'paper-hearts',
                            title: recTrack1.title,
                            artist: recTrack1.artist,
                            onPlay: () {
                              if (controller.likedTracks.isNotEmpty) {
                                controller.playTrack(recTrack1, newQueue: controller.likedTracks);
                              } else {
                                controller.playTrack(recTrack1, newQueue: _trendingTracks);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (recTrack2 != null)
                          SonoraRecommendationTile(
                            artwork: recTrack2.artworkUrl.isNotEmpty ? recTrack2.artworkUrl : 'moments',
                            title: recTrack2.title,
                            artist: recTrack2.artist,
                            trailingSecondary: const Icon(
                              Icons.devices_rounded,
                              color: DecibelColors.textSecondary,
                              size: 18,
                            ),
                            onPlay: () {
                              if (controller.likedTracks.length > 1) {
                                controller.playTrack(recTrack2, newQueue: controller.likedTracks);
                              } else {
                                controller.playTrack(recTrack2, newQueue: _trendingTracks);
                              }
                            },
                          )
                        else if (recTrack1 == null) ...[
                          SonoraRecommendationTile(
                            artwork: 'paper-hearts',
                            title: 'Heading Home',
                            artist: 'KEVIN KAARL',
                            onPlay: () => _playMoment('Discover', 'Heading Home Kevin Kaarl'),
                          ),
                          const SizedBox(height: 8),
                          SonoraRecommendationTile(
                            artwork: 'moments',
                            title: 'Moments Like This',
                            artist: 'Dermot Kennedy',
                            trailingSecondary: const Icon(
                              Icons.devices_rounded,
                              color: DecibelColors.textSecondary,
                              size: 18,
                            ),
                            onPlay: () => _playMoment('Discover', 'Moments Like This Dermot Kennedy'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

            // "Made for You" Mix Boxes Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Text('Made for You', style: DecibelTypography.sectionHeading),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: ValueListenableBuilder<List<DecibelMixBox>>(
                valueListenable: DecibelMixEngine.mixBoxesNotifier,
                builder: (context, boxes, _) {
                  if (boxes.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(color: DecibelColors.purple),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final box = boxes[index];
                        final isPlayingThisBox = box.tracks.any(
                          (t) => t.id == controller.currentTrack?.id && controller.isPlaying,
                        );

                        return MixBoxCard(
                          box: box,
                          isPlayingThisBox: isPlayingThisBox,
                          onPlay: () {
                            if (box.tracks.isNotEmpty) {
                              controller.playQueue(box.tracks);
                            }
                          },
                          onShuffle: () {
                            if (box.tracks.isNotEmpty) {
                              controller.playQueueShuffled(box.tracks);
                            }
                          },
                          onTap: () => _showMixBoxDetails(box, controller),
                        );
                      },
                      childCount: boxes.length,
                    ),
                  );
                },
              ),
            ),

            // Bottom space for floating navigation & mini player
            const SliverToBoxAdapter(
              child: SizedBox(height: 130),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPickPlaylistData {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final String query;

  const _TopPickPlaylistData({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.query,
  });
}

class _TopPickDetailSheet extends StatefulWidget {
  final _TopPickPlaylistData data;
  final Future<List<Track>> Function() loadTracks;

  const _TopPickDetailSheet({
    required this.data,
    required this.loadTracks,
  });

  @override
  State<_TopPickDetailSheet> createState() => _TopPickDetailSheetState();
}

class _TopPickDetailSheetState extends State<_TopPickDetailSheet> {
  List<Track>? _tracks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final t = await widget.loadTracks();
    if (mounted) {
      setState(() {
        _tracks = t;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: widget.data.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.data.gradientColors.first.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.data.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DecibelColors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DAILY TOP PICK',
                              style: TextStyle(
                                color: DecibelColors.purple,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.data.title,
                        style: const TextStyle(
                          fontFamily: DecibelTypography.headingFont,
                          color: DecibelColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoading ? 'Loading 40 songs...' : '${_tracks?.length ?? 40} songs • Daily Refresh',
                        style: const TextStyle(color: DecibelColors.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (_tracks != null && _tracks!.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: DecibelColors.textSecondary, size: 22),
                    onPressed: () {
                      controller.playQueueShuffled(_tracks!);
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: DecibelColors.purple, size: 38),
                    onPressed: () {
                      controller.playQueue(_tracks!);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: DecibelColors.purple),
                  )
                : (_tracks == null || _tracks!.isEmpty)
                    ? const Center(
                        child: Text(
                          'No songs found for this playlist today.',
                          style: TextStyle(color: DecibelColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _tracks!.length,
                        itemBuilder: (context, i) {
                          final track = _tracks![i];
                          final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;
                          return TrackTile(
                            track: track,
                            isPlaying: isPlaying,
                            onTap: () {
                              controller.playTrack(track, newQueue: _tracks!);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
