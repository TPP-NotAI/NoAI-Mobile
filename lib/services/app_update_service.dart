import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _isChecking = false;
  DateTime? _lastPromptAt;

  Future<void> checkAndPromptForUpdate(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (_isChecking || !context.mounted) return;
    _isChecking = true;

    try {
      if (!Platform.isAndroid) {
        if (manual) {
          _showSnackBar(
            context,
            'Update check is currently supported on Android Play Store builds.',
          );
        }
        return;
      }

      final info = await InAppUpdate.checkForUpdate();
      final available = info.updateAvailability == UpdateAvailability.updateAvailable;

      if (!available) {
        if (manual && context.mounted) {
          _showSnackBar(context, 'You are already on the latest version.');
        }
        return;
      }

      final now = DateTime.now();
      final canPromptAgain =
          _lastPromptAt == null || now.difference(_lastPromptAt!) > const Duration(hours: 6);

      if (manual || canPromptAgain) {
        _lastPromptAt = now;
        await _showUpdateDialog(context, info);
      }
    } catch (e) {
      debugPrint('AppUpdateService: Failed to check app update - $e');
      if (manual && context.mounted) {
        _showSnackBar(
          context,
          'Could not check for updates. Try again in a moment.',
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: const Text(
          'A newer version of ROOVERSE is available. Update now for the latest improvements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _performUpdate(context, info);
            },
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpdate(BuildContext context, AppUpdateInfo info) async {
    try {
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        if (context.mounted) {
          _showSnackBar(context, 'Update downloaded. Restarting app...');
        }
      }
    } catch (e) {
      debugPrint('AppUpdateService: Failed to perform app update - $e');
      if (context.mounted) {
        _showSnackBar(context, 'Update failed. Please try again.');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
