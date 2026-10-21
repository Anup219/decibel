# 🎧 Decibel Music

A modern, high-performance music streaming application and client built with **Flutter**, inspired by the sleek aesthetics of Spotify and the smart dynamic discovery of YouTube Music.

---

## ✨ Features

- **Personalized "Made for You" Mixes**:
  - **Daily Mix**: Tailored blend of your most listened artists and top language hits.
  - **Artist Mix**: Curated radio centered around your favorite and primary artists.
  - **Release Radar**: Fresh new releases filtered by your language preferences.
  - **Recently Played**: Auto-updated live queue of your recent listening history.
- **Smart Queue & Dynamic Autoplay**:
  - Selecting a searched song plays that song and automatically generates a taste-weighted, randomized radio queue behind it.
  - Infinite autoplay powered by `DecibelMixEngine` so playback never awkwardly stops.
- **Rich Browse & Search**:
  - Live search suggestions and responsive catalog search.
  - Spotify-aesthetic browse cards for Indian & Global genres (Bollywood, Telugu Hits, Tamil Beats, Punjabi Pop, Lo-Fi, Hip-Hop, Indie India, etc.).
- **Full Playback Engine**:
  - Background audio playback with system notification controls (`audio_service` + `just_audio`).
  - Pluggable stream resolution architecture for audio tracks.
  - Time-synced lyrics, liked tracks, user playlist creation, and offline caching.
- **Onboarding Personalization**:
  - Interactive selection of favorite artists across regions and preferred languages.

---

## 🔌 Pluggable Music Source Architecture

Decibel features a modular, pluggable provider architecture (`MusicProvider`). The core application is strictly a player UI and recommendation engine; **it does not ship with or bundle proprietary or unlicensed music extractors**.

Users and developers connect their own licensed audio provider or self-hosted media catalog (such as Spotify Web API, Apple MusicKit, Subsonic/Navidrome, Jamendo, or personal cloud storage).

### Implementing a Custom Provider

To connect your licensed provider, implement the `MusicProvider` interface:

```dart
import 'package:decibel/models/track.dart';
import 'package:decibel/services/providers/music_provider.dart';
import 'package:decibel/services/providers/music_provider_registry.dart';

class MyCustomMusicProvider implements MusicProvider {
  @override
  String get name => 'My Licensed Audio Provider';

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 40, int page = 1}) async {
    // Call your licensed API endpoint or private media server
    return [];
  }

  @override
  Future<String?> resolveStreamUrl(String title, String artist) async {
    // Return direct authorized audio stream URL
    return 'https://your-media-server.com/stream/...';
  }

  @override
  Future<List<ArtistInfo>> searchArtists(String query) async {
    return [];
  }
}
```

Register your provider during app startup (e.g. in `lib/main.dart`):

```dart
void main() async {
  // ...
  MusicProviderRegistry.registerProvider(MyCustomMusicProvider());
  runApp(DecibelApp());
}
```

By default, Decibel uses `StandardMusicProvider`, which queries public catalog preview endpoints for demonstration and development purposes.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.9.0`)
- **Audio Engine**: [`just_audio`](https://pub.dev/packages/just_audio) & [`audio_service`](https://pub.dev/packages/audio_service)
- **State Management**: [`provider`](https://pub.dev/packages/provider)
- **Persistence**: [`shared_preferences`](https://pub.dev/packages/shared_preferences) & [`sqflite`](https://pub.dev/packages/sqflite)
- **Networking & Cache**: [`http`](https://pub.dev/packages/http) & [`cached_network_image`](https://pub.dev/packages/cached_network_image)
- **UI & Animations**: [`lottie`](https://pub.dev/packages/lottie), [`cupertino_icons`](https://pub.dev/packages/cupertino_icons)

---

## 📁 Project Structure

```
lib/
├── config/               # App configuration & environment settings
├── controllers/          # State & business logic (PlayerController)
├── models/               # Domain models (Track, MixBox, UserPlaylist)
├── screens/              # App views (Home, Search, Library, Player, Splash)
├── services/             # Core engines:
│   ├── providers/        # Pluggable music source interfaces (MusicProvider)
│   ├── decibel_mix_engine.dart       # Recommendation engine
│   ├── music_search_service.dart     # Catalog search service
│   ├── full_song_stream_resolver.dart# Stream resolution cache & dispatcher
│   ├── artist_preference_service.dart# Artist catalog & onboarding state
│   ├── language_preference_service.dart # Language selection & detection
│   └── decibel_audio_handler.dart    # Android/iOS background audio handler
├── theme/                # Decibel design tokens & curated color palette
└── widgets/              # Reusable UI components (TrackTile, MixBoxCard, MiniPlayer)
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (`>= 3.24.0`).
- Android Studio / VS Code with Flutter extensions.
- Android SDK or an active physical device/emulator.

### Setup & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/decibel.git
   cd decibel
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **(Optional) Configure Supabase Telemetry:**
   Copy `.env.json.example` to `.env.json` (which is git-ignored):
   ```bash
   cp .env.json.example .env.json
   ```
   Fill in your Supabase project URL and anon key, then run:
   ```bash
   flutter run --dart-define-from-file=.env.json
   ```

4. **Run directly:**
   ```bash
   flutter run
   ```

---

## 📦 Release & Distribution Policy

- **Legal Catalog Compliance**: Official releases, tags, and binary packages (`.apk`, `.aab`, `.ipa`) must only be compiled against authorized, licensed music providers or standard preview catalogs.
- **No Unofficial Extractors**: Do not bundle proprietary extractors, scraping logic, or unlicensed mirrors into release artifacts or public pull requests.

---

## 🔒 Privacy & Data Policy
Decibel is designed with an offline-first philosophy. Playback telemetry and preference learning are kept private to each install using anonymous authentication and Row Level Security (RLS). No personal identities, emails, or search queries are collected. Review [`PRIVACY_POLICY.md`](./PRIVACY_POLICY.md) and [`DECIBEL_DATA_COLLECTION.md`](./DECIBEL_DATA_COLLECTION.md) for full details.

---

## 📄 License
This project is open-source and intended for educational, research, and personal use with licensed audio providers.
