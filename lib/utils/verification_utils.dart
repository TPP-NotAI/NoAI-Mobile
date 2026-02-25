import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/kyc_verification_service.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

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
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Verification Required'.tr(context)),
          ],
        ),
        content: Text(
          'To ensure a high-quality community, you must be a verified human to perform this action.\n\nIt takes less than a minute!'
              .tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: Text('Maybe Later'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // Verify
            child: Text('Verify Now'.tr(context)),
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
  /// - Unverified: shows verify prompt (or pending message if Didit review in progress)
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

    // Gate 2: Must have purchased at least 1 ROO.
    // Try current wallet first, then refresh once to avoid stale false negatives.
    final walletProvider = context.read<WalletProvider>();
    double balance = walletProvider.wallet?.balanceRc ?? user.balance;
    if (balance <= 0) {
      try {
        await walletProvider.refreshWallet(user.id);
        balance = walletProvider.wallet?.balanceRc ?? user.balance;
      } catch (_) {
        // Ignore refresh failure and continue with current value.
      }
    }
    if (balance <= 0) {
      try {
        // Final source-of-truth check (wallets.balance_rc) to avoid false prompts
        // when local provider state is stale.
        await KycVerificationService().requireActivation(
          currentBalance: balance,
        );
        return true;
      } on NotActivatedException {
        await _showBuyRooDialog(context);
        return false;
      } on KycNotVerifiedException {
        final refreshedUser = context.read<AuthProvider>().currentUser;
        if (refreshedUser?.isVerificationPending == true) {
          await _showPendingDialog(context);
          return false;
        }
        return checkVerification(context);
      }
    }

    return true;
  }

  static Future<void> _showPendingDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Verification Pending'.tr(context)),
          ],
        ),
        content: Text(
          'Your identity verification is being reviewed. This typically takes a few minutes.\n\nYou will be notified once approved and can start participating.'
              .tr(context),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.tr(context)),
          ),
        ],
      ),
    );
  }

  static Future<void> _showBuyRooDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_open, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Activate Your Account'.tr(context)),
          ],
        ),
        content: Text(
          "You're verified! To unlock posting, commenting, liking, and all platform features, purchase at least 1 ROO.\n\nThis is a one-time activation step."
              .tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Not Now'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Buy ROO'.tr(context)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pushNamed(context, '/wallet');
    }
  }
}
