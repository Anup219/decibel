import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/music_provider_registry.dart';
import 'event_uploader.dart';

class ArtistInfo {
  final String name;
  final String language;
  final String imageUrl;

  const ArtistInfo({
    required this.name,
    required this.language,
    required this.imageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistInfo &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

class ArtistPreferenceService {
  static const String _keyFavoriteArtists = 'decibel_user_favorite_artists';
  static const String _keyHasConfiguredArtists = 'decibel_artists_configured';

  static const List<ArtistInfo> catalog = [
    // Telugu
    ArtistInfo(
      name: 'Sid Sriram',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/fbe3e1d17fc6958e047f011f74233f82/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Devi Sri Prasad (DSP)',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a904f8ee6cc4dcb472f75bd8ae1a21da/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'S. Thaman',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/910c0078f7867daaade0fa2d94e37e1b/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Anurag Kulkarni',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/f9f1f4491e7efc579dff25792bbc0fd6/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Ram Miriyala',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/43f399df39ffe548e7ed9b5495abf6e1/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'M. M. Keeravani',
      language: 'Telugu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/5d78a2351117fed4d9d9c564de968a7e/250x250-000000-80-0-0.jpg',
    ),

    // Hindi
    ArtistInfo(
      name: 'Arijit Singh',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/ac5350cff290edd5b69fa584b8b1bd4f/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Pritam',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/d4914ccd414067cd5e2c108867079a85/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Shreya Ghoshal',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/3bb832d37d10ff2affcfa9afdc7c68a0/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Atif Aslam',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/0ea90444148fff9c11d77f06a344724e/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Badshah',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/5b90b89299a7d42f81d79afa263a85d2/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Jubin Nautiyal',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9031b483049b5551abcb11529873b4f6/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Neha Kakkar',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/3a0f7ba65d6d8c1081b461ee49cb59e8/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Sachin-Jigar',
      language: 'Hindi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/d812840574d5c6177ef5480a4ba24d59/250x250-000000-80-0-0.jpg',
    ),

    // English
    ArtistInfo(
      name: 'Taylor Swift',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/cc2495870fe1a792ad0cdb05501ad5ec/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'The Weeknd',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Drake',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/eb0ed5b21d1ea5af021fc074ded0e91f/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Ed Sheeran',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/d6bb84390641d8ae9118228d9544e53d/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Billie Eilish',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Justin Bieber',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/fe097f693cebf1f882e3da79e99e3bf9/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Dua Lipa',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/877872aaf75694f11d53c318700ab2b5/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Post Malone',
      language: 'English',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a5a8cca44e7eab2db7d44e039bed2574/250x250-000000-80-0-0.jpg',
    ),

    // Punjabi
    ArtistInfo(
      name: 'Sidhu Moose Wala',
      language: 'Punjabi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/fb1def876c43cc16738bfd6ad3d1dcd9/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'AP Dhillon',
      language: 'Punjabi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/52594ac9fa763dc163ed13d21cb130ec/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Diljit Dosanjh',
      language: 'Punjabi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/79b85e695e0ca6529e56bf3b628e92bd/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Karan Aujla',
      language: 'Punjabi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a91a1d5ea91e85e4f0966569b50e8d6a/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'B Praak',
      language: 'Punjabi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/efe513aabaa0a94c4db307ac3431b833/250x250-000000-80-0-0.jpg',
    ),

    // Tamil
    ArtistInfo(
      name: 'Anirudh Ravichander',
      language: 'Tamil',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9da0a547b39e99bc35c6a9724aef91bf/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'A.R. Rahman',
      language: 'Tamil',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/bd34315ef977a62a9e28c1ab19bb8ac4/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Yuvan Shankar Raja',
      language: 'Tamil',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/1dbf7d81a2e964d9c707e53478407974/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Harris Jayaraj',
      language: 'Tamil',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/b10caf45eae518a2b16997874ded7143/250x250-000000-80-0-0.jpg',
    ),

    // Malayalam
    ArtistInfo(
      name: 'Sushin Shyam',
      language: 'Malayalam',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/6ba914ca28d2c5cc21dc3effa07c690d/250x250-000000-80-0-0.jpg',
    ),
    ArtistInfo(
      name: 'Hesham Abdul Wahab',
      language: 'Malayalam',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/567c9aaa183caf6d18b33025343a014b/250x250-000000-80-0-0.jpg',
    ),
  ];

  static final ValueNotifier<List<String>> favoriteArtistsNotifier =
      ValueNotifier<List<String>>([]);
  static final ValueNotifier<bool> hasConfiguredNotifier =
      ValueNotifier<bool>(false);

  static List<String> get favoriteArtists => favoriteArtistsNotifier.value;
  static bool get hasConfigured => hasConfiguredNotifier.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasConfiguredNotifier.value = prefs.getBool(_keyHasConfiguredArtists) ?? false;
      final saved = prefs.getStringList(_keyFavoriteArtists);
      if (saved != null) {
        favoriteArtistsNotifier.value = saved;
      }
    } catch (_) {}
  }

  static Future<void> saveFavoriteArtists(List<String> artists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = artists.take(10).toList();
      await prefs.setStringList(_keyFavoriteArtists, capped);
      await prefs.setBool(_keyHasConfiguredArtists, true);
      favoriteArtistsNotifier.value = List.unmodifiable(capped);
      hasConfiguredNotifier.value = true;

      // Sync updated favorite artists to remote installs profile
      EventUploader.updatePreferences(favArtists: capped);
    } catch (_) {}
  }

