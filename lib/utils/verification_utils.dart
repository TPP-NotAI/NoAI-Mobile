import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

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

  /// Full two-gate check: verified AND wallet balance > 0.
  ///
  /// - Unverified: shows verify prompt (or pending message if Veriff review in progress)
  /// - Verified but balance = 0: shows "Buy ROO to activate" prompt
  /// - Both gates pass: returns true
  static Future<bool> checkActivation(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return false;

    // Gate 1: Verification status
    if (user.isVerificationPending) {
      await _showPendingDialog(context);
      return false;
    }

    if (!user.isVerified) {
      // Reuse existing verify dialog
      return checkVerification(context);
    }

    // Gate 2: Must have purchased at least 1 ROO
    final balance = context.read<WalletProvider>().wallet?.balanceRc ?? 0.0;
    if (balance <= 0) {
      await _showBuyRooDialog(context);
      return false;
    }

    return true;
  }

  static Future<void> _showPendingDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange),
            SizedBox(width: 8),
            Text('Verification Pending'),
          ],
        ),
        content: const Text(
          'Your identity verification is being reviewed. This typically takes a few minutes.\n\nYou will be notified once approved and can start participating.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showBuyRooDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('Activate Your Account'),
          ],
        ),
        content: const Text(
          "You're verified! To unlock posting, commenting, liking, and all platform features, purchase at least 1 ROO.\n\nThis is a one-time activation step.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy ROO'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pushNamed(context, '/wallet');
    }
  }
}
