import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
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
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.primary,
      onSecondary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      // Warm off-white (#EEEDE8) — M3 surface = scaffold base
      surface: AppColors.backgroundLight,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainer: AppColors.surfaceLight,
      surfaceContainerHigh: AppColors.surfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineLight,
      // Disable M3 tonal tinting
      surfaceTint: Colors.transparent,
    ),

    scaffoldBackgroundColor: AppColors.backgroundLight,
    textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.light().textTheme),

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textPrimaryLight,
      titleTextStyle: GoogleFonts.beVietnamPro(
        fontSize: AppTypography.base,
        fontWeight: AppTypography.semiBold,
        color: AppColors.textPrimaryLight,
      ),
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
      hintStyle: GoogleFonts.beVietnamPro(
        color: AppColors.textSecondaryLight,
        fontSize: AppTypography.base,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.double_,
          vertical: AppSpacing.large,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: AppTypography.base,
          fontWeight: AppTypography.semiBold,
          letterSpacing: 0.3,
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      indicatorColor: AppColors.primarySoft,
      elevation: 0,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.textSecondaryLight,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.textSecondaryLight,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────
  // MATERIAL 3 – DARK
  // Brand roles:  Background=Primary #1E1E21  Surface/cards=#333333
  //               Gold=#DEA331 (CTAs/active)  Text=#EEEDE8  Inputs=#26262A
  // ─────────────────────────────────────────────────────────────────────

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      // Gold (#DEA331) — buttons, active icons, links, selection
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.primary,
      onSecondary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      // Primary (#1E1E21) — M3 surface = scaffold/page base
      surface: AppColors.backgroundDark,
      onSurface: AppColors.textPrimaryDark,
      // Accent (#333333) — cards, sheets, dialogs
      surfaceContainer: AppColors.surfaceDark,
      surfaceContainerHigh: AppColors.surfaceDark,
      // Mid-level (#26262A) — inputs, chips
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      // Disable M3 tonal tinting
      surfaceTint: Colors.transparent,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
    ),

    scaffoldBackgroundColor: AppColors.backgroundDark,
    textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.dark().textTheme),

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      // AppBar flush with scaffold — Primary (#1E1E21)
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: AppColors.textPrimaryDark,
      titleTextStyle: GoogleFonts.beVietnamPro(
        fontSize: AppTypography.base,
        fontWeight: AppTypography.semiBold,
        color: AppColors.textPrimaryDark,
      ),
    ),

    dividerColor: AppColors.outlineDark,

    cardTheme: CardThemeData(
      elevation: 0,
      // Cards use Accent (#333333) = surfaceContainer
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
        side: BorderSide(color: AppColors.outlineDark),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // Inputs use mid-level (#26262A)
      fillColor: AppColors.surfaceVariantDark,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.largePlus,
        vertical: AppSpacing.large,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: BorderSide(color: AppColors.outlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: BorderSide(color: AppColors.outlineDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: GoogleFonts.beVietnamPro(
        color: AppColors.textMutedDark,
        fontSize: AppTypography.base,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.double_,
          vertical: AppSpacing.large,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: AppTypography.base,
          fontWeight: AppTypography.semiBold,
          letterSpacing: 0.3,
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      // Nav bar flush with scaffold — Primary (#1E1E21)
      backgroundColor: AppColors.backgroundDark,
      indicatorColor: AppColors.primarySoft,
      elevation: 0,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
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