  /// Returns suggested artists matching the given languages
  static List<ArtistInfo> getArtistsForLanguages(List<String> languages) {
    if (languages.isEmpty) return catalog;
    final lowerLangs = languages.map((l) => l.toLowerCase()).toSet();
    final matched = catalog.where((a) => lowerLangs.contains(a.language.toLowerCase())).toList();
    if (matched.isEmpty) return catalog;
    return matched;
  }

  /// Searches for artists online across music platforms and guarantees the query is returnable
  static Future<List<ArtistInfo>> searchOnlineArtists(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final List<ArtistInfo> results = [];
    final Set<String> seenNames = {};

    // 1. Check local catalog first
    for (final a in catalog) {
      if (a.name.toLowerCase().contains(cleanQuery.toLowerCase())) {
        if (!seenNames.contains(a.name.toLowerCase())) {
          seenNames.add(a.name.toLowerCase());
          results.add(a);
        }
      }
    }

    // 2. Query Deezer Artist Search API (High quality artist photos)
    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse('https://api.deezer.com/search/artist?q=$encoded');
      final res = await http.get(url).timeout(const Duration(milliseconds: 3500));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['data'] is List) {
          for (final item in (data['data'] as List).take(8)) {
            final name = (item['name'] ?? '').toString().trim();
            final pic = (item['picture_medium'] ?? item['picture_big'] ?? item['picture'] ?? '')
                .toString()
                .trim();
            if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
              seenNames.add(name.toLowerCase());
              results.add(ArtistInfo(
                name: name,
                language: 'All',
                imageUrl: pic,
              ));
            }
          }
        }
      }
    } catch (_) {}

    // 3. Query active pluggable provider
    try {
      final providerArtists = await MusicProviderRegistry.current.searchArtists(cleanQuery);
      for (final a in providerArtists) {
        if (!seenNames.contains(a.name.toLowerCase())) {
          seenNames.add(a.name.toLowerCase());
          results.add(a);
        }
      }
    } catch (_) {}

    // 4. Guarantee: If user searched something not yet in results, provide a card with their query name
    final exactMatch = seenNames.contains(cleanQuery.toLowerCase());
    if (!exactMatch) {
      results.insert(
        0,
        ArtistInfo(
          name: cleanQuery,
          language: 'Custom',
          imageUrl: '',
        ),
      );
    }

    return results;
  }
}
