import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static const String _keyUserName = 'decibel_user_custom_name';
  static final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('');

  static String get userName => userNameNotifier.value;
  static String get displayName => userName.trim().isEmpty ? 'Friend' : userName.trim();

  static String get avatarLetter {
    final clean = userName.trim();
    if (clean.isNotEmpty) {
      return clean[0].toUpperCase();
    }
    return 'D';
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userNameNotifier.value = prefs.getString(_keyUserName) ?? '';
  }

  static Future<void> setUserName(String name) async {
    final clean = name.trim();
    userNameNotifier.value = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, clean);
  }
}
