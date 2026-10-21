import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import '../theme/decibel_colors.dart';

/// User lettermark avatar widget that dynamically renders the first letter of their custom name
class SonoraUserAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;

  const SonoraUserAvatar({
    super.key,
    this.size = 36,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: UserProfileService.userNameNotifier,
      builder: (context, _, __) {
        final letter = UserProfileService.avatarLetter;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: DecibelColors.activePillGradient,
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: DecibelColors.purple.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: DecibelTypography.headingFont,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.44,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Universal artwork loader for both Sonora local webp assets and remote network urls
class SonoraArtwork extends StatelessWidget {
  final String urlOrName;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  const SonoraArtwork({
    super.key,
    required this.urlOrName,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final clean = urlOrName.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      child = CachedNetworkImage(
        imageUrl: clean,
        fit: fit,
        placeholder: (_, __) => Container(color: DecibelColors.lavender),
        errorWidget: (_, __, ___) => _fallback(),
      );
    } else if (clean.isNotEmpty) {
      final assetPath = clean.contains('/')
          ? clean
          : (clean.endsWith('.webp') || clean.endsWith('.png')
              ? 'assets/ui/$clean'
              : 'assets/ui/$clean.webp');
      child = Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      child = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: DecibelColors.lavender,
      alignment: Alignment.center,
      child: const Icon(
        Icons.music_note_rounded,
        color: DecibelColors.purple,
        size: 20,
      ),
    );
  }
}

/// Standard Sonora Section Heading with optional "See all" action
class SonoraSectionHeading extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SonoraSectionHeading({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: DecibelTypography.sectionHeading),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See all', style: DecibelTypography.seeAll),
            ),
        ],
      ),
    );
  }
}

/// "Sunrise Acoustic" curated hero banner with multi-layer sunset gradient & waves
class SonoraSunriseHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final LinearGradient? gradient;
  final VoidCallback onPlay;

  const SonoraSunriseHeroCard({
    super.key,
    this.eyebrow = 'CURATED FOR YOU',
    this.title = 'Sunrise\nAcoustic',
    this.description = 'Warm guitars to start\nyour day right.',
    this.gradient,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient ?? DecibelColors.sunriseGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF322555).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative sweeping sunset waves
          Positioned(
            top: -120,
            left: -40,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(120),
                  gradient: const LinearGradient(
                    colors: [Color(0x99423399), Color(0xAAE677A7)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: -20,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 240,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: const LinearGradient(
                    colors: [Color(0x88A51C7D), Color(0xAAFFB579)],
                  ),
                ),
              ),
            ),
          ),

          // Bell / Star icon on top right
          Positioned(
            top: 14,
            right: 56,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 18,
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: DecibelTypography.eyebrow),
                    const SizedBox(height: 5),
                    Text(title, style: DecibelTypography.heroTitle),
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: DecibelTypography.bodyFont,
                    fontSize: 9.5,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Play button
          Positioned(
            right: 18,
            bottom: 20,
            child: GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF27218B).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFBE3A3B),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "For your moment" pastel card item
class SonoraMomentCard extends StatelessWidget {
  final String title;
  final String detail;
  final List<Color> gradientColors;
  final Color? borderColor;
  final VoidCallback onTap;

