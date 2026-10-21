import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../models/mix_box.dart';
import '../models/track.dart';
import '../services/artist_preference_service.dart';
import '../services/music_search_service.dart';
import '../theme/decibel_colors.dart';
import '../widgets/import_playlist_modal.dart';
import '../widgets/decibel_components.dart';
import '../widgets/track_tile.dart';
import 'telemetry_debug_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with AutomaticKeepAliveClientMixin {
  int _activeChipIndex = 0;
  final List<String> _filterChips = ['Playlists', 'Albums', 'Artists', 'Downloaded'];

  @override
  bool get wantKeepAlive => true;



  void _showCreatePlaylistDialog(BuildContext context, PlayerController controller) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DecibelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Playlist',
            style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: DecibelColors.textPrimary),
              cursorColor: DecibelColors.purple,
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                hintStyle: TextStyle(color: DecibelColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: DecibelColors.purple)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ImportPlaylistModal.show(context);
              },
              icon: const Icon(Icons.sync_alt_rounded, size: 16, color: DecibelColors.purple),
              label: const Text(
                'Import from Spotify / Apple / URL',
                style: TextStyle(color: DecibelColors.purple, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: DecibelColors.purple.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: DecibelColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DecibelColors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                controller.createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }



  void _showRenamePlaylistDialog(BuildContext context, UserPlaylist pl, PlayerController controller) {
    final textController = TextEditingController(text: pl.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DecibelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Playlist',
            style: TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.bold, color: DecibelColors.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: DecibelColors.textPrimary),
          cursorColor: DecibelColors.purple,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: DecibelColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: DecibelColors.purple)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: DecibelColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DecibelColors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.renamePlaylist(pl.id, newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, UserPlaylist pl, PlayerController controller, {VoidCallback? onDeleted}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DecibelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${pl.name}"?',
            style: const TextStyle(fontFamily: DecibelTypography.headingFont, fontWeight: FontWeight.bold, color: DecibelColors.textPrimary)),
        content: const Text(
          'Are you sure you want to remove this playlist? This action cannot be undone.',
          style: TextStyle(color: DecibelColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: DecibelColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4D),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              controller.deletePlaylist(pl.id);
              Navigator.pop(ctx);
              if (onDeleted != null) onDeleted();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${pl.name}"'),
                  backgroundColor: DecibelColors.surface,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPlaylistDetail(BuildContext context, UserPlaylist pl, PlayerController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPl = controller.playlists.firstWhere(
            (p) => p.id == pl.id,
            orElse: () => pl,
          );

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
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: DecibelColors.lavender,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.queue_music_rounded, color: DecibelColors.purple, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPl.name,
                              style: const TextStyle(
                                fontFamily: DecibelTypography.headingFont,
                                color: DecibelColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currentPl.tracks.length} songs',
                              style: const TextStyle(color: DecibelColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (currentPl.tracks.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: DecibelColors.purple, size: 38),
                          onPressed: () {
                            controller.playQueue(currentPl.tracks);
                            Navigator.pop(ctx);
                          },
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: DecibelColors.textSecondary),
                        color: DecibelColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        onSelected: (val) {
                          if (val == 'rename') {
                            _showRenamePlaylistDialog(context, currentPl, controller);
                          } else if (val == 'delete') {
                            _confirmDeletePlaylist(context, currentPl, controller, onDeleted: () {
                              Navigator.pop(ctx);
                            });
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, color: DecibelColors.textSecondary, size: 18),
                                SizedBox(width: 8),
                                Text('Rename Playlist', style: TextStyle(color: DecibelColors.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 18),
                                SizedBox(width: 8),
                                Text('Delete Playlist', style: TextStyle(color: Color(0xFFFF5252), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: currentPl.tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No songs added to this playlist yet.',
                            style: TextStyle(color: DecibelColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: currentPl.tracks.length,
                          itemBuilder: (context, i) {
                            final track = currentPl.tracks[i];
                            final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;
                            return Row(
                              children: [
                                Expanded(
                                  child: TrackTile(
                                    track: track,
                                    isPlaying: isPlaying,
                                    onTap: () {
                                      controller.playTrack(track, newQueue: currentPl.tracks);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white30, size: 20),
                                  onPressed: () {
                                    controller.removeTrackFromPlaylist(currentPl.id, track.id);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLikedSongsDetail(BuildContext context, PlayerController controller) {
    final liked = controller.likedTracks;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: DecibelColors.likedSongsGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Liked Songs',
                          style: TextStyle(
                            fontFamily: DecibelTypography.headingFont,
                            color: DecibelColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${liked.length} songs',
                          style: const TextStyle(color: DecibelColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (liked.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: DecibelColors.purple, size: 38),
                      onPressed: () {
                        controller.playQueue(liked);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: liked.isEmpty
                  ? const Center(
                      child: Text(
                        'Songs you like will appear here.',
                        style: TextStyle(color: DecibelColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: liked.length,
                      itemBuilder: (context, i) {
                        final track = liked[i];
                        final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;
                        return TrackTile(
                          track: track,
                          isPlaying: isPlaying,
                          onTap: () {
                            controller.playTrack(track, newQueue: liked);
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
    final likedCount = controller.likedTracks.length;
    final playlists = controller.playlists;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with "Your Library" and circular "+" button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Library', style: DecibelTypography.screenTitle),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TelemetryDebugScreen()),
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: DecibelColors.purple.withOpacity(0.12),
                            border: Border.all(color: DecibelColors.purple.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: DecibelColors.purple, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ImportPlaylistModal.show(context),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            color: DecibelColors.purple.withOpacity(0.12),
                            border: Border.all(color: DecibelColors.purple.withOpacity(0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_alt_rounded, color: DecibelColors.purple, size: 15),
                              SizedBox(width: 5),
                              Text(
                                'Import',
                                style: TextStyle(
                                  fontFamily: DecibelTypography.bodyFont,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: DecibelColors.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showCreatePlaylistDialog(context, controller),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: DecibelColors.card,
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Icons.add_rounded, color: DecibelColors.textPrimary, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(_filterChips.length, (i) {
                  final isSelected = _activeChipIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeChipIndex = i),
                      child: Container(
                        height: 32,
                        margin: EdgeInsets.only(right: i == _filterChips.length - 1 ? 0 : 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: isSelected ? DecibelColors.activePillGradient : null,
                          color: isSelected ? null : DecibelColors.card,
                          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: DecibelColors.purple.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _filterChips[i],
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : DecibelColors.textSecondary,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Dynamic Library Items Feed
            Expanded(
              child: Builder(
                builder: (context) {
                  // 1. Albums Tab
                  if (_activeChipIndex == 1) {
                    final allTracks = [...controller.likedTracks, ...controller.downloadedTracks];
                    final uniqueAlbums = <String, Track>{};
                    for (final t in allTracks) {
                      if (t.album.isNotEmpty && !uniqueAlbums.containsKey(t.album)) {
                        uniqueAlbums[t.album] = t;
                      }
                    }

                    if (uniqueAlbums.isEmpty) {
                      return const Center(
                        child: Text(
                          'No saved albums yet.\nLike or download songs to see albums here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: DecibelColors.textSecondary, height: 1.4),
                        ),
                      );
                    }

                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      children: uniqueAlbums.values.map<Widget>((t) {
                        return _buildPlaylistRow(
                          artwork: t.artworkUrl,
                          title: t.album,
                          detail: t.artist,
                          onTap: () async {
                            final tracks = await MusicSearchService.searchSongs(t.album, limit: 15);
                            if (tracks.isNotEmpty && context.mounted) {
                              controller.playQueue(tracks);
                            }
                          },
                        );
                      }).toList(),
                    );
                  }

                  // 2. Artists Tab
                  if (_activeChipIndex == 2) {
                    final favArtists = ArtistPreferenceService.favoriteArtists;
                    if (favArtists.isEmpty) {
                      return const Center(
                        child: Text(
                          'No favorite artists selected yet.',
                          style: TextStyle(color: DecibelColors.textSecondary),
                        ),
                      );
                    }

                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      children: favArtists.map<Widget>((artist) {
                        return _buildPlaylistRow(
                          icon: Icons.person_rounded,
                          title: artist,
                          detail: 'Artist Mix',
                          onTap: () async {
                            final tracks = await MusicSearchService.searchSongs('$artist hits', limit: 15);
                            if (tracks.isNotEmpty && context.mounted) {
                              controller.playQueue(tracks);
                            }
                          },
                        );
                      }).toList(),
                    );
                  }

                  // 3. Downloaded Tab
                  if (_activeChipIndex == 3) {
                    final dls = controller.downloadedTracks;
                    if (dls.isEmpty) {
                      return const Center(
                        child: Text(
                          'No downloaded songs offline yet.',
                          style: TextStyle(color: DecibelColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: dls.length,
                      itemBuilder: (context, i) {
                        final track = dls[i];
                        final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;
                        return TrackTile(
                          track: track,
                          isPlaying: isPlaying,
                          onTap: () => controller.playTrack(track, newQueue: dls),
                        );
                      },
                    );
                  }

                  // 0. Default: Playlists Tab (Liked Songs + Downloads + Import + Pure User Playlists)
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    children: [
                      // Liked Songs Tile
                      _buildPlaylistRow(
                        isLikedTile: true,
                        title: 'Liked Songs',
                        detail: '$likedCount songs',
                        onTap: () => _showLikedSongsDetail(context, controller),
                      ),

                      // Downloaded Songs Tile
                      _buildPlaylistRow(
                        icon: Icons.cloud_done_rounded,
                        title: 'Downloaded Songs',
                        detail: '${controller.downloadedTracks.length} songs ready offline',
                        onTap: () {
                          setState(() => _activeChipIndex = 3);
                        },
                      ),

                      // Import Playlist from Spotify & Other Apps Tile
                      _buildPlaylistRow(
                        icon: Icons.sync_alt_rounded,
                        title: 'Import Playlist',
                        detail: 'Sync from Spotify, Apple Music, YouTube & links',
                        onTap: () => ImportPlaylistModal.show(context),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Colors.white10),
                      ),

                      // User Custom Playlists Section Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'YOUR PLAYLISTS',
                              style: TextStyle(
                                fontFamily: DecibelTypography.headingFont,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: DecibelColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${playlists.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: DecibelColors.textSubtle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (playlists.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DecibelColors.card,
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: const Icon(Icons.playlist_add_rounded, color: DecibelColors.textSecondary, size: 24),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No playlists yet',
                                  style: TextStyle(
                                    fontFamily: DecibelTypography.headingFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: DecibelColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap "+" above to create one or import from Spotify.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: DecibelTypography.bodyFont,
                                    fontSize: 11.5,
                                    color: DecibelColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...playlists.map((pl) => _buildPlaylistRow(
                              artwork: pl.imageUrl.isNotEmpty ? pl.imageUrl : null,
                              icon: Icons.queue_music_rounded,
                              title: pl.name,
                              detail: '${pl.trackCount} songs',
                              playlist: pl,
                              controller: controller,
                              onTap: () => _showPlaylistDetail(context, pl, controller),
                            )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistRow({
    bool isLikedTile = false,
    String? artwork,
    IconData? icon,
    required String title,
    required String detail,
    UserPlaylist? playlist,
    PlayerController? controller,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Artwork / Icon
            if (isLikedTile)
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: DecibelColors.likedSongsGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 26),
              )
            else if (artwork != null && artwork.isNotEmpty)
              SonoraArtwork(
                urlOrName: artwork,
                width: 54,
                height: 54,
                borderRadius: 10,
              )
            else
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DecibelColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Icon(icon ?? Icons.music_note_rounded, color: DecibelColors.purple, size: 26),
              ),

            const SizedBox(width: 14),

            // Title & Detail
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: DecibelTypography.headingFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: DecibelColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: DecibelTypography.bodyMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Three dots action button
            if (playlist != null && controller != null)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: DecibelColors.textSecondary,
                  size: 20,
                ),
                color: DecibelColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                onSelected: (val) {
                  if (val == 'play') {
                    if (playlist.tracks.isNotEmpty) {
                      controller.playQueue(playlist.tracks);
                    }
                  } else if (val == 'rename') {
                    _showRenamePlaylistDialog(context, playlist, controller);
                  } else if (val == 'delete') {
                    _confirmDeletePlaylist(context, playlist, controller);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, color: DecibelColors.purple, size: 20),
                        SizedBox(width: 8),
                        Text('Play', style: TextStyle(color: DecibelColors.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: DecibelColors.textSecondary, size: 18),
                        SizedBox(width: 8),
                        Text('Rename', style: TextStyle(color: DecibelColors.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 18),
                        SizedBox(width: 8),
                        Text('Delete Playlist', style: TextStyle(color: Color(0xFFFF5252), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6C6A78),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
