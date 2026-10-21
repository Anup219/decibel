import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../theme/decibel_colors.dart';
import 'marquee_text.dart';
import 'decibel_components.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final track = controller.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final isLiked = controller.likedTrackIds.contains(track.id);
    final progress = controller.duration.inMilliseconds > 0
        ? (controller.currentPosition.inMilliseconds / controller.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: DecibelColors.miniPlayerGradient,
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
          boxShadow: DecibelColors.floatingShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  // Artwork
                  SonoraArtwork(
                    urlOrName: track.artworkUrl.isNotEmpty ? track.artworkUrl : 'jellyfish',
                    width: 38,
                    height: 38,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 10),

                  // Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeText(
                          text: track.title,
                          style: const TextStyle(
                            fontFamily: DecibelTypography.headingFont,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Favorite
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                      color: isLiked ? DecibelColors.heartPink : Colors.white70,
                      size: 19,
                    ),
                    onPressed: () => controller.toggleLike(track),
                  ),

                  // Play / Pause
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    icon: Icon(
                      controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: controller.togglePlayPause,
                  ),

                  // Skip Next
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: controller.skipNext,
                  ),
                ],
              ),
            ),

            // Thin progress indicator
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 2.0,
            ),
          ],
        ),
      ),
    );
  }
}
