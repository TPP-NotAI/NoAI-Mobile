import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/storage_service.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../config/app_spacing.dart';

class ThemeProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  static const _key = 'isDarkMode';

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    _isDarkMode = _storage.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.setBool(_key, _isDarkMode);
    notifyListeners();
  }

  ThemeData get theme => _isDarkMode ? darkTheme : lightTheme;
  CupertinoThemeData get cupertinoTheme =>
      _isDarkMode ? darkCupertino : lightCupertino;

  // ─────────────────────────────────────────────
  // CUPERTINO
  // ─────────────────────────────────────────────

  static final lightCupertino = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundLight,
  );

  static final darkCupertino = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundDark,
  );

  // ─────────────────────────────────────────────
  // MATERIAL 3 – LIGHT
  // ─────────────────────────────────────────────

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      background: AppColors.backgroundLight,
      onBackground: AppColors.textPrimaryLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineLight,
      surfaceVariant: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
    ),

    scaffoldBackgroundColor: AppColors.backgroundLight,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textPrimaryLight,
    ),

    dividerColor: AppColors.outlineLight,

    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
        side: BorderSide(color: AppColors.outlineLight),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariantLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.largePlus,
        vertical: AppSpacing.large,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.outlineLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textSecondaryLight,
        fontSize: AppTypography.base,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.double_,
          vertical: AppSpacing.large,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        textStyle: AppTypography.buttonText,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      indicatorColor: AppColors.outlineLight,
      elevation: 0,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w600
              : null,
          color: states.contains(MaterialState.selected)
              ? AppColors.textPrimaryLight
              : AppColors.textSecondaryLight,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? AppColors.textPrimaryLight
              : AppColors.textSecondaryLight,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // MATERIAL 3 – DARK (NOAI PRIMARY)
  // ─────────────────────────────────────────────

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      background: AppColors.backgroundDark,
      onBackground: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: Colors.white,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      surfaceVariant: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
    ),

    scaffoldBackgroundColor: AppColors.backgroundDark,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: Colors.white,
    ),

    dividerColor: AppColors.outlineDark,

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: AppColors.primary.withOpacity(0.18),
      elevation: 0,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.bold
              : null,
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.textSecondaryDark,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.textSecondaryDark,
        ),
      ),
    ),
  );
}
