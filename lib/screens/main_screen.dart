import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../theme/decibel_colors.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/mini_player.dart';
import '../widgets/decibel_components.dart';
import 'downloads_screen.dart';
import 'fullscreen_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConsentDialog.checkAndShow(context);
    });
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    DownloadsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreenPlayer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FullscreenPlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final hasActiveTrack = controller.currentTrack != null;

    return Scaffold(
      backgroundColor: DecibelColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: DecibelColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Sliding Screen Views
              PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: _screens,
              ),

              // Floating Controls Bar (MiniPlayer + Floating BottomNav)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasActiveTrack)
                        MiniPlayer(
                          onTap: _openFullscreenPlayer,
                        ),
                      SonoraBottomNavBar(
                        currentIndex: _currentIndex,
                        onTabSelected: (index) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
