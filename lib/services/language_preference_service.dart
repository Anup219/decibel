import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'event_uploader.dart';

class LanguageOption {
  final String id;
  final String englishName;
  final String nativeName;
  final String searchKeyword;
  final Color accentColor;

  const LanguageOption({
    required this.id,
    required this.englishName,
    required this.nativeName,
    required this.searchKeyword,
    required this.accentColor,
  });
}

class LanguagePreferenceService {
  static const String _keyPreferredLangs = 'decibel_user_preferred_languages';
  static const String _keyHasConfigured = 'decibel_languages_configured';

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      id: 'hindi',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      searchKeyword: 'Bollywood Hindi',
      accentColor: Color(0xFFFF5722),
    ),
    LanguageOption(
      id: 'telugu',
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
      searchKeyword: 'Telugu Tollywood',
      accentColor: Color(0xFFFF9800),
    ),
    LanguageOption(
      id: 'english',
      englishName: 'English',
      nativeName: 'English',
      searchKeyword: 'Global English Pop',
      accentColor: Color(0xFF2196F3),
    ),
    LanguageOption(
      id: 'punjabi',
      englishName: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      searchKeyword: 'Punjabi Hits',
      accentColor: Color(0xFFFFC107),
    ),
    LanguageOption(
      id: 'tamil',
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
      searchKeyword: 'Tamil Kollywood',
      accentColor: Color(0xFFE91E63),
    ),
    LanguageOption(
      id: 'malayalam',
      englishName: 'Malayalam',
      nativeName: 'മലയാളം',
      searchKeyword: 'Malayalam Mollywood',
      accentColor: Color(0xFF4CAF50),
    ),
    LanguageOption(
      id: 'kannada',
      englishName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      searchKeyword: 'Kannada Sandalwood',
      accentColor: Color(0xFF9C27B0),
    ),
    LanguageOption(
      id: 'bhojpuri',
      englishName: 'Bhojpuri',
      nativeName: 'भोजपुरी',
      searchKeyword: 'Bhojpuri Hits',
      accentColor: Color(0xFF795548),
    ),
    LanguageOption(
      id: 'bengali',
      englishName: 'Bengali',
      nativeName: 'বাংলা',
      searchKeyword: 'Bengali Hits',
      accentColor: Color(0xFF00BCD4),
    ),
    LanguageOption(
      id: 'marathi',
      englishName: 'Marathi',
      nativeName: 'मराठी',
      searchKeyword: 'Marathi Hits',
      accentColor: Color(0xFFE040FB),
    ),
  ];

  static final ValueNotifier<List<String>> preferredLanguagesNotifier =
      ValueNotifier<List<String>>(['Hindi', 'English']);
  static final ValueNotifier<bool> hasConfiguredNotifier =
      ValueNotifier<bool>(false);

  static List<String> get preferredLanguages => preferredLanguagesNotifier.value;
  static bool get hasConfigured => hasConfiguredNotifier.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConfig = prefs.getBool(_keyHasConfigured) ?? false;
      hasConfiguredNotifier.value = hasConfig;

      final savedList = prefs.getStringList(_keyPreferredLangs);
      if (savedList != null && savedList.isNotEmpty) {
        preferredLanguagesNotifier.value = savedList;
      } else {
        // Default initial selections before user configures
        preferredLanguagesNotifier.value = ['Hindi', 'English'];
      }
    } catch (_) {}
  }

  static Future<void> savePreferences(List<String> languages) async {
    if (languages.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyPreferredLangs, languages);
      await prefs.setBool(_keyHasConfigured, true);

      preferredLanguagesNotifier.value = List.unmodifiable(languages);
      hasConfiguredNotifier.value = true;

      // Sync updated preferences to remote installs profile
      EventUploader.updatePreferences(languages: languages);
    } catch (_) {}
  }

  /// Determines if a given track matches any of the user's preferred languages
  static bool matchesUserPreferences(Track track) {
    if (preferredLanguages.isEmpty) return true;

    final trackLang = detectTrackLanguage(track).toLowerCase();
    for (final pref in preferredLanguages) {
      if (trackLang.contains(pref.toLowerCase()) || pref.toLowerCase().contains(trackLang)) {
        return true;
      }
    }

    // Also check explicit keywords in title/artist
    final text = '${track.title} ${track.artist} ${track.album}'.toLowerCase();
    for (final pref in preferredLanguages) {
      if (text.contains(pref.toLowerCase())) return true;
    }

    return false;
  }

  /// Detects the language of a track using metadata and artist heuristics
  static String detectTrackLanguage(Track track) {
    if (track.language.isNotEmpty) {
      return _normalizeLanguage(track.language);
    }

    final text = '${track.title} ${track.artist} ${track.album}'.toLowerCase();

    // Telugu detection
    if (text.contains('telugu') ||
        text.contains('tollywood') ||
        text.contains('sid sriram') ||
        text.contains('devi sri prasad') ||
        text.contains('dsp') ||
        text.contains('thaman') ||
        text.contains('anurag kulkarni') ||
        text.contains('ram miriyala') ||
        text.contains('keeravani') ||
        text.contains('spb') ||
        text.contains('chitra') ||
        text.contains('guntur kaaram') ||
        text.contains('pushpa') ||
        text.contains('devara') ||
        text.contains('kalki')) {
      return 'Telugu';
    }

    // Tamil detection
    if (text.contains('tamil') ||
        text.contains('kollywood') ||
        text.contains('anirudh') ||
        text.contains('yuvan') ||
        text.contains('harris jayaraj') ||
        text.contains('santhosh narayanan') ||
        text.contains('dhibu ninan') ||
        text.contains('leo') ||
        text.contains('jailer') ||
        text.contains('vikram')) {
      return 'Tamil';
    }

    // Punjabi detection
    if (text.contains('punjabi') ||
        text.contains('sidhu moose') ||
        text.contains('ap dhillon') ||
        text.contains('diljit') ||
        text.contains('karan aujla') ||
        text.contains('shubh') ||
        text.contains('amrit maan') ||
        text.contains('jordan sandhu') ||
        text.contains('b praak') ||
        text.contains('harrdy')) {
      return 'Punjabi';
    }

    // Malayalam detection
    if (text.contains('malayalam') ||
        text.contains('sushin shyam') ||
        text.contains('hesham abdul') ||
        text.contains('vidyasagar') ||
        text.contains('avesham') ||
        text.contains('manjummel')) {
      return 'Malayalam';
    }

    // Kannada detection
    if (text.contains('kannada') ||
        text.contains('sandalwood') ||
        text.contains('ravi basrur') ||
        text.contains('charan raj') ||
        text.contains('kgf') ||
        text.contains('kantara')) {
      return 'Kannada';
    }

    // Bhojpuri detection
    if (text.contains('bhojpuri') ||
        text.contains('pawan singh') ||
        text.contains('khesari') ||
        text.contains('shilpi raj')) {
      return 'Bhojpuri';
    }

    // Hindi / Bollywood detection
    if (text.contains('hindi') ||
        text.contains('bollywood') ||
        text.contains('arijit') ||
        text.contains('pritam') ||
        text.contains('shreya ghoshal') ||
        text.contains('neha kakkar') ||
        text.contains('badshah') ||
        text.contains('jubin') ||
        text.contains('atif aslam') ||
        text.contains('vishal-shekhar') ||
        text.contains('armaan malik') ||
        text.contains('sonu nigam') ||
        text.contains('mohit chauhan') ||
        text.contains('sachin-jigar') ||
        text.contains('tanishk bagchi')) {
      return 'Hindi';
    }

    // English / Pop detection
    if (text.contains('taylor swift') ||
        text.contains('the weeknd') ||
        text.contains('drake') ||
        text.contains('ed sheeran') ||
        text.contains('billie eilish') ||
        text.contains('justin bieber') ||
        text.contains('dua lipa') ||
        text.contains('bruno mars') ||
        text.contains('post malone') ||
        text.contains('ariana grande') ||
        text.contains('eminem') ||
        text.contains('coldplay') ||
        text.contains('pop') ||
        text.contains('english')) {
      return 'English';
    }

    return 'Hindi';
  }

  static String _normalizeLanguage(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('telugu')) return 'Telugu';
    if (lower.contains('hindi')) return 'Hindi';
    if (lower.contains('english')) return 'English';
    if (lower.contains('tamil')) return 'Tamil';
    if (lower.contains('punjabi')) return 'Punjabi';
    if (lower.contains('malayalam')) return 'Malayalam';
    if (lower.contains('kannada')) return 'Kannada';
    if (lower.contains('bhojpuri')) return 'Bhojpuri';
    if (lower.contains('bengali')) return 'Bengali';
    if (lower.contains('marathi')) return 'Marathi';
    if (lower.contains('gujarati')) return 'Gujarati';
    return raw;
  }
}
