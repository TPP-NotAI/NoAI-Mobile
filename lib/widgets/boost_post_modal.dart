import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/global_keys.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../repositories/boost_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/push_notification_service.dart';
import '../utils/snackbar_utils.dart';
import 'post_card.dart' show PostBoostCache;

import 'package:rooverse/l10n/hardcoded_l10n.dart';
/// Cost per user notified (in ROO).
const double _kRooPerUser = 0.1;

/// Min / max reach on the slider.
const double _kMinUsers = 100;
const double _kMaxUsers = 10000;

class BoostPostModal extends StatefulWidget {
  final Post post;

  const BoostPostModal({super.key, required this.post});

  @override
  State<BoostPostModal> createState() => _BoostPostModalState();
}

class _BoostPostModalState extends State<BoostPostModal> {
  double _targetUsers = 500;
  bool _isProcessing = false;

  double get _cost => (_targetUsers * _kRooPerUser).ceilToDouble();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<WalletProvider>().refreshWallet(userId).catchError((_) {
          return null;
        });
      }
    });
  }

  Future<void> _boost() async {
    if (_isProcessing) return;

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      _showError('You must be logged in to boost a post.');
      return;
    }

    final availableBalance = walletProvider.wallet?.balanceRc ?? user.balance;
    if (_cost > availableBalance) {
      _showError(
        'Insufficient Roobyte balance. You need ${_cost.toStringAsFixed(0)} ROO.',
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Optimistic deduction
    final localTxId = walletProvider.addOptimisticOutgoingTransaction(
      userId: user.id,
      amount: _cost,
      txType: 'fee',
      memo: 'Boost post: ${widget.post.title ?? widget.post.content.split('\n').first}',
      metadata: {
        'activityType': 'POST_BOOST',
        'referencePostId': widget.post.id,
        'targetUsers': _targetUsers.toInt(),
      },
    );

    // Capture translated strings while context is still valid
    final targetUsers = _targetUsers.toInt();
    final confirmingText = 'Boosting post to $targetUsers users… confirming payment.'.tr(context);
    final successTitle = 'Boost Successful!'.tr(context);
    final successBody = 'Your post was successfully boosted to $targetUsers users.'.tr(context);
    final greatText = 'Great!'.tr(context);
    final boostFailedPrefix = 'Boost failed: '.tr(context);

    // Close modal immediately for snappy UX
    if (mounted) Navigator.pop(context);

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(confirmingText),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );

    unawaited(
      _performBoost(
        userId: user.id,
        targetUsers: targetUsers,
        cost: _cost,
        localTxId: localTxId,
        walletProvider: walletProvider,
        successTitle: successTitle,
        successBody: successBody,
        greatText: greatText,
        boostFailedPrefix: boostFailedPrefix,
      ),
    );
  }

  Future<void> _performBoost({
    required String userId,
    required int targetUsers,
    required double cost,
    required String localTxId,
    required WalletProvider walletProvider,
    required String successTitle,
    required String successBody,
    required String greatText,
    required String boostFailedPrefix,
  }) async {
    final boostRepo = BoostRepository();

    try {
      // 1. Deduct ROO from wallet
      final success = await walletProvider.spendRoo(
        userId: userId,
        amount: cost,
        activityType: 'POST_BOOST',
        metadata: {
          'referencePostId': widget.post.id,
          'targetUsers': targetUsers,
        },
      );

      if (!success) {
        walletProvider.rollbackOptimisticTransaction(
          localTxId,
          errorMessage: walletProvider.error ?? 'Payment failed',
        );
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'Boost payment failed.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      walletProvider.confirmOptimisticTransaction(localTxId);

      // 2. Record the boost in post_boosts
      final boostId = await boostRepo.createBoost(
        postId: widget.post.id,
        authorId: userId,
        targetUserCount: targetUsers,
        costRc: cost,
      );

      // Update the in-card Sponsored badge cache immediately
      PostBoostCache.markBoosted(widget.post.id);

      // 3. Select recipients, persist to post_boost_recipients, and notify
      if (boostId != null) {
        final recipientIds = await boostRepo.selectAndInsertRecipients(
          boostId: boostId,
          authorId: userId,
          targetUserCount: targetUsers,
        );
        await _sendBoostNotifications(
          boosterId: userId,
          recipientIds: recipientIds,
        );
      }

      // 4. Fire a local push notification
      await PushNotificationService().showLocalNotification(
        title: 'Post Boosted! 🚀',
        body: 'Your post was successfully boosted to $targetUsers users.',
        type: 'social',
      );

      // 5. Show an in-app success dialog
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        showDialog<void>(
          context: ctx,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.rocket_launch, color: Color(0xFFF97316), size: 36),
            title: Text(successTitle),
            content: Text(successBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(greatText),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      walletProvider.rollbackOptimisticTransaction(
        localTxId,
        errorMessage: e.toString(),
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$boostFailedPrefix${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Sends 'mention' notifications to the already-selected [recipientIds].
  Future<void> _sendBoostNotifications({
    required String boosterId,
    required List<String> recipientIds,
  }) async {
    final notifRepo = NotificationRepository();

    final postTitle = widget.post.title?.isNotEmpty == true
        ? widget.post.title!
        : widget.post.content.split('\n').first;
    final truncatedTitle =
        postTitle.length > 60 ? '${postTitle.substring(0, 60)}…' : postTitle;

    const batchSize = 50;
    for (int i = 0; i < recipientIds.length; i += batchSize) {
      final batch = recipientIds.skip(i).take(batchSize);
      await Future.wait(
        batch.map(
          (recipientId) => notifRepo.createNotification(
            userId: recipientId,
            type: 'mention',
            title: 'Trending Post',
            body: truncatedTitle,
            actorId: boosterId,
            postId: widget.post.id,
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    SnackBarUtils.showErrorMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final wallet = context.watch<WalletProvider>().wallet;
    final user = context.watch<AuthProvider>().currentUser;
    final balance = wallet?.balanceRc ?? user?.balance ?? 0.0;
    final canAfford = _cost <= balance;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Boost Post'.tr(context),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Notify users across ROOVERSE about your post'.tr(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ── Balance row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Balance'.tr(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.toll, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            balance.toStringAsFixed(2),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('ROO'.tr(context),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Reach slider ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REACH'.tr(context),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Big reach number
                    Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _targetUsers.toInt().toString(),
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF97316),
                              ),
                            ),
                            TextSpan(
                              text: ' users',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFF97316),
                        inactiveTrackColor: colors.surfaceContainerHighest,
                        thumbColor: const Color(0xFFF97316),
                        overlayColor: Colors.orange.withValues(alpha: 0.15),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _targetUsers,
                        min: _kMinUsers,
                        max: _kMaxUsers,
                        divisions: 99, // steps of 100
                        onChanged: (v) =>
                            setState(() => _targetUsers = (v / 100).round() * 100.0),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_kMinUsers.toInt()}'.tr(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text('${_kMaxUsers.toInt()}'.tr(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Cost summary card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? Colors.orange.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: canAfford
                          ? Colors.orange.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Users notified',
                        value: '${_targetUsers.toInt()}',
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Rate',
                        value: '${(_kRooPerUser * 100).toStringAsFixed(0)} ROO / 10 users',
                      ),
                      const Divider(height: 20),
                      _SummaryRow(
                        label: 'Total cost',
                        value: '${_cost.toStringAsFixed(0)} ROO',
                        highlight: true,
                        error: !canAfford,
                      ),
                      if (!canAfford) ...[
                        const SizedBox(height: 6),
                        Text('Insufficient balance — reduce reach or top up your wallet.'.tr(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Boost button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (canAfford && !_isProcessing) ? _boost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rocket_launch, size: 20),
                              const SizedBox(width: 10),
                              Text('Boost for ${_cost.toStringAsFixed(0)} ROO'.tr(context),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text('${(_kRooPerUser * 100).toStringAsFixed(0)} ROO per 10 users · Random selection across ROOVERSE'.tr(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool error;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final valueColor = error
        ? Colors.red.shade400
        : highlight
        ? const Color(0xFFF97316)
        : colors.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
