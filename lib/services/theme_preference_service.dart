import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceService {
  static const String _keyIsDarkMode = 'decibel_is_dark_mode';
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkPref = prefs.getBool(_keyIsDarkMode) ?? true;
    themeModeNotifier.value = isDarkPref ? ThemeMode.dark : ThemeMode.light;
    _updateSystemOverlay(isDarkPref);
  }

  static Future<void> toggleTheme() async {
    final nextIsDark = !isDark;
    themeModeNotifier.value = nextIsDark ? ThemeMode.dark : ThemeMode.light;
    _updateSystemOverlay(nextIsDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, nextIsDark);
  }

  static Future<void> setDarkMode(bool dark) async {
    themeModeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
    _updateSystemOverlay(dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, dark);
  }

  static void _updateSystemOverlay(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? const Color(0xFF0E0C17) : const Color(0xFFFAF9FD),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }
}
