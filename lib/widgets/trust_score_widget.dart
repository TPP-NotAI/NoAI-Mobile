import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/app_typography.dart';

/// Trust score widget with gradient progress bar matching web design
class TrustScoreWidget extends StatelessWidget {
  final double score; // 0-100
  final bool showLabel;

  const TrustScoreWidget({
    super.key,
    required this.score,
    this.showLabel = true,
  });

  Color _getScoreColor() {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trust Score',
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: AppTypography.semiBold,
                ).copyWith(color: colors.onSurface),
              ),
              Text(
                '${score.toInt()}/100',
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: AppTypography.bold,
                ).copyWith(color: _getScoreColor()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.mediumSmall),
        ],
        // Progress bar container
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: colors.brightness == Brightness.dark
                ? AppColors.outlineDark
                : AppColors.outlineLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: Stack(
              children: [
                // Filled portion with gradient
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.trustScoreGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact trust score badge for user cards
class TrustScoreBadge extends StatelessWidget {
  final double score;

  const TrustScoreBadge({super.key, required this.score});

  Color _getScoreColor() {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mediumSmall,
        vertical: AppSpacing.extraSmall,
      ),
      decoration: BoxDecoration(
        color: _getScoreColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: _getScoreColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 12, color: _getScoreColor()),
          const SizedBox(width: 4),
          Text(
            '${score.toInt()}',
            style: TextStyle(
              fontSize: AppTypography.extraSmall,
              fontWeight: AppTypography.bold,
              color: _getScoreColor(),
            ),
          ),
        ],
      ),
    );
  }
}
