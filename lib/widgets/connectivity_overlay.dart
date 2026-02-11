import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';

/// Overlay widget that shows a "No Internet" banner when offline.
class ConnectivityOverlay extends StatefulWidget {
  final Widget child;

  const ConnectivityOverlay({super.key, required this.child});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  ConnectivityResult _lastResult = ConnectivityResult.wifi; // Default to connected
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final result = await ConnectivityService().currentResult;
    if (mounted) {
      setState(() {
        _lastResult = result;
        _isFirstLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: ConnectivityService().connectivityStream,
      initialData: _lastResult,
      builder: (context, snapshot) {
        final result = snapshot.data ?? ConnectivityResult.none;
        final isOffline = result == ConnectivityResult.none;

        return Stack(
          children: [
            widget.child,
            if (isOffline && !_isFirstLoad)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.red.shade700,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'No Internet access. Please check your connection.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isOffline && _lastResult == ConnectivityResult.none && !_isFirstLoad)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: _buildBackOnlineMessage(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBackOnlineMessage() {
    // Show "Back Online" for 3 seconds then hide it
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _lastResult = ConnectivityResult.wifi; // Reset state
        });
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.green.shade700,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Back Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
