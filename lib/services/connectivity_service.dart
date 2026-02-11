import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor internet connectivity status.
class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  
  // Stream controller to broadcast connectivity changes
  final StreamController<ConnectivityResult> _connectivityController = 
      StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;

  /// Initialize the service and start listening for changes.
  Future<void> initialize() async {
    // Initial check
    final results = await _connectivity.checkConnectivity();
    if (results.isNotEmpty) {
      _connectivityController.add(results.first);
    }

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        _connectivityController.add(results.first);
      }
    });
  }

  /// Check if the device is currently connected to the internet.
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.first != ConnectivityResult.none;
  }

  /// Get the current connectivity result.
  Future<ConnectivityResult> get currentResult async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return ConnectivityResult.none;
    return results.first;
  }

  void dispose() {
    _connectivityController.close();
  }
}
