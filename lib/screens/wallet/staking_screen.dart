import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/staking.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staking_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/app_colors.dart';

class StakingScreen extends StatefulWidget {
  const StakingScreen({super.key});

  @override
  State<StakingScreen> createState() => _StakingScreenState();
}

class _StakingScreenState extends State<StakingScreen> {
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();
  bool _isStaking = false;

  // ROO brand colors (consistent across light/dark)
  static const Color _rooOrange = Color(0xFFFF8C00);
  static const Color _rooGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<StakingProvider>().init(userId);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _stake() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    setState(() => _isStaking = true);

    final success = await context.read<StakingProvider>().stake(
          userId: userId,
          amount: amount,
        );

    setState(() => _isStaking = false);

    if (success && mounted) {
      _amountController.clear();
      // Refresh wallet balance
      context.read<WalletProvider>().refreshWallet(userId);
      _showSuccess('Successfully staked ${amount.toStringAsFixed(2)} ROO!');
    } else if (mounted) {
      final error = context.read<StakingProvider>().error;
      _showError(error ?? 'Failed to stake');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stakingProvider = context.watch<StakingProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final wallet = walletProvider.wallet;
    final colors = Theme.of(context).colorScheme;

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
          'Staking & Reputation',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Network: Operational',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: stakingProvider.isLoading && stakingProvider.positions.isEmpty
          ? Center(child: CircularProgressIndicator(color: _rooOrange))
          : RefreshIndicator(
              color: _rooOrange,
              onRefresh: () async {
                final userId = context.read<AuthProvider>().currentUser?.id;
                if (userId != null) {
                  await context.read<StakingProvider>().refresh(userId);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header subtitle
                    Text(
                      'Lock your RooCoin to validate your humanity, earn yields, and gain visibility priority.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary Cards - Full width stacked
                    _buildSummaryCard(
                      'TOTAL STAKED',
                      '${stakingProvider.userSummary.totalStaked.toStringAsFixed(0)} ROO',
                      '${stakingProvider.userSummary.activePositions} active position(s)',
                      _rooOrange,
                      colors,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'AVG APY',
                            '${stakingProvider.userSummary.avgApy.toStringAsFixed(1)}%',
                            'Based on tier',
                            colors.onSurface,
                            colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'REWARDS',
                            '${stakingProvider.userSummary.pendingRewards.toStringAsFixed(2)}',
                            'ROO pending',
                            AppColors.success,
                            colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // User Profile Card
                    _buildUserProfileCard(user, wallet, stakingProvider, colors),
                    const SizedBox(height: 16),

                    // Staking Tiers Section
                    _buildSectionHeader(Icons.emoji_events, 'Staking Tiers', colors),
                    const SizedBox(height: 16),
                    _buildTierGrid(stakingProvider, colors),
                    const SizedBox(height: 24),

                    // Stake Form
                    _buildStakeForm(stakingProvider, wallet?.balanceRc ?? 0, colors),
                    const SizedBox(height: 24),

                    // Staking Benefits
                    _buildStakingBenefits(colors),
                    const SizedBox(height: 24),

                    // Network Stats
                    _buildNetworkStatsCard(stakingProvider, colors),
                    const SizedBox(height: 16),

                    // Quick Actions
                    _buildQuickActions(colors),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, Color valueColor, ColorScheme colors) {
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
            title,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: valueColor.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ColorScheme colors) {
    return Row(
      children: [
        Icon(icon, color: _rooOrange, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTierGrid(StakingProvider provider, ColorScheme colors) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: provider.tiers.map((tier) {
        final isSelected = provider.selectedTier.id == tier.id;
        return _buildTierCard(tier, isSelected, () => provider.selectTier(tier), colors);
      }).toList(),
    );
  }

  Widget _buildTierCard(StakingTier tier, bool isSelected, VoidCallback onTap, ColorScheme colors) {
    final tierColors = {
      'flexible': colors.onSurface,
      'bronze': const Color(0xFFCD7F32),
      'silver': const Color(0xFFC0C0C0),
      'gold': _rooGold,
      'platinum': const Color(0xFFE5E4E2),
    };

    final color = tierColors[tier.id] ?? colors.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _rooOrange : colors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tier.name,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${tier.apyPercent.toStringAsFixed(0)}% APY',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Min: ${_numberFormat.format(tier.minAmount)} ROO',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Text(
              'Lock: ${tier.lockDays} days',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tier.description,
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStakeForm(StakingProvider provider, double availableBalance, ColorScheme colors) {
    final projectedEarnings = provider.calculateProjectedEarnings(
      double.tryParse(_amountController.text) ?? 0,
    );
    final unlockDate = provider.getUnlockDate();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.tune, 'Stake RooCoin', colors),
          const SizedBox(height: 20),

          // Amount Input
          Text(
            'Amount to Stake',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(color: colors.onSurface, fontSize: 18),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintText: '0',
                hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                suffixIcon: TextButton(
                  onPressed: () {
                    _amountController.text = availableBalance.toStringAsFixed(2);
                    setState(() {});
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('MAX', style: TextStyle(color: _rooOrange)),
                      const SizedBox(width: 4),
                      Text('ROO', style: TextStyle(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available: ${availableBalance.toStringAsFixed(2)} ROO',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Lock Period Display
          Text(
            'Lock Period',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.selectedTier.name} Tier',
                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${provider.selectedTier.lockDays} Days',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlockDate != null
                ? 'Unlock: ${DateFormat.yMMMd().format(unlockDate)}'
                : 'Flexible - withdraw anytime',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Projected Earnings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Projected Earnings',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                    ),
                    Text(
                      '+${projectedEarnings.toStringAsFixed(2)} ROO',
                      style: const TextStyle(
                        color: _rooOrange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on ${provider.selectedTier.apyPercent.toStringAsFixed(0)}% APY for ${provider.selectedTier.lockDays > 0 ? provider.selectedTier.lockDays : 365} days',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stake Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isStaking ? null : _stake,
              icon: _isStaking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                _isStaking ? 'STAKING...' : 'STAKE ROOCOIN',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _rooGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStakingBenefits(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _rooOrange.withValues(alpha: 0.1),
            _rooOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rooOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: _rooOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Staking Benefits',
                style: TextStyle(
                  color: _rooOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(Icons.trending_up, 'Earn Yield', 'Up to 15% APY on staked tokens', colors),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.visibility, 'Priority Visibility', 'Higher ranking in feeds', colors),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.verified_user, 'Trust Boost', 'Increased reputation score', colors),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description, ColorScheme colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _rooOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _rooOrange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _rooOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileCard(dynamic user, dynamic wallet, StakingProvider provider, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colors.outline,
                backgroundImage: user?.avatar != null ? NetworkImage(user!.avatar!) : null,
                child: user?.avatar == null
                    ? Icon(Icons.person, size: 40, color: colors.onSurfaceVariant)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'User',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Verified Human',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Trust Score Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 Trust Score',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                  Text(
                    'Max: 1000',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0,
                backgroundColor: colors.outline,
                valueColor: const AlwaysStoppedAnimation<Color>(_rooOrange),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.outline),
          const SizedBox(height: 16),

          // Stats
          _buildProfileStatRow('Wallet Balance', '${wallet?.balanceRc.toStringAsFixed(2) ?? '0'} ROO', colors),
          const SizedBox(height: 8),
          _buildProfileStatRow('Total Staked', '${provider.userSummary.totalStaked.toStringAsFixed(0)} ROO', colors),
          const SizedBox(height: 8),
          _buildProfileStatRow(
            'Pending Rewards',
            '+${provider.userSummary.pendingRewards.toStringAsFixed(2)} ROO',
            colors,
            valueColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatRow(String label, String value, ColorScheme colors, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkStatsCard(StakingProvider provider, ColorScheme colors) {
    final stats = provider.networkStats;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network Stats',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildNetworkStatRow(
            'Total Value Locked',
            '${_formatLargeNumber(stats?.totalValueLocked ?? 0)} ROO',
            colors,
          ),
          const SizedBox(height: 8),
          _buildNetworkStatRow(
            'Active Stakers',
            _numberFormat.format(stats?.activeStakers ?? 0),
            colors,
          ),
          const SizedBox(height: 8),
          _buildNetworkStatRow(
            'Avg. Lock Period',
            '${stats?.avgLockPeriod.toStringAsFixed(0) ?? '0'} days',
            colors,
          ),
          const SizedBox(height: 8),
          _buildNetworkStatRow(
            'Reward Pool',
            '${_formatLargeNumber(stats?.rewardPool ?? 0)} ROO',
            colors,
          ),
        ],
      ),
    );
  }

  String _formatLargeNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return _numberFormat.format(value);
  }

  Widget _buildNetworkStatRow(String label, String value, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
            Icons.account_balance_wallet,
            'View Wallet',
            () => Navigator.pop(context),
            colors,
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.verified_user,
            'Verify Identity',
            () {},
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap, ColorScheme colors) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.outline,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
