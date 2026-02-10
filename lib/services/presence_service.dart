import 'dart:async';
import 'package:flutter/material.dart';
import 'supabase_service.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _updateTimer;
  final _supabase = SupabaseService().client;
  int _consecutiveErrors = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _consecutiveErrors = 0;
    _startTimer();
    _updateStatus();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
  }

  void _startTimer() {
    _updateTimer?.cancel();
    // Back off if we keep getting errors: 30s, 60s, 120s, max 5min
    final intervalSeconds = 30 * (1 << _consecutiveErrors.clamp(0, 3));
    _updateTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _updateStatus();
    });
  }

  void _stopTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  Future<void> _updateStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
      if (_consecutiveErrors > 0) {
        _consecutiveErrors = 0;
        _startTimer(); // Reset to normal interval
      }
    } catch (e) {
      _consecutiveErrors++;
      if (_consecutiveErrors <= 2) {
        debugPrint('Error updating presence: $e');
      }
      if (_consecutiveErrors == 3) {
        debugPrint('Presence updates failing repeatedly, backing off');
        _startTimer(); // Restart with longer interval
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _updateStatus();
    } else {
      _stopTimer();
    }
  }
}
