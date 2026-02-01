import 'dart:async';
import 'package:flutter/material.dart';
import 'supabase_service.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _updateTimer;
  final _supabase = SupabaseService().client;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _updateStatus(); // Initial update
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
  }

  void _startTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
    } catch (e) {
      debugPrint('Error updating presence: $e');
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
