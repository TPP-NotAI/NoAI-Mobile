import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

/// App-wide event bus for post lifecycle events.
/// Any screen can listen to [postEventBus] and refresh when a post is created.
final PostEventBus postEventBus = PostEventBus();

class PostEventBus extends ChangeNotifier {
  void notifyPostCreated() => notifyListeners();
}
