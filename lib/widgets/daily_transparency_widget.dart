import 'package:flutter/material.dart';
import '../config/app_colors.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
/// Daily Transparency Report widget
/// Shows content moderation statistics
class DailyTransparencyWidget extends StatelessWidget {
  final int verifiedHumanContent;
  final int aiContentBlocked;
  final bool systemOperational;

  const DailyTransparencyWidget({
    super.key,
    required this.verifiedHumanContent,
    required this.aiContentBlocked,
    this.systemOperational = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Daily Transparency Report'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Verified Human Content
          _StatRow(
            label: 'Verified Human Content',
            value: _formatNumber(verifiedHumanContent),
            color: AppColors.success,
            icon: Icons.verified_user,
          ),
          const SizedBox(height: 12),

          // AI Content Blocked
          _StatRow(
            label: 'AI Content Blocked',
            value: _formatNumber(aiContentBlocked),
            color: AppColors.error,
            icon: Icons.block,
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 16),

          // System Status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: systemOperational ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                systemOperational ? 'System Operational' : 'System Issues',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
