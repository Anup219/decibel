import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/artist_preference_service.dart';
import '../services/decibel_mix_engine.dart';
import '../services/language_preference_service.dart';
import '../theme/decibel_colors.dart';
import 'main_screen.dart';

class IntroductionScreen extends StatefulWidget {
  final bool isEditingFromSettings;
  final VoidCallback? onComplete;

  const IntroductionScreen({
    super.key,
    this.isEditingFromSettings = false,
    this.onComplete,
  });

  @override
  State<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  int _currentStep = 0; // 0 = Languages, 1 = Artists
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedArtists = {};
  String _artistSearchQuery = '';
  Timer? _searchDebounce;
  List<ArtistInfo> _onlineSearchResults = [];
  bool _isSearchingOnline = false;

  @override
  void initState() {
    super.initState();
    _selectedLanguages.addAll(LanguagePreferenceService.preferredLanguages);
    if (_selectedLanguages.isEmpty) {
      _selectedLanguages.addAll(['Hindi', 'English']);
    }
    _selectedArtists.addAll(ArtistPreferenceService.favoriteArtists);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onArtistSearchChanged(String val) {
    final query = val.trim();
    _searchDebounce?.cancel();
    setState(() {
      _artistSearchQuery = query;
      if (query.isEmpty) {
        _onlineSearchResults = [];
        _isSearchingOnline = false;
      } else {
        _isSearchingOnline = true;
      }
    });

    if (query.isEmpty) return;

    _searchDebounce = Timer(const Duration(milliseconds: 320), () async {
      final results = await ArtistPreferenceService.searchOnlineArtists(query);
      if (mounted && _artistSearchQuery == query) {
        setState(() {
          _onlineSearchResults = results;
          _isSearchingOnline = false;
        });
      }
    });
  }

  void _toggleLanguage(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        if (_selectedLanguages.length > 1) {
          _selectedLanguages.remove(lang);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least 1 language'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        _selectedLanguages.add(lang);
      }
    });
  }

  void _toggleArtist(String artistName) {
    setState(() {
      if (_selectedArtists.contains(artistName)) {
        _selectedArtists.remove(artistName);
      } else {
        if (_selectedArtists.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can select up to 10 favorite artists'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedArtists.add(artistName);
      }
    });
  }

  Future<void> _finishIntroduction() async {
    final langs = _selectedLanguages.toList();
    await LanguagePreferenceService.savePreferences(langs);
    final artists = _selectedArtists.toList();
    await ArtistPreferenceService.saveFavoriteArtists(artists);
    await DecibelMixEngine.refreshMixes(force: true);

    if (!mounted) return;

    if (widget.isEditingFromSettings) {
      widget.onComplete?.call();
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DecibelColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: DecibelColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation / Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _stepIndicator(0, 'Languages'),
                        const SizedBox(width: 8),
                        Container(width: 16, height: 1.5, color: DecibelColors.purple.withOpacity(0.3)),
                        const SizedBox(width: 8),
                        _stepIndicator(1, 'Artists'),
                      ],
                    ),
                    if (!widget.isEditingFromSettings)
                      TextButton(
                        onPressed: _finishIntroduction,
                        child: const Text('Skip', style: TextStyle(color: DecibelColors.textSecondary)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: DecibelColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
              ),

              // Step Content
              Expanded(
                child: _currentStep == 0 ? _buildLanguagesStep() : _buildArtistsStep(),
              ),

              // Bottom Continue / Finish Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DecibelColors.surface,
                  boxShadow: DecibelColors.cardShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentStep == 0) {
                        setState(() => _currentStep = 1);
                      } else {
                        _finishIntroduction();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DecibelColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentStep == 0
                          ? 'Next: Choose Artists (${_selectedLanguages.length} languages)'
                          : 'Done & Start Listening (${_selectedArtists.length}/10 selected)',
                      style: const TextStyle(
                        fontFamily: DecibelTypography.headingFont,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? DecibelColors.purple
                : (isDone ? DecibelColors.purple.withOpacity(0.25) : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            '${stepIndex + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : DecibelColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: DecibelTypography.bodyFont,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? DecibelColors.purple : DecibelColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What languages do you listen to?',
            style: DecibelTypography.screenTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'We will prioritize recommendations, daily mixes, and top charts in your chosen languages.',
            style: TextStyle(
              fontFamily: DecibelTypography.bodyFont,
              color: DecibelColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: LanguagePreferenceService.supportedLanguages.map((option) {
              final isSelected = _selectedLanguages.contains(option.englishName);
              return GestureDetector(
                onTap: () => _toggleLanguage(option.englishName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: isSelected ? DecibelColors.activePillGradient : null,
                    color: isSelected ? null : DecibelColors.card,
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white12,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? DecibelColors.purple.withOpacity(0.25)
                            : Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.englishName,
                        style: TextStyle(
                          fontFamily: DecibelTypography.headingFont,
                          color: isSelected ? Colors.white : DecibelColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.nativeName,
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : DecibelColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsStep() {
    final languageFilteredArtists = ArtistPreferenceService.catalog
        .where((artist) => _selectedLanguages.contains(artist.language))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your favorite artists', style: DecibelTypography.screenTitle),
              const SizedBox(height: 6),
              Text(
                'Select up to 10 artists. We use this to curate your Artist Mixes and radio queue.',
                style: TextStyle(
                  fontFamily: DecibelTypography.bodyFont,
                  color: DecibelColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              // Search input
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: DecibelColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: DecibelColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: _onArtistSearchChanged,
                        style: const TextStyle(color: DecibelColors.textPrimary, fontSize: 13),
                        cursorColor: DecibelColors.purple,
                        decoration: const InputDecoration(
                          hintText: 'Search for any artist worldwide...',
                          hintStyle: TextStyle(color: DecibelColors.textSecondary, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.8,
            ),
            itemCount: _artistSearchQuery.isNotEmpty
                ? _onlineSearchResults.length
                : languageFilteredArtists.length,
            itemBuilder: (context, index) {
              final artist = _artistSearchQuery.isNotEmpty
                  ? _onlineSearchResults[index]
                  : languageFilteredArtists[index];
              final isSelected = _selectedArtists.contains(artist.name);

              return GestureDetector(
                onTap: () => _toggleArtist(artist.name),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? DecibelColors.purple : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: artist.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: artist.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: DecibelColors.lavender),
                                    errorWidget: (_, __, ___) => Container(
                                      color: DecibelColors.lavender,
                                      child: const Icon(Icons.person, color: DecibelColors.purple),
                                    ),
                                  )
                                : Container(
                                    color: DecibelColors.lavender,
                                    child: const Icon(Icons.person, color: DecibelColors.purple),
                                  ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: DecibelColors.purple,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artist.name,
                      style: TextStyle(
                        fontFamily: DecibelTypography.headingFont,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? DecibelColors.purple : DecibelColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
