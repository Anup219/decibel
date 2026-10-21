import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/player_controller.dart';
import '../models/track.dart';
import '../theme/decibel_colors.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onMoreTap;

  const TrackTile({
    super.key,
    required this.track,
    this.isCurrent = false,
    this.isPlaying = false,
    this.isLiked = false,
    required this.onTap,
    this.onLikeToggle,
    this.onMoreTap,
  });

  void _showAddToPlaylistSheet(BuildContext context, PlayerController controller, Track track) {
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
                  style: TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.add, color: DecibelColors.green),
                title: const Text('New playlist',
                    style: TextStyle(color: DecibelColors.green, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistDialog(context, controller, track);
                },
              ),
              if (playlists.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, i) {
                      final pl = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music, color: Colors.white70),
                        title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${pl.trackCount} songs',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        onTap: () {
                          controller.addTrackToPlaylist(pl.id, track);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${track.title}" to ${pl.name}'),
                              backgroundColor: DecibelColors.card,
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

  void _showCreatePlaylistDialog(BuildContext context, PlayerController controller, Track track) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: DecibelColors.card,
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: DecibelColors.green)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: DecibelColors.green, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DecibelColors.green),
            onPressed: () async {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                await controller.createPlaylist(name);
                if (controller.playlists.isNotEmpty) {
                  await controller.addTrackToPlaylist(controller.playlists.first.id, track);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created "$name" and added "${track.title}"'),
                      backgroundColor: DecibelColors.card,
                    ),
                  );
                }
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTrackOptionsBottomSheet(BuildContext context, PlayerController controller, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DecibelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDownloaded = controller.isTrackDownloaded(track.id);

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
              // Track header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: track.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: track.artworkUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: DecibelColors.lavender),
                                errorWidget: (_, __, ___) => Container(color: DecibelColors.lavender),
                              )
                            : Container(color: DecibelColors.lavender),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              fontFamily: DecibelTypography.headingFont,
                              color: DecibelColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              color: DecibelColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.black12),

              // 1. Add to Queue
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: DecibelColors.navy),
                title: Text('Add to queue', style: TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary)),
                onTap: () {
                  controller.addToQueue(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added "${track.title}" to queue'),
                      backgroundColor: DecibelColors.navy,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // 2. Play Next
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: DecibelColors.navy),
                title: Text('Play next', style: TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary)),
                onTap: () {
                  controller.playNext(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${track.title}" will play next'),
                      backgroundColor: DecibelColors.navy,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // 3. Add to Playlist
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: DecibelColors.navy),
                title: Text('Add to playlist', style: TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistSheet(context, controller, track);
                },
              ),

              // 4. Download Offline
              ListTile(
                leading: Icon(
                  isDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
                  color: isDownloaded ? DecibelColors.purple : DecibelColors.navy,
                ),
                title: Text(
                  isDownloaded ? 'Remove from downloads' : 'Download song offline',
                  style: const TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!isDownloaded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading "${track.title}" in 320kbps audio...'),
                        backgroundColor: DecibelColors.surface,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  final downloaded = await controller.toggleDownload(track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          downloaded
                              ? 'Downloaded "${track.title}" for offline playback'
                              : (isDownloaded
                                  ? 'Removed "${track.title}" from downloads'
                                  : 'Could not download "${track.title}". Check connection.'),
                        ),
                        backgroundColor: downloaded ? DecibelColors.purple : DecibelColors.card,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),

              // 5. Share
              ListTile(
                leading: const Icon(Icons.share_rounded, color: DecibelColors.navy),
                title: Text('Share song', style: TextStyle(fontFamily: DecibelTypography.headingFont, color: DecibelColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                    'Listening to "${track.title}" by ${track.artist} on DECIBEL!\n${track.streamUrl}',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final isLikedEffective = isLiked || controller.likedTrackIds.contains(track.id);
    final isCurrentEffective = isCurrent || controller.currentTrack?.id == track.id;
    final isPlayingEffective = isPlaying || (isCurrentEffective && controller.isPlaying);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: track.artworkUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.artworkUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: DecibelColors.lavender,
                            child: const Icon(Icons.music_note, color: DecibelColors.purple, size: 20),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: DecibelColors.lavender,
                            child: const Icon(Icons.music_note, color: DecibelColors.purple, size: 20),
                          ),
                        )
                      : Container(
                          color: DecibelColors.lavender,
                          child: const Icon(Icons.music_note, color: DecibelColors.purple, size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        fontFamily: DecibelTypography.headingFont,
                        color: isCurrentEffective ? DecibelColors.purple : DecibelColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${track.artist}${track.album.isNotEmpty ? " • ${track.album}" : ""}',
                      style: const TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        color: DecibelColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Equalizer icon when currently playing
              if (isPlayingEffective)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.graphic_eq, color: DecibelColors.purple, size: 20),
                ),

              // Heart (Like) button on the left of the 3 dots
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                splashRadius: 20,
                icon: Icon(
                  isLikedEffective ? Icons.favorite : Icons.favorite_border_rounded,
                  color: isLikedEffective ? DecibelColors.heartPink : DecibelColors.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  if (onLikeToggle != null) {
                    onLikeToggle!();
                  } else {
                    controller.toggleLike(track);
                  }
                },
              ),

              // 3 dots button on the far right
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                splashRadius: 20,
                icon: const Icon(Icons.more_horiz_rounded, color: DecibelColors.textSecondary, size: 20),
                onPressed: () {
                  if (onMoreTap != null) {
                    onMoreTap!();
                  } else {
                    _showTrackOptionsBottomSheet(context, controller, track);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
