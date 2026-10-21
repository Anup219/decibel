import 'package:flutter/material.dart';
import '../services/decibel_mix_engine.dart';
import '../services/language_preference_service.dart';
import '../theme/decibel_colors.dart';

class LanguagePreferenceCard extends StatefulWidget {
  final VoidCallback? onSaved;
  final VoidCallback? onDismiss;
  final bool isModal;

  const LanguagePreferenceCard({
    super.key,
    this.onSaved,
    this.onDismiss,
    this.isModal = false,
  });

  static Future<void> showAsBottomSheet(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: DecibelColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: LanguagePreferenceCard(
                isModal: true,
                onSaved: () {
                  Navigator.pop(ctx);
                  onSaved?.call();
                },
                onDismiss: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<LanguagePreferenceCard> createState() => _LanguagePreferenceCardState();
}

class _LanguagePreferenceCardState extends State<LanguagePreferenceCard> {
  final Set<String> _selectedLanguages = {};

  @override
  void initState() {
    super.initState();
    _selectedLanguages.addAll(LanguagePreferenceService.preferredLanguages);
    // If empty, pre-select Hindi & English as convenient defaults
    if (_selectedLanguages.isEmpty) {
      _selectedLanguages.addAll(['Hindi', 'English']);
    }
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

  Future<void> _save() async {
    final list = _selectedLanguages.toList();
    await LanguagePreferenceService.savePreferences(list);
    await DecibelMixEngine.refreshForLanguagePreferenceChange();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved preferences! Tailoring music for ${list.join(", ")}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: DecibelColors.card,
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DecibelColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DecibelColors.purple.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: DecibelColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DecibelColors.purple.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: DecibelColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Music Languages',
                      style: TextStyle(
                        fontFamily: DecibelTypography.headingFont,
                        color: DecibelColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'We will only play & recommend songs in your choices',
                      style: TextStyle(
                        fontFamily: DecibelTypography.bodyFont,
                        color: DecibelColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isModal && widget.onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: DecibelColors.textSecondary, size: 20),
                  onPressed: widget.onDismiss,
                  tooltip: 'Dismiss for now',
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Flowing wrap of language chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LanguagePreferenceService.supportedLanguages.map((option) {
              final isSelected = _selectedLanguages.contains(option.englishName);
              return GestureDetector(
                onTap: () => _toggleLanguage(option.englishName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? DecibelColors.purple : DecibelColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white12,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? DecibelColors.purple.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        option.englishName,
                        style: TextStyle(
                          fontFamily: DecibelTypography.headingFont,
                          color: isSelected ? Colors.white : DecibelColors.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        option.nativeName,
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : DecibelColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DecibelColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Preferences (${_selectedLanguages.length})',
                    style: const TextStyle(
                      fontFamily: DecibelTypography.headingFont,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (!widget.isModal && widget.onDismiss != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'Later',
                    style: TextStyle(color: DecibelColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
