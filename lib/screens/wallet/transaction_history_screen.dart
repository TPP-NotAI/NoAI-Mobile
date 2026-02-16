import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Defer loading to after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = authProvider.currentUser?.id;

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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: userProvider.transactions.length,
                itemBuilder: (context, index) {
                  final tx = userProvider.transactions[index];
                  return _TransactionItem.fromData(
                    tx: tx,
                    currentUserId: currentUserId,
                  );
                },
              ),
            ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final String date;

  const _TransactionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.date,
  });

  factory _TransactionItem.fromData({
    required Map<String, dynamic> tx,
    required String? currentUserId,
  }) {
    final txType = tx['tx_type'] as String? ?? 'transfer';
    final fromUserId = tx['from_user_id'] as String?;
    final toUserId = tx['to_user_id'] as String?;
    final amountRc = (tx['amount_rc'] as num?)?.toDouble() ?? 0.0;
    final memo = tx['memo'] as String?;

    final isReceived = toUserId == currentUserId;
    final isFromSystem = fromUserId == null;

    // Determine transaction display info
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    String amountStr;
    Color amountColor;

    switch (txType) {
      case 'tip':
        icon = Icons.toll;
        iconColor = Colors.blue;
        if (isReceived) {
          title = 'Tip Received';
          subtitle = memo ?? 'From a supporter';
          amountStr = '+${amountRc.toStringAsFixed(2)}';
          amountColor = Colors.green;
        } else {
          title = 'Tip Sent';
          subtitle = memo ?? 'To a creator';
          amountStr = '-${amountRc.toStringAsFixed(2)}';
          amountColor = Colors.red;
        }
        break;
      case 'engagement_reward':
      case 'post_reward':
      case 'staking_reward':
      case 'daily_bonus':
        icon = Icons.attach_money;
        iconColor = Colors.green;
        title = 'Reward Earned';
        subtitle = memo ?? 'Daily reward';
        amountStr = '+${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.green;
        break;
      case 'signup_bonus':
        icon = Icons.card_giftcard;
        iconColor = Colors.purple;
        title = 'Signup Bonus';
        subtitle = 'Welcome to ROOVERSE!';
        amountStr = '+${amountRc.toStringAsFixed(2)}';
        amountColor = Colors.green;
        break;
      case 'transfer':
      case 'fee':
      default:
        if (isReceived) {
          icon = Icons.arrow_downward;
          iconColor = Colors.green;
          title = 'Received ROO';
          subtitle = memo ?? (isFromSystem ? 'System transfer' : 'Transfer');
          amountStr = '+${amountRc.toStringAsFixed(2)}';
          amountColor = Colors.green;
        } else {
          icon = Icons.arrow_upward;
          iconColor = Colors.red;
          title = 'Sent ROO';
          subtitle = memo ?? 'Transfer';
          amountStr = '-${amountRc.toStringAsFixed(2)}';
          amountColor = Colors.red;
        }
        break;
    }

    return _TransactionItem(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      amount: amountStr,
      amountColor: amountColor,
      date: tx['created_at'] != null
          ? (DateFormat.yMMMd().add_jm().format(
              DateTime.parse(tx['created_at'] as String).toLocal(),
            ))
          : 'Unknown date',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
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
          Text(
            '$amount ROO',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
