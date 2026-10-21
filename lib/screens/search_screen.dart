import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/player_controller.dart';
import '../models/track.dart';
import '../services/artist_preference_service.dart';
import '../services/language_preference_service.dart';
import '../services/music_search_service.dart';
import '../theme/decibel_colors.dart';
import '../widgets/decibel_components.dart';
import '../widgets/track_tile.dart';

class RecentSearchItem {
  final String id;
  final String query;
  final Track? track;
  final int timestamp;

  const RecentSearchItem({
    required this.id,
    required this.query,
    this.track,
    required this.timestamp,
  });

  bool get isTrack => track != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'track': track?.toJson(),
        'timestamp': timestamp,
      };

  factory RecentSearchItem.fromJson(Map<String, dynamic> json) {
    return RecentSearchItem(
      id: json['id']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      track: json['track'] != null
          ? Track.fromJson(json['track'] as Map<String, dynamic>)
          : null,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  List<Track> _searchResults = [];
  bool _isLoading = false;
  List<RecentSearchItem> _recentItems = [];

  // Sonora 6 Primary Explore Categories
  final List<Map<String, dynamic>> _exploreCategories = const [
    {
      'title': 'Genres',
      'colors': [Color(0xFF8060E9), Color(0xFF9382E8)],
      'icon': Icons.music_note_rounded,
      'query': 'Top genres music',
    },
    {
      'title': 'Moods',
      'colors': [Color(0xFFCD6DA8), Color(0xFFED86BF)],
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'query': 'Moods chill playlist',
    },
    {
      'title': 'Decades',
      'colors': [Color(0xFFF16657), Color(0xFFFF9D64)],
      'icon': Icons.radio_rounded,
      'query': '80s 90s 2000s classics',
    },
    {
      'title': 'Activities',
      'colors': [Color(0xFF4C9D98), Color(0xFF76C4A7)],
      'icon': Icons.directions_run_rounded,
      'query': 'Workout running study',
    },
    {
      'title': 'Podcasts',
      'colors': [Color(0xFF6284DC), Color(0xFF809CE7)],
      'icon': Icons.mic_none_rounded,
      'query': 'Podcasts stories',
    },
    {
      'title': 'Live',
      'colors': [Color(0xFF9052D8), Color(0xFFC176E7)],
      'icon': Icons.podcasts_rounded,
      'query': 'Live acoustic performance',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('decibel_recent_searches_rich');
    if (jsonStr != null) {
      try {
        final list = (jsonDecode(jsonStr) as List)
            .map((e) => RecentSearchItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _recentItems = list;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _recentItems.map((e) => e.toJson()).toList();
    await prefs.setString('decibel_recent_searches_rich', jsonEncode(jsonList));
  }

  void _saveRecentQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentItems.removeWhere((item) => !item.isTrack && item.query.toLowerCase() == trimmed.toLowerCase());
    _recentItems.insert(
      0,
      RecentSearchItem(
        id: 'query_${DateTime.now().millisecondsSinceEpoch}',
        query: trimmed,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_recentItems.length > 20) _recentItems = _recentItems.sublist(0, 20);
    _saveRecentSearches();
    if (mounted) setState(() {});
  }

  void _saveRecentTrack(Track track) {
    _recentItems.removeWhere((item) => item.isTrack && item.track?.id == track.id);
    _recentItems.insert(
      0,
      RecentSearchItem(
        id: 'track_${track.id}',
        query: track.title,
        track: track,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_recentItems.length > 20) _recentItems = _recentItems.sublist(0, 20);
    _saveRecentSearches();
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 320), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final results = await MusicSearchService.searchSongs(query, limit: 40);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<PlayerController>();
    final isFocused = _searchFocusNode.hasFocus;
    final query = _searchController.text.trim();

    Widget content;
    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: DecibelColors.purple),
      );
    } else if (query.isNotEmpty) {
      content = _buildSearchResults(controller);
    } else {
      content = _buildDefaultExploreView(controller);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Title & Search Field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: DecibelTypography.screenTitle),
                  const SizedBox(height: 10),
                  // Dark Search Field
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: DecibelColors.card,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: DecibelColors.textSecondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              color: DecibelColors.textPrimary,
                              fontSize: 13,
                            ),
                            cursorColor: DecibelColors.purple,
                            onChanged: _onSearchChanged,
                            onSubmitted: (term) {
                              _saveRecentQuery(term);
                              _performSearch(term);
                            },
                            decoration: const InputDecoration(
                              hintText: 'Songs, artists, albums, podcasts...',
                              hintStyle: TextStyle(
                                fontFamily: DecibelTypography.bodyFont,
                                color: DecibelColors.textSubtle,
                                fontSize: 11.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(Icons.close_rounded, color: DecibelColors.textSecondary, size: 18),
                          )
                        else
                          const Icon(Icons.mic_none_rounded, color: DecibelColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  /// Default Sonora View (Explore 2-column Grid + Trending Searches)
  Widget _buildDefaultExploreView(PlayerController controller) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        // "Explore" Section Header
        const SonoraSectionHeading(title: 'Explore'),

        // 2-Column Category Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemCount: _exploreCategories.length,
          itemBuilder: (context, index) {
            final cat = _exploreCategories[index];
            return SonoraCategoryCard(
              title: cat['title'] as String,
              icon: cat['icon'] as IconData,
              gradientColors: cat['colors'] as List<Color>,
              onTap: () {
                _searchController.text = cat['title'] as String;
                _performSearch(cat['query'] as String);
              },
            );
          },
        ),

        // "Your Favorite Artists" Section (from Decibel Artist Preferences)
        if (ArtistPreferenceService.favoriteArtists.isNotEmpty) ...[
          const SonoraSectionHeading(title: 'Your Favorite Artists'),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: ArtistPreferenceService.favoriteArtists.map((artist) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () {
                      _searchController.text = artist;
                      _performSearch('$artist hits');
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: DecibelColors.activePillGradient,
                            boxShadow: [
                              BoxShadow(
                                color: DecibelColors.purple.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 68,
                          child: Text(
                            artist,
                            style: const TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: DecibelColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // "Explore Your Languages" Section
        if (LanguagePreferenceService.preferredLanguages.isNotEmpty) ...[
          const SonoraSectionHeading(title: 'Your Music Languages'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LanguagePreferenceService.preferredLanguages.map((lang) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = '$lang Hits';
                  _performSearch('Top $lang Songs 2024');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: DecibelColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DecibelColors.purple.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 14, color: DecibelColors.purple),
                      const SizedBox(width: 6),
                      Text(
                        lang,
                        style: const TextStyle(
                          fontFamily: DecibelTypography.headingFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: DecibelColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Recent searches if available
        if (_recentItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SonoraSectionHeading(title: 'Recent Searches'),
          ..._recentItems.take(5).map((item) {
            if (item.isTrack && item.track != null) {
              return TrackTile(
                track: item.track!,
                onTap: () => controller.playTrackFromSearch(item.track!),
              );
            }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: DecibelColors.textSecondary),
              title: Text(item.query,
                  style: const TextStyle(
                      fontFamily: DecibelTypography.headingFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DecibelColors.textPrimary)),
              onTap: () {
                _searchController.text = item.query;
                _performSearch(item.query);
              },
            );
          }),
        ],
      ],
    );
  }

  /// Live Search Results View
  Widget _buildSearchResults(PlayerController controller) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: DecibelColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No tracks found',
              style: TextStyle(
                fontFamily: DecibelTypography.headingFont,
                color: DecibelColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for another song, artist, or album',
              style: TextStyle(
                fontFamily: DecibelTypography.bodyFont,
                color: DecibelColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;

        return TrackTile(
          track: track,
          isPlaying: isPlaying,
          onTap: () {
            _saveRecentTrack(track);
            controller.playTrackFromSearch(track);
          },
        );
      },
    );
  }
}
