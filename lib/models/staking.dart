/// Staking tier configuration
class StakingTier {
  final String id;
  final String name;
  final double apyPercent;
  final double minAmount;
  final int lockDays;
  final String description;

  const StakingTier({
    required this.id,
    required this.name,
    required this.apyPercent,
    required this.minAmount,
    required this.lockDays,
    required this.description,
  });

  static const List<StakingTier> tiers = [
    StakingTier(
      id: 'flexible',
      name: 'Flexible',
      apyPercent: 3.0,
      minAmount: 100,
      lockDays: 0,
      description: 'No lock period, withdraw anytime',
    ),
    StakingTier(
      id: 'bronze',
      name: 'Bronze',
      apyPercent: 5.0,
      minAmount: 500,
      lockDays: 30,
      description: '30-day lock period',
    ),
    StakingTier(
      id: 'silver',
      name: 'Silver',
      apyPercent: 8.0,
      minAmount: 1000,
      lockDays: 90,
      description: '90-day lock period',
    ),
    StakingTier(
      id: 'gold',
      name: 'Gold',
      apyPercent: 12.0,
      minAmount: 5000,
      lockDays: 180,
      description: '180-day lock period',
    ),
    StakingTier(
      id: 'platinum',
      name: 'Platinum',
      apyPercent: 15.0,
      minAmount: 10000,
      lockDays: 365,
      description: '365-day lock period',
    ),
  ];

  static StakingTier? fromId(String id) {
    try {
      return tiers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// A user's staking position
class StakePosition {
  final String id;
  final String oderId;
  final String tierId;
  final double amountStaked;
  final double pendingRewards;
  final DateTime stakedAt;
  final DateTime? unlocksAt;
  final String status;

  StakePosition({
    required this.id,
    required this.oderId,
    required this.tierId,
    required this.amountStaked,
    required this.pendingRewards,
    required this.stakedAt,
    this.unlocksAt,
    required this.status,
  });

  StakingTier? get tier => StakingTier.fromId(tierId);

  bool get isLocked =>
      unlocksAt != null && DateTime.now().isBefore(unlocksAt!);

  int get daysRemaining {
    if (unlocksAt == null) return 0;
    final diff = unlocksAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory StakePosition.fromSupabase(Map<String, dynamic> json) {
    return StakePosition(
      id: json['id'] as String,
      oderId: json['user_id'] as String,
      tierId: json['tier_id'] as String,
      amountStaked: (json['amount_rc'] as num).toDouble(),
      pendingRewards: (json['pending_rewards'] as num?)?.toDouble() ?? 0.0,
      stakedAt: DateTime.parse(json['started_at'] as String),
      unlocksAt: json['unlocks_at'] != null
          ? DateTime.parse(json['unlocks_at'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': oderId,
        'tier_id': tierId,
        'amount_rc': amountStaked,
        'pending_rewards': pendingRewards,
        'started_at': stakedAt.toIso8601String(),
        'unlocks_at': unlocksAt?.toIso8601String(),
        'status': status,
      };
}

/// Network-wide staking statistics
class StakingStats {
  final double totalValueLocked;
  final int activeStakers;
  final double avgLockPeriod;
  final double rewardPool;

  StakingStats({
    required this.totalValueLocked,
    required this.activeStakers,
    required this.avgLockPeriod,
    required this.rewardPool,
  });

  factory StakingStats.empty() => StakingStats(
        totalValueLocked: 0,
        activeStakers: 0,
        avgLockPeriod: 0,
        rewardPool: 0,
      );

  factory StakingStats.fromJson(Map<String, dynamic> json) {
    return StakingStats(
      totalValueLocked: (json['total_value_locked'] as num?)?.toDouble() ?? 0,
      activeStakers: json['active_stakers'] as int? ?? 0,
      avgLockPeriod: (json['avg_lock_period'] as num?)?.toDouble() ?? 0,
      rewardPool: (json['reward_pool'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// User's staking summary
class UserStakingSummary {
  final double totalStaked;
  final double totalRewards;
  final double pendingRewards;
  final int activePositions;
  final double avgApy;

  UserStakingSummary({
    required this.totalStaked,
    required this.totalRewards,
    required this.pendingRewards,
    required this.activePositions,
    required this.avgApy,
  });

  factory UserStakingSummary.empty() => UserStakingSummary(
        totalStaked: 0,
        totalRewards: 0,
        pendingRewards: 0,
        activePositions: 0,
        avgApy: 0,
      );

  factory UserStakingSummary.fromPositions(List<StakePosition> positions) {
    if (positions.isEmpty) return UserStakingSummary.empty();

    double totalStaked = 0;
    double pendingRewards = 0;
    double weightedApy = 0;

    for (final pos in positions) {
      totalStaked += pos.amountStaked;
      pendingRewards += pos.pendingRewards;
      final tier = pos.tier;
      if (tier != null) {
        weightedApy += pos.amountStaked * tier.apyPercent;
      }
    }

    final avgApy = totalStaked > 0 ? weightedApy / totalStaked : 0.0;

    return UserStakingSummary(
      totalStaked: totalStaked,
      totalRewards: 0,
      pendingRewards: pendingRewards,
      activePositions: positions.where((p) => p.status == 'active').length,
      avgApy: avgApy,
    );
  }
}
