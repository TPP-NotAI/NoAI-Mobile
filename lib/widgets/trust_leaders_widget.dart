import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Trust Leaders widget - shows top users by trust score
/// Displays as horizontal scroll on mobile, sidebar on web
class TrustLeadersWidget extends StatelessWidget {
  final List<TrustLeader> leaders;

  const TrustLeadersWidget({super.key, required this.leaders});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trust Leaders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full leaderboard
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Leaders list (horizontal scroll)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: leaders.length,
              itemBuilder: (context, index) {
                final leader = leaders[index];
                return _LeaderCard(leader: leader, rank: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final TrustLeader leader;
  final int rank;

  const _LeaderCard({required this.leader, required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary.withValues(alpha: 0.2),
                backgroundImage: leader.avatar.isNotEmpty
                    ? NetworkImage(leader.avatar)
                    : null,
                child: leader.avatar.isEmpty
                    ? Icon(Icons.person, size: 16, color: colors.primary)
                    : null,
              ),
              const SizedBox(width: 8),
              // Rank badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getRankColor(rank),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Username
          Text(
            '@${leader.username}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Trust score
          Row(
            children: [
              Icon(
                Icons.verified,
                size: 12,
                color: AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                '${leader.trustScore.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFCD34D); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.primary;
    }
  }
}

/// Trust Leader model
class TrustLeader {
  final String username;
  final String displayName;
  final String avatar;
  final double trustScore;
  final String bio;

  TrustLeader({
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.trustScore,
    this.bio = '',
  });
}
