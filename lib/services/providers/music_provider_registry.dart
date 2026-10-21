import 'music_provider.dart';
import 'standard_music_provider.dart';

/// Registry for managing the active MusicProvider instance.
/// 
/// Decibel defaults to [StandardMusicProvider]. Custom or licensed providers
/// can be registered at runtime during app bootstrap:
/// 
/// ```dart
/// MusicProviderRegistry.registerProvider(MyLicensedMusicProvider());
/// ```
class MusicProviderRegistry {
  MusicProviderRegistry._();

  static MusicProvider _current = StandardMusicProvider();

  /// The active music provider instance
  static MusicProvider get current => _current;

  /// Register a licensed or custom music provider
  static void registerProvider(MusicProvider provider) {
    _current = provider;
  }
}
