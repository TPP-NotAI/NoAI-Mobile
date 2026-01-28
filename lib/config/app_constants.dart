class AppConstants {
  // App Info
  static const String appName = 'NoAI App';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrl = 'https://jsonplaceholder.typicode.com';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String themeKey = 'isDarkMode';
  static const String languageKey = 'language';
  static const String firstLaunchKey = 'firstLaunch';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double defaultElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Limits
  static const int maxPostTitleLength = 100;
  static const int maxPostBodyLength = 500;
  static const int paginationLimit = 20;
}
