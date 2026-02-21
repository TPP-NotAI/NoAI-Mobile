import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      await userProvider.fetchTransactions(userId);
    }
  }

  String _profileLabel(dynamic profile) {
    if (profile is Map<String, dynamic>) {
      final displayName = (profile['display_name'] as String?)?.trim();
      final username = (profile['username'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) return displayName;
      if (username != null && username.isNotEmpty) return '@$username';
    }
    return '';
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> source) {
    final query = _searchController.text.trim().toLowerCase();
    final from = _selectedDateRange?.start;
    final to = _selectedDateRange?.end;

    return source.where((tx) {
      final createdAt = tx['created_at'] != null
          ? DateTime.tryParse(tx['created_at'].toString())?.toLocal()
          : null;

      if (from != null && to != null && createdAt != null) {
        final txDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final fromDate = DateTime(from.year, from.month, from.day);
        final toDate = DateTime(to.year, to.month, to.day);
        if (txDate.isBefore(fromDate) || txDate.isAfter(toDate)) {
          return false;
        }
      }

      if (query.isEmpty) return true;

      final txType = (tx['tx_type'] as String? ?? '').toLowerCase();
      final memo = (tx['memo'] as String? ?? '').toLowerCase();
      final hash = (tx['tx_hash'] as String? ?? '').toLowerCase();
      final amount = (tx['amount_rc'] as num?)?.toDouble() ?? 0.0;
      final fromProfile = _profileLabel(tx['from_profile']).toLowerCase();
      final toProfile = _profileLabel(tx['to_profile']).toLowerCase();

      final metadataRaw = tx['metadata'];
      final metadata = metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : <String, dynamic>{};
      final recipientUsername =
          (metadata['recipientUsername'] as String? ?? '').toLowerCase();
      final recipientDisplayName =
          (metadata['recipientDisplayName'] as String? ?? '').toLowerCase();
      final inputRecipient =
          (metadata['inputRecipient'] as String? ?? '').toLowerCase();
      final address = (metadata['toAddress'] as String? ?? '').toLowerCase();

      return txType.contains(query) ||
          memo.contains(query) ||
          hash.contains(query) ||
          amount.toStringAsFixed(2).contains(query) ||
          fromProfile.contains(query) ||
          toProfile.contains(query) ||
          recipientUsername.contains(query) ||
          recipientDisplayName.contains(query) ||
          inputRecipient.contains(query) ||
          address.contains(query);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = authProvider.currentUser?.id;
    final filteredTransactions = _applyFilters(userProvider.transactions);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transaction History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.outlineVariant),
        ),
      ),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProvider.transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transaction history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by user, hash, memo, type, amount',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Filter by date'
                                : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - '
                                      '${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _selectedDateRange == null &&
                                _searchController.text.isEmpty
                            ? null
                            : () {
                                _searchController.clear();
                                setState(() => _selectedDateRange = null);
                              },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filteredTransactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_alt_off,
                            size: 48,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No matching transactions',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredTransactions.map(
                      (tx) => _TransactionItem(
                        tx: tx,
                        currentUserId: currentUserId,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String? currentUserId;

  const _TransactionItem({required this.tx, required this.currentUserId});

  String _profileName(dynamic profile, {required String fallback}) {
    if (profile is Map<String, dynamic>) {
      final displayName = profile['display_name'] as String?;
      final username = profile['username'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) {
        return displayName;
      }
      if (username != null && username.trim().isNotEmpty) {
        return '@$username';
      }
    }
    return fallback;
  }

  String _resolveReceiverLabel({
    required Map<String, dynamic> tx,
    required Map<String, dynamic> metadata,
  }) {
    final toProfile = tx['to_profile'];
    final recipientDisplayName = (metadata['recipientDisplayName'] as String?)
        ?.trim();
    final recipientUsername = (metadata['recipientUsername'] as String?)
        ?.trim();
    final inputRecipient = (metadata['inputRecipient'] as String?)?.trim();
    final toAddress = (metadata['toAddress'] as String?)?.trim();
    final toUserId = (tx['to_user_id'] as String?)?.trim();

    return _profileName(
      toProfile,
      fallback: recipientDisplayName?.isNotEmpty == true
          ? recipientDisplayName!
          : recipientUsername?.isNotEmpty == true
          ? '@$recipientUsername'
          : inputRecipient?.isNotEmpty == true
          ? inputRecipient!
          : toAddress?.isNotEmpty == true
          ? toAddress!
          : toUserId?.isNotEmpty == true
          ? 'Unknown user'
          : 'External wallet',
    );
  }

  double? _parseBalanceValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _titleCaseWords(String value) {
    return value
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _rewardLabel(String? activityType, String txType) {
    if (activityType != null && activityType.trim().isNotEmpty) {
      return _titleCaseWords(activityType);
    }

    switch (txType) {
      case 'post_reward':
        return 'Post Reward';
      case 'staking_reward':
        return 'Staking Reward';
      case 'daily_bonus':
        return 'Daily Login';
      case 'signup_bonus':
        return 'Signup Bonus';
      case 'engagement_reward':
        return 'Engagement Reward';
      default:
        return _titleCaseWords(txType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final txType = (tx['tx_type'] as String? ?? 'transfer').toLowerCase();
    final status = (tx['status'] as String? ?? 'completed').toLowerCase();
    final fromUserId = tx['from_user_id'] as String?;
    final toUserId = tx['to_user_id'] as String?;
    final amountRc = (tx['amount_rc'] as num?)?.toDouble() ?? 0.0;
    final memo = tx['memo'] as String?;
    final txHash = tx['tx_hash'] as String?;

    final metadataRaw = tx['metadata'];
    final metadata = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};
    final activityType =
        (metadata['activityType'] as String?)?.trim().toLowerCase();
    final effectiveType = activityType == 'tip' ? 'tip' : txType;

    final isReceived = toUserId != null && toUserId == currentUserId;
    final isSent = fromUserId != null && fromUserId == currentUserId;
    final isFromSystem = fromUserId == null || fromUserId.isEmpty;

    final sender = _profileName(
      tx['from_profile'],
      fallback: isFromSystem ? 'System' : 'Unknown sender',
    );

    final receiver = _resolveReceiverLabel(tx: tx, metadata: metadata);
    final balanceBefore = _parseBalanceValue(metadata['balanceBeforeRc']);
    final balanceAfter = _parseBalanceValue(metadata['balanceAfterRc']);

    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    String amountStr;
    Color amountColor;

    if (effectiveType == 'tip') {
      icon = Icons.toll;
      iconColor = Colors.blue;
      if (isReceived) {
        title = 'Tip Received';
        subtitle = 'From $sender';
        amountStr = '+${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.green;
      } else {
        title = 'Tip Sent';
        subtitle = 'To $receiver';
        amountStr = '-${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.red;
      }
    } else if (txType == 'engagement_reward' ||
        txType == 'post_reward' ||
        txType == 'staking_reward' ||
        txType == 'daily_bonus' ||
        txType == 'signup_bonus') {
      icon = Icons.card_giftcard;
      iconColor = Colors.green;
      title = _rewardLabel(activityType, txType);
      subtitle = memo ?? 'From $sender';
      amountStr = '+${amountRc.toStringAsFixed(2)}';
      amountColor = Colors.green;
    } else if (txType == 'fee') {
      icon = activityType == 'post_boost'
          ? Icons.rocket_launch
          : Icons.receipt;
      iconColor = Colors.orange;
      title = activityType == 'post_boost' ? 'Post Boost' : 'Platform Fee';
      subtitle = memo ?? 'Fee charged';
      amountStr = '-${amountRc.toStringAsFixed(2)}';
      amountColor = Colors.red;
    } else {
      if (isReceived) {
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        title = 'Received ROO';
        subtitle = 'From $sender';
        amountStr = '+${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.green;
      } else {
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        title = 'Sent ROO';
        subtitle = 'To $receiver';
        amountStr = '-${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.red;
      }
    }

    final createdAt = tx['created_at'] != null
        ? DateTime.tryParse(tx['created_at'].toString())?.toLocal()
        : null;

    final date = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt)
        : 'Unknown date';

    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'failed'
        ? Colors.red
        : Colors.orange;

    final statusLabel = status == 'completed'
        ? 'Completed'
        : status == 'failed'
        ? 'Failed'
        : 'Pending';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _TransactionDetailsSheet(
            title: title,
            amount: '$amountStr ROO',
            statusLabel: statusLabel,
            statusColor: statusColor,
            date: date,
            sender: sender,
            receiver: receiver,
            txHash: txHash,
            memo: memo,
            txType: txType == 'engagement_reward' ||
                    txType == 'post_reward' ||
                    txType == 'staking_reward' ||
                    txType == 'daily_bonus' ||
                    txType == 'signup_bonus'
                ? _rewardLabel(activityType, txType)
                : _titleCaseWords(effectiveType),
            referencePostId: tx['reference_post_id'] as String?,
            referenceCommentId: tx['reference_comment_id'] as String?,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountStr ROO',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  final String title;
  final String amount;
  final String statusLabel;
  final Color statusColor;
  final String date;
  final String sender;
  final String receiver;
  final String? txHash;
  final String? memo;
  final String txType;
  final String? referencePostId;
  final String? referenceCommentId;
  final double? balanceBefore;
  final double? balanceAfter;

  const _TransactionDetailsSheet({
    required this.title,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
    required this.date,
    required this.sender,
    required this.receiver,
    required this.txHash,
    required this.memo,
    required this.txType,
    required this.referencePostId,
    required this.referenceCommentId,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  Widget _row(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(context, 'Amount', amount),
            if (balanceBefore != null)
              _row(
                context,
                'Balance Before',
                '${balanceBefore!.toStringAsFixed(2)} ROO',
              ),
            if (balanceAfter != null)
              _row(
                context,
                'Balance After',
                '${balanceAfter!.toStringAsFixed(2)} ROO',
              ),
            _row(context, 'Type', txType),
            _row(context, 'Date', date),
            _row(context, 'Sender', sender),
            _row(context, 'Receiver', receiver),
            if (memo != null && memo!.trim().isNotEmpty)
              _row(context, 'Memo', memo!.trim()),
            if (txHash != null && txHash!.trim().isNotEmpty)
              _row(context, 'Tx Hash', txHash!.trim()),
            if (referencePostId != null && referencePostId!.trim().isNotEmpty)
              _row(context, 'Post Ref', referencePostId!.trim()),
            if (referenceCommentId != null &&
                referenceCommentId!.trim().isNotEmpty)
              _row(context, 'Comment Ref', referenceCommentId!.trim()),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


