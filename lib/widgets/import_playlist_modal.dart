import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../services/playlist_import_service.dart';
import '../theme/decibel_colors.dart';
import 'decibel_components.dart';

class ImportPlaylistModal extends StatefulWidget {
  const ImportPlaylistModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ImportPlaylistModal(),
    );
  }

  @override
  State<ImportPlaylistModal> createState() => _ImportPlaylistModalState();
}

class _ImportPlaylistModalState extends State<ImportPlaylistModal> {
  final TextEditingController _inputController = TextEditingController();
  bool _isImporting = false;
  String _statusMessage = '';
  int _currentProgress = 0;
  int _totalProgress = 0;
  PlaylistImportResult? _result;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _inputController.text = data.text!.trim();
      });
    }
  }

  void _startImport() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isImporting = true;
      _statusMessage = 'Connecting & analyzing playlist...';
      _currentProgress = 0;
      _totalProgress = 0;
      _result = null;
    });

    try {
      final res = await PlaylistImportService.parseAndImport(
        text,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _currentProgress = current;
              _totalProgress = total;
              _statusMessage = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'Error importing: $e';
        });
      }
    }
  }

  void _saveAndFinish(PlayerController controller) async {
    final res = _result;
    if (res == null || res.matchedTracks.isEmpty) return;

    final pl = await controller.saveImportedPlaylist(
      res.playlistName,
      res.matchedTracks,
      coverUrl: res.coverUrl,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported "${pl.name}" with ${pl.trackCount} songs!'),
          backgroundColor: DecibelColors.purple,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: DecibelColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: DecibelColors.cardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: DecibelColors.activePillGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Playlist',
                            style: TextStyle(
                              fontFamily: DecibelTypography.headingFont,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: DecibelColors.textPrimary,
                            ),
                          ),
                          Text(
                            'From Spotify, Apple Music, YouTube or track text',
                            style: TextStyle(
                              fontFamily: DecibelTypography.bodyFont,
                              fontSize: 11.5,
                              color: DecibelColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: DecibelColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.black12),

              // Body: Input or Results
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _result == null
                      ? _buildInputSection()
                      : _buildResultSection(controller),
                ),
              ),

              // Bottom Actions
              if (_result != null && _result!.matchedTracks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _result = null;
                              _inputController.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DecibelColors.textSecondary,
                            side: const BorderSide(color: Colors.black12),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _saveAndFinish(controller),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DecibelColors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Save to Library (${_result!.matchedTracks.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App Badges
        Row(
          children: [
            _buildSourceBadge('Spotify', const Color(0xFF1DB954)),
            const SizedBox(width: 8),
            _buildSourceBadge('Apple Music', const Color(0xFFFA243C)),
            const SizedBox(width: 8),
            _buildSourceBadge('YouTube', const Color(0xFFFF0000)),
            const SizedBox(width: 8),
            _buildSourceBadge('Text List', const Color(0xFF6C6A78)),
          ],
        ),

        const SizedBox(height: 16),

        // Text input field
        Container(
          decoration: BoxDecoration(
            color: DecibelColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _inputController,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(fontSize: 13.5, color: DecibelColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Paste playlist link or songs list (e.g. https://open.spotify.com/playlist/...)',
                  hintStyle: TextStyle(fontSize: 12.5, color: DecibelColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste_rounded, size: 16, color: DecibelColors.purple),
                  label: const Text('Paste', style: TextStyle(color: DecibelColors.purple, fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress or Import Button
        if (_isImporting) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DecibelColors.lavender.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _totalProgress > 0 ? (_currentProgress / _totalProgress) : null,
                  backgroundColor: DecibelColors.lavender,
                  color: DecibelColors.purple,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                Text(
                  _totalProgress > 0
                      ? 'Matching song $_currentProgress of $_totalProgress...'
                      : 'Connecting to service...',
                  style: const TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: DecibelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 11,
                    color: DecibelColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: _startImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: DecibelColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_fix_high_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Import & Match 320kbps Audio',
                  style: TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        const Text(
          'DECIBEL will automatically extract every track name and match it with full official 320kbps streams for offline listening.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: DecibelColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DecibelTypography.bodyFont,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection(PlayerController controller) {
    final res = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Row(
          children: [
            SonoraArtwork(
              urlOrName: res.coverUrl.isNotEmpty
                  ? res.coverUrl
                  : (res.matchedTracks.isNotEmpty ? res.matchedTracks.first.artworkUrl : ''),
              width: 50,
              height: 50,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.playlistName,
                    style: const TextStyle(
                      fontFamily: DecibelTypography.headingFont,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: DecibelColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${res.matchedTracks.length} tracks matched (${res.unmatchedSongs.length} skipped)',
                    style: const TextStyle(fontSize: 12, color: DecibelColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Matched Songs Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),

        // List of matched tracks
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: res.matchedTracks.length.clamp(0, 15),
          itemBuilder: (context, i) {
            final t = res.matchedTracks[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SonoraArtwork(urlOrName: t.artworkUrl, width: 36, height: 36, borderRadius: 6),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                        ),
                        Text(t.artist, style: const TextStyle(fontSize: 11, color: DecibelColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: DecibelColors.purple, size: 16),
                ],
              ),
            );
          },
        ),

        if (res.matchedTracks.length > 15)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '+ ${res.matchedTracks.length - 15} more tracks',
              style: const TextStyle(color: DecibelColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
