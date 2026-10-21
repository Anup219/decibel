import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/player_controller.dart';
import '../models/track.dart';
import '../services/decibel_mix_engine.dart';
import '../theme/decibel_colors.dart';
import '../widgets/decibel_components.dart';
import 'queue_bottom_sheet.dart';
import 'synced_lyrics_screen.dart';

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showShareOptions(Track track) {
    // Note: Do NOT share track.streamUrl — it's a temporary signed URL that expires quickly.
    final text = '🎵 Listening to "${track.title}" by ${track.artist} on DECIBEL!\nFeel every note.';
    Share.share(text);
  }


  void _showAddToPlaylistDialog(BuildContext context, PlayerController controller, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final playlists = controller.playlists;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Add to Playlist',
                  style: TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    color: DecibelColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No custom playlists created yet',
                    style: TextStyle(color: DecibelColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, i) {
                      final pl = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play, color: DecibelColors.purple),
                        title: Text(pl.name,
                            style: const TextStyle(
                                fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary)),
                        subtitle: Text('${pl.trackCount} songs',
                            style: const TextStyle(color: DecibelColors.textSecondary)),
                        onTap: () {
                          controller.addTrackToPlaylist(pl.id, track);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${track.title}" to ${pl.name}'),
                              backgroundColor: DecibelColors.navy,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final track = controller.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: DecibelColors.navy,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('No song playing', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final isLiked = controller.likedTrackIds.contains(track.id);
    final isDownloaded = controller.isTrackDownloaded(track.id);
    final isDownloading = controller.isDownloading(track.id);
    final isPlaying = controller.isPlaying;

    final durationMs = controller.duration.inMilliseconds > 0
        ? controller.duration.inMilliseconds
        : track.durationMs;
    final positionMs = controller.currentPosition.inMilliseconds;

    final progress = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    final currentPosDisplay = _isDraggingSlider
        ? Duration(milliseconds: (_dragValue * durationMs).toInt())
        : controller.currentPosition;
    final totalDurationDisplay = Duration(milliseconds: durationMs);

    final queue = controller.queue;
    final currentIndex = controller.currentQueueIndex;
    final hasNext = currentIndex + 1 < queue.length;
    final nextTrack = hasNext ? queue[currentIndex + 1] : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: DecibelColors.nowPlayingGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              // Responsive artwork sizing: adapts smoothly on 390x844pt and other device sizes
              final artworkHeight = (availableHeight * 0.35).clamp(210.0, 275.0);
              final isCompact = availableHeight < 680;

              return Column(
                children: [
                  // 1. Header: Back/down arrow, playlist information, overflow menu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'PLAYING FROM',
                              style: TextStyle(
                                fontFamily: DecibelTypography.bodyFont,
                                color: Colors.white70,
                                fontSize: 7.5,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album.isNotEmpty ? track.album : 'My Favorites',
                              style: const TextStyle(
                                fontFamily: DecibelTypography.headingFont,
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                          color: DecibelColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (val) {
                            if (val == 'recommend_more') {
                              DecibelMixEngine.recordTuneMyTaste(track, recommendMore: true);
                            } else if (val == 'share') {
                              _showShareOptions(track);
                            } else if (val == 'add_to_pl') {
                              _showAddToPlaylistDialog(context, controller, track);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'recommend_more',
                              child: Row(
                                children: [
                                  Icon(Icons.thumb_up_alt_outlined, color: DecibelColors.purple, size: 20),
                                  SizedBox(width: 12),
                                  Text('Tune more like this', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add_to_pl',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text('Share Track', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Player Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          if (!isCompact) const Spacer(flex: 1),

                          // 2. Artwork: Album or playlist card
                          Container(
                            height: artworkHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                SonoraArtwork(
                                  urlOrName: track.artworkUrl.isNotEmpty ? track.artworkUrl : 'jellyfish',
                                  borderRadius: 24,
                                ),
                                // Ambient bottom shading for legibility
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.15),
                                        Colors.black.withOpacity(0.75),
                                      ],
                                      stops: const [0.4, 0.7, 1.0],
                                    ),
                                  ),
                                ),
                                // Embedded Title & Artist
                                Positioned(
                                  left: 20,
                                  bottom: 20,
                                  right: 64,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.title,
                                        style: const TextStyle(
                                          fontFamily: DecibelTypography.headingFont,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 24,
                                          color: Colors.white,
                                          height: 1.1,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        track.artist,
                                        style: const TextStyle(
                                          fontFamily: DecibelTypography.bodyFont,
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Heart icon
                                Positioned(
                                  right: 18,
                                  bottom: 22,
                                  child: GestureDetector(
                                    onTap: () => controller.toggleLike(track),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                      child: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                                        color: isLiked ? DecibelColors.heartPink : Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Target approximately 28–36 px between the bottom of the album card and waveform
                          SizedBox(height: isCompact ? 24 : 32),

                          // 3. Progress: Waveform and timestamps
                          SonoraWaveformVisualizer(
                            progress: _isDraggingSlider ? _dragValue : progress,
                            onSeek: (newP) {
                              final targetMs = (newP * durationMs).toInt();
                              controller.seekTo(Duration(milliseconds: targetMs));
                            },
                          ),

                          // Elapsed and remaining time labels directly below waveform with 12–16 px spacing
                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(currentPosDisplay),
                                style: const TextStyle(
                                  fontFamily: DecibelTypography.bodyFont,
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatDuration(totalDurationDisplay),
                                style: const TextStyle(
                                  fontFamily: DecibelTypography.bodyFont,
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          // Aim for approximately 24–32 px between time-label row and primary controls
                          SizedBox(height: isCompact ? 20 : 28),

                          // 4. Playback: Primary controls followed by secondary controls
                          // Primary Playback Controls Row (76-84px circular Play/Pause, balanced icons, vertically aligned)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Shuffle
                              IconButton(
                                iconSize: 22,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: controller.isShuffle ? DecibelColors.purpleLight : Colors.white70,
                                ),
                                onPressed: controller.toggleShuffle,
                              ),

                              const SizedBox(width: 14),

                              // Previous
                              IconButton(
                                iconSize: 34,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                                onPressed: controller.skipPrevious,
                              ),

                              const SizedBox(width: 18),

                              // Circular Play/Pause button (80px, in 76-84px range, centered horizontally)
                              GestureDetector(
                                onTap: controller.togglePlayPause,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF27218B).withOpacity(0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: DecibelColors.navy,
                                    size: 42,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 18),

                              // Next
                              IconButton(
                                iconSize: 34,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                                onPressed: controller.skipNext,
                              ),

                              const SizedBox(width: 14),

                              // Repeat Mode
                              IconButton(
                                iconSize: 22,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                icon: Icon(
                                  controller.repeatMode == DecibelRepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  color: controller.repeatMode != DecibelRepeatMode.off
                                      ? DecibelColors.purpleLight
                                      : Colors.white70,
                                ),
                                onPressed: controller.cycleRepeatMode,
                              ),
                            ],
                          ),

                          // Keep approximately 24–32 px between primary playback row and secondary controls
                          SizedBox(height: isCompact ? 18 : 26),

                          // Secondary Controls Toolbar (EQ, Cast, Lyrics, Queue distributed evenly across screen)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 22),
                                  tooltip: 'Equalizer',
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('DECIBEL Lossless 32-bit DSP Active'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.devices_rounded, color: Colors.white70, size: 22),
                                  tooltip: 'Cast / Audio Devices',
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: isDownloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: DecibelColors.purpleLight,
                                          ),
                                        )
                                      : Icon(
                                          isDownloaded
                                              ? Icons.download_done_rounded
                                              : Icons.download_for_offline_outlined,
                                          color: isDownloaded
                                              ? DecibelColors.purpleLight
                                              : Colors.white70,
                                          size: 22,
                                        ),
                                  tooltip: isDownloaded ? 'Downloaded' : 'Download for offline',
                                  onPressed: isDownloading
                                      ? null
                                      : () async {
                                          final success = await controller.toggleDownload(track);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Saved "${track.title}" for offline playback'
                                                      : 'Removed "${track.title}" from downloads',
                                                ),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 22),
                                  tooltip: 'Synced Lyrics',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SyncedLyricsScreen()),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 22),
                                  tooltip: 'Queue',
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      builder: (_) => const QueueBottomSheet(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Flexible spacer for remaining vertical space before Up Next card
                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),

                  // 5. Queue: Up Next card anchored toward the bottom
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => const QueueBottomSheet(),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            const Color(0xFFD7C8E7).withOpacity(0.18),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'UP NEXT',
                                style: TextStyle(
                                  fontFamily: DecibelTypography.headingFont,
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '${queue.length} songs',
                                style: const TextStyle(
                                  fontFamily: DecibelTypography.bodyFont,
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SonoraArtwork(
                                urlOrName: nextTrack?.artworkUrl.isNotEmpty == true
                                    ? nextTrack!.artworkUrl
                                    : 'be-alright',
                                width: 38,
                                height: 38,
                                borderRadius: 8,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      nextTrack?.title ?? 'Be Alright',
                                      style: const TextStyle(
                                        fontFamily: DecibelTypography.headingFont,
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      nextTrack?.artist ?? 'Dean Lewis',
                                      style: const TextStyle(
                                        fontFamily: DecibelTypography.bodyFont,
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.more_vert, color: Colors.white70, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
