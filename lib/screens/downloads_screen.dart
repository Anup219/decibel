import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../theme/decibel_colors.dart';
import '../widgets/track_tile.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with AutomaticKeepAliveClientMixin {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Downloaded', 'Auto-Cached', 'Offline Only'];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<PlayerController>();
    final downloadedTracks = controller.downloadedTracks;
    final cachedTracks = _selectedFilterIndex == 1 ? controller.likedTracks : downloadedTracks;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Downloads', style: DecibelTypography.screenTitle),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DecibelColors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_done_rounded, color: DecibelColors.purple, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Ready Offline',
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            color: DecibelColors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, i) {
                  final isSelected = _selectedFilterIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilterIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: isSelected ? DecibelColors.activePillGradient : null,
                          color: isSelected ? null : DecibelColors.card,
                          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _filters[i],
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : DecibelColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: cachedTracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: DecibelColors.card,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Icon(
                                Icons.download_for_offline_outlined,
                                color: DecibelColors.green,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _selectedFilterIndex == 1 ? 'No cached songs' : 'No offline songs downloaded',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFilterIndex == 1
                                  ? 'Like or play songs to automatically cache high-bitrate audio for offline listening.'
                                  : 'Tap the download icon in the full player to save songs for offline listening anywhere.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: DecibelColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: cachedTracks.length,
                      itemBuilder: (context, index) {
                        final track = cachedTracks[index];
                        final isPlaying = controller.currentTrack?.id == track.id && controller.isPlaying;

                        return TrackTile(
                          track: track,
                          isPlaying: isPlaying,
                          onTap: () => controller.playTrack(track, newQueue: cachedTracks),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
