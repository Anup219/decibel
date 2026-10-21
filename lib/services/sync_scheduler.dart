import 'dart:async';
import 'package:flutter/widgets.dart';
import 'event_uploader.dart';
import 'playback_logger.dart';

class SyncScheduler with WidgetsBindingObserver {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  final EventUploader _uploader = EventUploader();
  final PlaybackLogger _logger = PlaybackLogger();
  Timer? _periodicFlushTimer;
  int _eventsSinceLastFlush = 0;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Initial flush and recover any aborted plays from last run
    _logger.recoverPendingSessions().then((_) {
      _uploader.flush();
    });

    // Flush every 15 minutes
    _periodicFlushTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _uploader.flush();
    });
  }

  void onEventLogged() {
    _eventsSinceLastFlush++;
    if (_eventsSinceLastFlush >= 20) {
      _eventsSinceLastFlush = 0;
      _uploader.flush();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      _uploader.flush();
    }
  }

  void dispose() {
    _periodicFlushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }
}
