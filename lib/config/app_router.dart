import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/settings/privacy_screen.dart';
import '../screens/language_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/user_detail_screen.dart';
import '../models/post.dart';
import '../models/user.dart';

class AppRouter {
  // Route names
  static const String home = '/';
  static const String users = '/users';
  static const String settings = '/settings';
  static const String language = '/settings/language';
  static const String postDetail = '/post-detail';
  static const String userDetail = '/user-detail';
  static const String privacy = '/settings/privacy';

  // Generate routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == home) {
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    } else if (settings.name == users) {
      return MaterialPageRoute(builder: (_) => const UsersScreen());
    } else if (settings.name == settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    } else if (settings.name == privacy) {
      return MaterialPageRoute(builder: (_) => const PrivacyScreen());
    } else if (settings.name == language) {
      return MaterialPageRoute(builder: (_) => const LanguageScreen());
    } else if (settings.name == postDetail) {
      final post = settings.arguments as Post?;
      if (post != null) {
        return MaterialPageRoute(builder: (_) => PostDetailScreen(post: post));
      }
      return _errorRoute();
    } else if (settings.name == userDetail) {
      final user = settings.arguments as User?;
      if (user != null) {
        return MaterialPageRoute(builder: (_) => UserDetailScreen(user: user));
      }
      return _errorRoute();
    } else {
      return _errorRoute();
    }
  }

  // Error route
  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Page not found')),
      ),
    );
  }
}
