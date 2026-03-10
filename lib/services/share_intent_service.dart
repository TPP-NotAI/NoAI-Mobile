import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Handles incoming shared content from other apps (share target).
/// Only active on Android and iOS — silently no-ops on other platforms.
class ShareIntentService {
  static final ShareIntentService _instance = ShareIntentService._internal();
  factory ShareIntentService() => _instance;
  ShareIntentService._internal();

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSub;
  List<SharedMediaFile>? _pendingSharedMedia;

  // Plugin only works on Android and iOS
  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Call once at app startup.
  void initialize() {
    if (!_supported) return;

    // Content shared while app was closed (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _pendingSharedMedia = files;
        debugPrint('[ShareIntentService] Cold-start share: ${files.length} item(s)');
      }
    }).catchError((e) {
      // MissingPluginException on hot-restart or unsupported env — safe to ignore
      if (e is! MissingPluginException) {
        debugPrint('[ShareIntentService] getInitialMedia error: $e');
      }
    });

    // Content shared while app is already running (warm start)
    try {
      _mediaStreamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          if (files.isNotEmpty) {
            _pendingSharedMedia = files;
            debugPrint('[ShareIntentService] Warm share: ${files.length} item(s)');
          }
        },
        onError: (err) => debugPrint('[ShareIntentService] stream error: $err'),
      );
    } catch (e) {
      debugPrint('[ShareIntentService] getMediaStream error: $e');
    }
  }

  /// Consume and return any pending shared media. Returns null if nothing pending.
  List<SharedMediaFile>? consumePendingSharedMedia() {
    final pending = _pendingSharedMedia;
    _pendingSharedMedia = null;
    if (pending != null && pending.isNotEmpty) {
      try {
        ReceiveSharingIntent.instance.reset();
      } catch (_) {}
    }
    return pending;
  }

  void dispose() {
    _mediaStreamSub?.cancel();
  }
}
