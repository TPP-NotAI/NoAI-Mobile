import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class VerificationUtils {
  /// Checks if the current user is a verified human.
  /// If not, shows a dialog prompting them to verify.
  /// Returns [true] if verified, [false] otherwise.
  static Future<bool> checkVerification(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null && user.verifiedHuman == 'verified') {
      return true;
    }

    // Not verified - show dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.orange),
            SizedBox(width: 8),
            Text('Verification Required'),
          ],
        ),
        content: const Text(
          'To ensure a high-quality community, you must be a verified human to perform this action.\n\nIt takes less than a minute!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // Verify
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (context.mounted) {
        Navigator.pushNamed(context, '/verify');
      }
    }

    return false;
  }
}
