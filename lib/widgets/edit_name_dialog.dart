import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import '../theme/decibel_colors.dart';

class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const EditNameDialog(),
    );
  }

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: UserProfileService.userName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DecibelColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'What should we call you?',
        style: TextStyle(
          fontFamily: DecibelTypography.headingFont,
          fontWeight: FontWeight.bold,
          color: DecibelColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalize your greeting and profile icon lettermark:',
            style: TextStyle(
              fontFamily: DecibelTypography.bodyFont,
              color: DecibelColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontFamily: DecibelTypography.headingFont,
              color: DecibelColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            cursorColor: DecibelColors.purple,
            decoration: InputDecoration(
              hintText: 'Enter your name (e.g. Alex)',
              hintStyle: TextStyle(
                fontFamily: DecibelTypography.bodyFont,
                color: DecibelColors.textSubtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: DecibelColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DecibelColors.purple, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: DecibelTypography.bodyFont,
              color: DecibelColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: DecibelColors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () {
            final name = _controller.text.trim();
            UserProfileService.setUserName(name);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