  const SonoraMomentCard({
    super.key,
    required this.title,
    required this.detail,
    required this.gradientColors,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 95,
        height: 64,
        margin: const EdgeInsets.only(right: 9),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Watermark icon
            Positioned(
              right: -6,
              bottom: -6,
              child: Opacity(
                opacity: 0.12,
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontFamily: DecibelTypography.bodyFont,
                    fontSize: 8.5,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "New & Notable" album card
class SonoraAlbumCard extends StatelessWidget {
  final String artwork;
  final String title;
  final String artist;
  final bool isNew;
  final VoidCallback onTap;

  const SonoraAlbumCard({
    super.key,
    required this.artwork,
    required this.title,
    required this.artist,
    this.isNew = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 98,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                SonoraArtwork(
                  urlOrName: artwork,
                  width: 98,
                  height: 94,
                  borderRadius: 11,
                ),
                if (isNew)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9A7DF4).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontFamily: DecibelTypography.bodyFont,
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: DecibelTypography.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              artist,
              style: DecibelTypography.bodyMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Because you listened" recommendation tile
class SonoraRecommendationTile extends StatelessWidget {
  final String artwork;
  final String title;
  final String artist;
  final Widget? trailingSecondary;
  final VoidCallback onPlay;

  const SonoraRecommendationTile({
    super.key,
    required this.artwork,
    required this.title,
    required this.artist,
    this.trailingSecondary,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DecibelColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: DecibelColors.cardShadow,
      ),
      child: Row(
        children: [
          SonoraArtwork(
            urlOrName: artwork,
            width: 40,
            height: 40,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: DecibelColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  artist.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: DecibelTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: DecibelColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailingSecondary != null) ...[
            trailingSecondary!,
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DecibelColors.elevated,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 109-bar interactive dynamic soundwave scrubber
class SonoraWaveformVisualizer extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Function(double newProgress)? onSeek;

  const SonoraWaveformVisualizer({
    super.key,
    required this.progress,
    this.onSeek,
  });

  static const int totalBars = 90;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barWidth = (totalWidth / totalBars).clamp(1.5, 3.5);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            if (onSeek != null) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(details.globalPosition);
                final p = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                onSeek!(p);
              }
            }
          },
          onTapDown: (details) {
            if (onSeek != null) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(details.globalPosition);
                final p = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                onSeek!(p);
              }
            }
          },
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(totalBars, (i) {
                // Waveform envelope formula
                final envelope = 5.0 +
                    22.0 * math.exp(-math.pow((i - (totalBars * 0.28)) / 12.0, 2)) +
                    20.0 * math.exp(-math.pow((i - (totalBars * 0.74)) / 12.0, 2));
                final height = (3.0 + envelope * (0.3 + math.sin(i * 2.37).abs() * 0.95))
                    .clamp(4.0, 44.0);

                final isElapsed = (i / totalBars) <= progress;

                return Container(
                  width: barWidth - 0.6,
                  height: height,
                  decoration: BoxDecoration(
                    color: isElapsed ? Colors.white : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

/// Category grid card for Search (Genres, Moods, Decades, etc.)
class SonoraCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const SonoraCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 69,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Translucent musical watermark
            Positioned(
              top: 0,
              right: 2,
              child: Text(
                '♪',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            // Outlined category icon
            Positioned(
              bottom: -2,
              right: 6,
              child: Icon(
                icon,
                size: 32,
                color: Colors.white.withOpacity(0.45),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontFamily: DecibelTypography.headingFont,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trending ranked search tile (01 to 04)
class SonoraTrendingTile extends StatelessWidget {
  final int rank;
  final String artwork;
  final String title;
  final String artist;
  final VoidCallback onTap;

  const SonoraTrendingTile({
    super.key,
    required this.rank,
    required this.artwork,
    required this.title,
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rankStr = rank < 10 ? '0$rank' : '$rank';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                rankStr,
                style: const TextStyle(
                  fontFamily: DecibelTypography.bodyFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: DecibelColors.textSecondary,
                ),
              ),
            ),
            SonoraArtwork(
              urlOrName: artwork,
              width: 42,
              height: 42,
              borderRadius: 9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: DecibelTypography.headingFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: DecibelColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: DecibelTypography.bodyMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DecibelColors.elevated,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: DecibelColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating glassmorphic bottom navigation bar matching Sonora
class SonoraBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const SonoraBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: DecibelColors.bottomNavGradient,
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
        boxShadow: DecibelColors.floatingShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, 'Discover', Icons.home_rounded, Icons.home_outlined),
          _navItem(1, 'Search', Icons.search_rounded, Icons.search_rounded),
          _navItem(2, 'Library', Icons.library_music_rounded, Icons.library_music_outlined),
          _navItem(3, 'Profile', Icons.person_rounded, Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData activeIcon, IconData inactiveIcon) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected ? const Color(0xFF272340) : Colors.transparent,
            border: isSelected
                ? Border.all(color: Colors.white.withOpacity(0.08), width: 1.0)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 20,
                color: isSelected ? DecibelColors.purpleLight : DecibelColors.textSubtle,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: DecibelTypography.bodyFont,
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? DecibelColors.purpleLight : DecibelColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
