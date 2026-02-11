import 'package:flutter/material.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_mapper.dart';

/// Utility class for showing error/success/info SnackBars consistently.
///
/// Usage in screens/widgets:
/// ```dart
/// SnackBarUtils.showError(context, exception);
/// SnackBarUtils.showSuccess(context, 'Post created!');
/// ```
class SnackBarUtils {
  /// Show an error SnackBar for any exception.
  /// Automatically maps to user-friendly message.
  static void showError(
    BuildContext context,
    Object error, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final appError = error is AppException ? error : ErrorMapper.map(error);

    _show(
      context,
      message: appError.userMessage,
      backgroundColor: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline,
      duration: duration,
      action: action,
    );
  }

  /// Show an error SnackBar with a custom message.
  /// Use when you have a specific message to display.
  static void showErrorMessage(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline,
      duration: duration,
      action: action,
    );
  }

  /// Show a success SnackBar.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle_outline,
      duration: duration,
      action: action,
    );
  }

  /// Show an info SnackBar.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: Icons.info_outline,
      duration: duration,
      action: action,
    );
  }

  /// Show a warning SnackBar.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Colors.orange.shade700,
      icon: Icons.warning_amber_outlined,
      duration: duration,
      action: action,
    );
  }

  /// Internal method to show SnackBar.
  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
    SnackBarAction? action,
  }) {
    // Ensure context is still valid
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Convenience method to handle try-catch with automatic SnackBar display.
  /// Returns the result of the operation, or null if an error occurred.
  ///
  /// Usage:
  /// ```dart
  /// final result = await SnackBarUtils.tryWithError(
  ///   context,
  ///   () => someAsyncOperation(),
  ///   successMessage: 'Operation completed!',
  /// );
  /// ```
  static Future<T?> tryWithError<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? successMessage,
  }) async {
    try {
      final result = await operation();
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
      return null;
    }
  }

  /// Show a SnackBar with an action button for KYC verification.
  static void showKycRequired(
    BuildContext context, {
    VoidCallback? onVerify,
  }) {
    _show(
      context,
      message: 'Please complete human verification to perform this action',
      backgroundColor: Colors.orange.shade700,
      icon: Icons.verified_user_outlined,
      duration: const Duration(seconds: 5),
      action: onVerify != null
          ? SnackBarAction(
              label: 'Verify',
              textColor: Colors.white,
              onPressed: onVerify,
            )
          : null,
    );
  }

  /// Show a SnackBar for internet connectivity issues.
  static void showNoInternet(BuildContext context) {
    _show(
      context,
      message: 'No internet access. Please check your connection.',
      backgroundColor: Colors.red.shade700,
      icon: Icons.wifi_off_outlined,
      duration: const Duration(seconds: 5),
    );
  }
}
