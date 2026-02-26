import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
/// Human verification badge matching web design
/// Shows when AI confidence score is < 20%
class HumanVerificationBadge extends StatelessWidget {
  final double aiConfidenceScore;
  final String? verificationMethod;

  const HumanVerificationBadge({
    super.key,
    required this.aiConfidenceScore,
    this.verificationMethod,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final aiPercentage = aiConfidenceScore.toStringAsFixed(2);
    final isPassed = aiConfidenceScore < 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ML Score badge (web format)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.success, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text('HUMAN SCORE: $aiPercentage% [${isPassed ? 'PASS'.tr(context) : 'FAIL'.tr(context)}]',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (verificationMethod != null) ...[
              const SizedBox(width: 12),
              Text(
                verificationMethod!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact verified badge (just icon and text, for user cards)
class VerifiedBadge extends StatelessWidget {
  final bool isSmall;

  const VerifiedBadge({super.key, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified, size: isSmall ? 14 : 16, color: AppColors.success),
        SizedBox(width: isSmall ? 3 : 4),
        Text('Verified'.tr(context),
          style: TextStyle(
            fontSize: isSmall ? AppTypography.tiny : AppTypography.extraSmall,
            fontWeight: AppTypography.medium,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}
