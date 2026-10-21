import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../theme/decibel_colors.dart';

class SyncedLyricsScreen extends StatefulWidget {
  const SyncedLyricsScreen({super.key});

  @override
  State<SyncedLyricsScreen> createState() => _SyncedLyricsScreenState();
}

class _SyncedLyricsScreenState extends State<SyncedLyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalLines) {
    if (!_scrollController.hasClients || index < 0 || index >= totalLines) return;
    const itemHeight = 64.0;
    final targetOffset = (index * itemHeight) - 180.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final track = controller.currentTrack;

    if (track == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: DecibelColors.nowPlayingGradient),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text('No track playing', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lyrics = track.lyrics;
    final currentMs = controller.currentPosition.inMilliseconds;

    int activeIndex = -1;
    for (int i = 0; i < lyrics.length; i++) {
      if (lyrics[i].timeMs <= currentMs) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != _lastActiveIndex && activeIndex != -1) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeIndex, lyrics.length);
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: DecibelColors.nowPlayingGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontFamily: DecibelTypography.headingFont,
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artist,
                      style: const TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                centerTitle: true,
              ),

              // Lyrics list
              Expanded(
                child: lyrics.isEmpty
                    ? const Center(
                        child: Text(
                          'No synced lyrics found for this track',
                          style: TextStyle(
                            fontFamily: DecibelTypography.bodyFont,
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        itemCount: lyrics.length,
                        itemBuilder: (context, i) {
                          final line = lyrics[i];
                          final isActive = i == activeIndex;

                          return GestureDetector(
                            onTap: () {
                              controller.seekTo(Duration(milliseconds: line.timeMs));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  fontFamily: DecibelTypography.headingFont,
                                  color: isActive ? Colors.white : Colors.white38,
                                  fontSize: isActive ? 24 : 18,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
