import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_uploader.dart';
import '../services/local_db.dart';
import '../theme/decibel_colors.dart';

class TelemetryDebugScreen extends StatefulWidget {
  const TelemetryDebugScreen({super.key});

  @override
  State<TelemetryDebugScreen> createState() => _TelemetryDebugScreenState();
}

class _TelemetryDebugScreenState extends State<TelemetryDebugScreen> {
  int _unsyncedCount = 0;
  int _totalEventsCount = 0;
  List<Map<String, dynamic>> _recentEvents = [];
  bool _isLoading = true;
  bool _isFlushing = false;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    setState(() => _isLoading = true);
    try {
      final db = await LocalDb.instance;
      final unsynced = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM play_events WHERE synced = 0'),
      ) ?? 0;

      final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM play_events'),
      ) ?? 0;

      final events = await db.query(
        'play_events',
        orderBy: 'occurred_at DESC',
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _unsyncedCount = unsynced;
          _totalEventsCount = total;
          _recentEvents = events;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manualFlush() async {
    setState(() => _isFlushing = true);
    await EventUploader().flush();
    await _loadDebugData();
    if (mounted) {
      setState(() => _isFlushing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync completed!'),
          backgroundColor: DecibelColors.purple,
        ),
      );
    }
  }

  Future<void> _exportLogJson() async {
    try {
      final db = await LocalDb.instance;
      final events = await db.query('play_events', orderBy: 'occurred_at DESC', limit: 100);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(events);
      await Share.share(jsonStr, subject: 'Decibel Telemetry Log Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteMyData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DecibelColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Telemetry Data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete your anonymous install profile and all play events from both the local database and the server.',
          style: TextStyle(color: DecibelColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: DecibelColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await EventUploader.deleteMyData();
      await _loadDebugData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data successfully deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String anonUid = 'Not Signed In';
    try {
      anonUid = Supabase.instance.client.auth.currentUser?.id ?? 'Not Signed In';
    } catch (_) {}

    final lastFlush = EventUploader().lastFlushTime;

    return Scaffold(
      backgroundColor: DecibelColors.background,
      appBar: AppBar(
        title: const Text(
          'Telemetry & Sync Health',
          style: TextStyle(
            fontFamily: DecibelTypography.headingFont,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadDebugData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DecibelColors.purple))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Install info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DecibelColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DecibelColors.purple.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANONYMOUS INSTALL ID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: DecibelColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        anonUid,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: DecibelColors.purpleLight,
                        ),
                      ),
                      const Divider(height: 24, color: Colors.white12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStat('Unsynced Events', '$_unsyncedCount', _unsyncedCount > 0 ? Colors.amber : Colors.greenAccent),
                          _buildStat('Total Logged', '$_totalEventsCount', Colors.white),
                          _buildStat(
                            'Last Sync',
                            lastFlush != null
                                ? '${lastFlush.hour.toString().padLeft(2, '0')}:${lastFlush.minute.toString().padLeft(2, '0')}'
                                : 'None',
                            Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DecibelColors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isFlushing ? null : _manualFlush,
                        icon: _isFlushing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                        label: const Text('Flush to Server', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF232230),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _exportLogJson,
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      label: const Text('Export JSON', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmDeleteMyData,
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                  label: const Text('Delete My Data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // Recent Events
                const Text(
                  'Recent 20 Play Events',
                  style: TextStyle(
                    fontFamily: DecibelTypography.headingFont,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                if (_recentEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No play events recorded yet.', style: TextStyle(color: DecibelColors.textSecondary)),
                    ),
                  )
                else
                  ..._recentEvents.map((e) {
                    final synced = (e['synced'] as int? ?? 0) == 1;
                    final listenedSec = ((e['listened_ms'] as int? ?? 0) / 1000).toStringAsFixed(1);
                    final durSec = ((e['duration_ms'] as int? ?? 1) / 1000).toStringAsFixed(1);
                    final origin = e['origin'] as String? ?? 'unknown';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DecibelColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            color: synced ? Colors.greenAccent : Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['track_key'] as String? ?? 'unknown_track',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'origin: $origin • listened: ${listenedSec}s / ${durSec}s',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: DecibelColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((e['liked'] as int? ?? 0) == 1)
                            const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: DecibelColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
