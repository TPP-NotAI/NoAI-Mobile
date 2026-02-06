import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/staking_provider.dart';
import '../../config/app_colors.dart';
import 'send_roo_screen.dart';
import 'receive_roo_screen.dart';
import 'staking_screen.dart';
import 'transaction_history_screen.dart';
import '../../services/referral_service.dart';
import 'package:share_plus/share_plus.dart';

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

  // ROO brand colors (consistent across light/dark)
  static const Color _rooOrange = Color(0xFFFF8C00);
  static const Color _rooGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<WalletProvider>().refreshWallet(user.id);
        context.read<StakingProvider>().init(user.id);
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
                              'Join me on ROOVERSE and start earning ROO! Use my referral code: $_referralCode\nDownload at: https://rooverse.com',
                              subject: 'Join ROOVERSE - The Human Network',
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
    final user = context.watch<AuthProvider>().currentUser;
    final walletProvider = context.watch<WalletProvider>();
    final stakingProvider = context.watch<StakingProvider>();
    final wallet = walletProvider.wallet;
    final transactions = walletProvider.transactions;
    final colors = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: _rooOrange,
          onRefresh: () async {
            await context.read<WalletProvider>().refreshWallet(user.id);
            await context.read<StakingProvider>().refresh(user.id);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet Overview',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your RooCoin assets and track yield performance.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: walletProvider.isNetworkOnline
                                    ? AppColors.success
                                    : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              walletProvider.isNetworkOnline
                                  ? 'Online'
                                  : 'Offline',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (walletProvider.isLoading && wallet == null)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _rooOrange),
                  ),
                )
              else ...[
                // Main Balance Card (Full Width)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (!walletProvider.isWalletActivated)
                          _buildActivationBanner(
                            context,
                            walletProvider,
                            user.id,
                            colors,
                          ),
                        _buildMainBalanceCard(wallet, user.id, colors),
                      ],
                    ),
                  ),
                ),

                // APY and Total Earned Cards Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(child: _buildApyCard(stakingProvider, colors)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTotalEarnedCard(wallet, colors)),
                      ],
                    ),
                  ),
                ),

                // Balance Breakdown
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBreakdownCard(
                            'AVAILABLE',
                            wallet?.balanceRc ?? 0,
                            'ROO',
                            colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBreakdownCard(
                            'STAKED',
                            stakingProvider.userSummary.totalStaked,
                            'ROO',
                            colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBreakdownCard(
                            'PENDING',
                            stakingProvider.userSummary.pendingRewards,
                            'ROO',
                            colors,
                            isReward: true,
                          ),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Refer & Earn 50 ROO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Invite your friends to ROOVERSE and earn extra RooCoin for every verified human you refer!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                _showReferralSheet(context, user.id),
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

                // Recent Activity Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TransactionHistoryScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: _rooOrange,
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
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 14,
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

                      String label = 'Transaction';
                      if (tx.metadata != null &&
                          tx.metadata!['activityType'] != null) {
                        final type = tx.metadata!['activityType'] as String;
                        label = type.replaceAll('_', ' ').toLowerCase();
                        label = label
                            .split(' ')
                            .map(
                              (word) => word.isNotEmpty
                                  ? '${word[0].toUpperCase()}${word.substring(1)}'
                                  : '',
                            )
                            .join(' ');
                      } else if (tx.txType == 'transfer' &&
                          tx.fromUserId == user.id) {
                        label = 'Transfer to External Wallet';
                      } else if (tx.txType == 'fee') {
                        label = 'Platform Fee';
                      }

                      final date = DateFormat.yMMMd().format(tx.createdAt);
                      final statusColor = tx.status == 'completed'
                          ? AppColors.success
                          : _rooOrange;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    (isSent
                                            ? AppColors.error
                                            : AppColors.success)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSent ? Icons.north_east : Icons.south_west,
                                color: isSent
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isSent ? '-' : '+'}${_currencyFormat.format(amount)} ROO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSent
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tx.status == 'completed'
                                        ? 'Completed'
                                        : 'Pending',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }, childCount: transactions.length),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBalanceCard(
    dynamic wallet,
    String userId,
    ColorScheme colors,
  ) {
    final balance = wallet?.balanceRc ?? 0.0;
    final usdValue = balance * 0.16;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _rooOrange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: colors.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance.toStringAsFixed(2),
                style: const TextStyle(
                  color: _rooGold,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'ROO',
                  style: TextStyle(
                    color: _rooGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '≈ \$${usdValue.toStringAsFixed(2)} USD',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              _buildActionButton(
                'Stake',
                Icons.trending_up,
                AppColors.primary,
                true,
                colors,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StakingScreen()),
                  );
                },
              ),
              const SizedBox(width: 6),
              _buildActionButton('Send', Icons.send, null, false, colors, () {
                if (wallet != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SendRooScreen(currentBalance: wallet.balanceRc),
                    ),
                  );
                }
              }),
              const SizedBox(width: 6),
              _buildActionButton(
                'Receive',
                Icons.qr_code,
                null,
                false,
                colors,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceiveRooScreen()),
                  );
                },
              ),
              const SizedBox(width: 6),
              _buildActionButton(
                'Withdraw',
                Icons.account_balance,
                null,
                false,
                colors,
                () {
                  if (wallet != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SendRooScreen(currentBalance: wallet.balanceRc),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Network Status
          Row(
            children: [
              const Icon(Icons.circle, color: AppColors.success, size: 8),
              const SizedBox(width: 8),
              Text(
                'Connected to Sepolia Testnet',
                style: TextStyle(color: AppColors.success, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationBanner(
    BuildContext context,
    WalletProvider walletProvider,
    String userId,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rooOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activate Your Wallet',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Activate to receive tips and transfers. This creates your on-chain address.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: walletProvider.isLoading
                  ? null
                  : () async {
                      final ok =
                          await walletProvider.activateWallet(userId);
                      if (!context.mounted) return;
                      if (!ok) {
                        final msg = walletProvider.error ??
                            'Failed to activate wallet';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _rooOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: walletProvider.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Activate Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color? color,
    bool isPrimary,
    ColorScheme colors,
    VoidCallback onTap,
  ) {
    final buttonColor = color ?? AppColors.primary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isPrimary ? buttonColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isPrimary ? null : Border.all(color: colors.outline),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : buttonColor,
                size: 18,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : buttonColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApyCard(StakingProvider stakingProvider, ColorScheme colors) {
    final avgApy = stakingProvider.userSummary.avgApy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT APY',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.trending_up, color: AppColors.success, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avgApy > 0 ? '${avgApy.toStringAsFixed(1)}%' : '8.5%',
                style: const TextStyle(
                  color: _rooGold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '+0.05%',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalEarnedCard(dynamic wallet, ColorScheme colors) {
    final totalEarned = wallet?.lifetimeEarnedRc ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL EARNED',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.monetization_on, color: AppColors.success, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${totalEarned.toStringAsFixed(0)}',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'ROO',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '+0 this month',
            style: TextStyle(color: AppColors.success, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    String label,
    double value,
    String unit,
    ColorScheme colors, {
    bool isReward = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isReward
                    ? '+${value.toStringAsFixed(1)}'
                    : value.toStringAsFixed(1),
                style: TextStyle(
                  color: isReward ? AppColors.success : colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
