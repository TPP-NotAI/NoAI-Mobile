import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _isChecking = false;
  DateTime? _lastPromptAt;

  Future<void> checkAndPromptForUpdate(
    BuildContext context, {
    bool manual = false,
    bool force = false,
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
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      final mustForce = force && await _isBelowMinimumRequiredVersion();

      if (!available) {
        if (mustForce && context.mounted) {
          _showSnackBar(
            context,
            'An update is required but no store update is available yet.',
          );
        }
        if (manual && context.mounted) {
          _showSnackBar(context, 'You are already on the latest version.');
        }
        return;
      }

      final now = DateTime.now();
      final canPromptAgain =
          _lastPromptAt == null ||
          now.difference(_lastPromptAt!) > const Duration(hours: 6);

      if (mustForce || manual || canPromptAgain) {
        _lastPromptAt = now;
        await _showUpdateDialog(context, info, force: mustForce);
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
    AppUpdateInfo info, {
    bool force = false,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) {
        var isUpdating = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: !force,
            child: AlertDialog(
              title: const Text('Update available'),
              content: Text(
                force
                    ? 'A required update is available. You must update ROOVERSE to continue.'
                    : 'A newer version of ROOVERSE is available. Update now for the latest improvements.',
              ),
              actions: [
                if (!force)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Later'),
                  ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setDialogState(() => isUpdating = true);
                          final success = await _performUpdate(context, info);

                          if (!context.mounted || !dialogContext.mounted) {
                            return;
                          }

                          if (!force || success) {
                            Navigator.of(dialogContext).pop();
                            return;
                          }

                          setDialogState(() => isUpdating = false);
                        },
                  child: Text(isUpdating ? 'Updating...' : 'Update now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _performUpdate(BuildContext context, AppUpdateInfo info) async {
    try {
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        if (context.mounted) {
          _showSnackBar(context, 'Update downloaded. Restarting app...');
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AppUpdateService: Failed to perform app update - $e');
      if (context.mounted) {
        _showSnackBar(context, 'Update failed. Please try again.');
      }
      return false;
    }
  }

  Future<bool> _isBelowMinimumRequiredVersion() async {
    try {
      final response = await SupabaseService().client
          .from(SupabaseConfig.platformConfigTable)
          .select('*')
          .eq('id', 1)
          .maybeSingle();

      if (response == null) return false;

      final minRequiredVersion = _extractMinRequiredVersion(response);
      if (minRequiredVersion == null || minRequiredVersion.isEmpty) {
        return false;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      return _compareVersions(currentVersion, minRequiredVersion) < 0;
    } catch (e) {
      debugPrint(
        'AppUpdateService: Failed to evaluate minimum required version - $e',
      );
      return false;
    }
  }

  String? _extractMinRequiredVersion(Map<String, dynamic> row) {
    final forceFlag = _getBoolByKeys(
      row,
      const [
        'force_update_required',
        'force_update_enabled',
        'require_force_update',
      ],
    );

    if (forceFlag == false) return null;

    final platformKeys = Platform.isAndroid
        ? const [
            'min_android_version',
            'min_supported_android_version',
            'android_min_version',
            'minimum_android_version',
          ]
        : const [
            'min_ios_version',
            'min_supported_ios_version',
            'ios_min_version',
            'minimum_ios_version',
          ];

    final platformVersion = _getStringByKeys(row, platformKeys);
    if (platformVersion != null && platformVersion.isNotEmpty) {
      return platformVersion;
    }

    return _getStringByKeys(
      row,
      const [
        'min_app_version',
        'minimum_app_version',
        'min_supported_version',
      ],
    );
  }

  String? _getStringByKeys(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final stringValue = value.toString().trim();
      if (stringValue.isNotEmpty) return stringValue;
    }
    return null;
  }

  bool? _getBoolByKeys(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return null;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _normalizeVersion(left);
    final rightParts = _normalizeVersion(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < maxLength; i++) {
      final l = i < leftParts.length ? leftParts[i] : 0;
      final r = i < rightParts.length ? rightParts[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  List<int> _normalizeVersion(String version) {
    final cleaned = version.split('+').first.trim();
    if (cleaned.isEmpty) return const [0];

    return cleaned.split('.').map((part) {
      final digits = RegExp(r'\d+').firstMatch(part)?.group(0);
      return int.tryParse(digits ?? '') ?? 0;
    }).toList();
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
