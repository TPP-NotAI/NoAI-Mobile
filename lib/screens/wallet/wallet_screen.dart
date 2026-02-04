import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import 'send_roo_screen.dart';
import 'receive_roo_screen.dart';
import '../../services/referral_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern();
  final ReferralService _referralService = ReferralService();
  String? _referralCode;
  bool _isLoadingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<WalletProvider>().refreshWallet(user.id);
        _fetchReferralCode(user.id);
      }
    });
  }

  Future<void> _fetchReferralCode(String userId) async {
    setState(() => _isLoadingCode = true);
    try {
      final code = await _referralService.generateReferralCode(userId);
      if (mounted) {
        setState(() {
          _referralCode = code;
          _isLoadingCode = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching referral code: $e');
      if (mounted) setState(() => _isLoadingCode = false);
    }
  }

  void _showReferralSheet(BuildContext context, String userId) {
    if (_referralCode == null && !_isLoadingCode) {
      _fetchReferralCode(userId);
    }

    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Icon(
                  Icons.card_giftcard,
                  size: 48,
                  color: Color(0xFF4A00E0),
                ),
                const SizedBox(height: 16),
                Text(
                  'Invite Friends',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your referral code and earn 50 ROO!\nFriend must complete human verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR REFERRAL CODE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _isLoadingCode
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _referralCode ?? 'ERROR',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: const Color(0xFF4A00E0),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _referralCode == null
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: _referralCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied to clipboard!'),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _referralCode == null
                        ? null
                        : () {
                            Share.share(
                              'Join me on NOAI and start earning ROO! Use my referral code: $_referralCode\nDownload at: https://noai.org',
                              subject: 'Join NOAI - The Human Network',
                            );
                          },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A00E0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<AuthProvider>().currentUser;
    final walletProvider = context.watch<WalletProvider>();
    final wallet = walletProvider.wallet;
    final transactions = walletProvider.transactions;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<WalletProvider>().refreshWallet(user.id);
          },
          child: CustomScrollView(
            slivers: [
              // Network Status
              SliverToBoxAdapter(
                child: walletProvider.isLoading && wallet == null
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: walletProvider.isNetworkOnline
                              ? colors.surfaceContainerHighest
                              : colors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: walletProvider.isNetworkOnline
                                    ? const Color(0xFF10B981)
                                    : colors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              walletProvider.isNetworkOnline
                                  ? 'Network Status: Online'
                                  : 'Network Status: Offline',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: walletProvider.isNetworkOnline
                                    ? colors.onSurfaceVariant
                                    : colors.onErrorContainer,
                              ),
                            ),
                            const Spacer(),
                            if (wallet != null)
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  // TODO: Copy wallet address
                                },
                                tooltip: 'Copy Address',
                              ),
                          ],
                        ),
                      ),
              ),

              // Total Balance Card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF8C00),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL BALANCE',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (walletProvider.isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            wallet != null
                                ? _currencyFormat.format(wallet.balanceRc)
                                : '0.00',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: const Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'ROO',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFFFFD700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '≈ \$${wallet != null ? _currencyFormat.format(wallet.balanceRc * 0.34) : '0.00'} USD',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFFFD700).withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReceiveRooScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              label: const Text('Earn Yield'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (wallet == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendRooScreen(
                                      currentBalance: wallet.balanceRc,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.account_balance_wallet,
                                size: 18,
                              ),
                              label: const Text('Spend'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFFD700),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFFFD700),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Current APY Card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT APY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '5.2%',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '+0.05%',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Refer & Earn Card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A00E0).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Refer & Earn 50 ROO',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Invite your friends to NOAI and earn extra RooCoin for every verified human you refer!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showReferralSheet(context, user.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A00E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Invite Friends',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Debug Tools (Dev Only)
              if (kDebugMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<WalletProvider>().debugEarnReward(user.id);
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Simulate Daily Login (+5 ROO)'),
                    ),
                  ),
                ),

              // Activities header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Recent Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Activity list
              if (transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: colors.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent activity',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = transactions[index];
                    final isSent =
                        tx.fromUserId == user.id ||
                        tx.txType == 'fee' ||
                        tx.txType == 'transfer';
                    final amount = tx.amountRc;

                    // Format activity type
                    String label = 'Transaction';
                    if (tx.metadata != null &&
                        tx.metadata!['activityType'] != null) {
                      final type = tx.metadata!['activityType'] as String;
                      label = type.replaceAll('_', ' ').toLowerCase();
                      // Capitalize first letter of each word
                      label = label
                          .split(' ')
                          .map((word) {
                            return word.isNotEmpty
                                ? '${word[0].toUpperCase()}${word.substring(1)}'
                                : '';
                          })
                          .join(' ');
                    } else if (tx.txType == 'transfer' &&
                        tx.fromUserId == user.id) {
                      label = 'Transfer to External Wallet';
                    } else if (tx.txType == 'fee') {
                      label = 'Platform Fee';
                    }

                    final date = DateFormat.yMMMd().format(tx.createdAt);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (isSent ? colors.error : Colors.green)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isSent ? Icons.north_east : Icons.south_west,
                              color: isSent ? colors.error : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(date, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            '${isSent ? '-' : '+'}${_currencyFormat.format(amount)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSent ? colors.error : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: transactions.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
