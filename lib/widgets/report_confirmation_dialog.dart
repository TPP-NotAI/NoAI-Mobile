import 'package:flutter/material.dart';

/// A confirmation dialog shown after successfully submitting a report.
class ReportConfirmationDialog extends StatelessWidget {
  final String type; // 'post' or 'profile'
  final String? username; // For profile reports

  const ReportConfirmationDialog({
    super.key,
    required this.type,
    this.username,
  });

  /// Shows the confirmation dialog.
  static Future<void> show(
    BuildContext context, {
    required String type,
    String? username,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportConfirmationDialog(
        type: type,
        username: username,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 40,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            'Report Submitted',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Message
          Text(
            type == 'post'
                ? 'Thank you for helping keep NOAI safe. We\'ll review this post and take appropriate action if needed.'
                : username != null
                    ? 'Thank you for reporting @$username. We\'ll review this profile and take appropriate action if needed.'
                    : 'Thank you for your report. We\'ll review this and take appropriate action if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Close button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

