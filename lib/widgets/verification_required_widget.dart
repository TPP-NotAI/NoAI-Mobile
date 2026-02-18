import 'package:flutter/material.dart';

class VerificationRequiredWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onVerifyTap;

  const VerificationRequiredWidget({
    super.key,
    required this.message,
    this.onVerifyTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (onVerifyTap != null) {
                  onVerifyTap!();
                } else {
                  Navigator.pushNamed(context, '/verify');
                }
              },
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('Verify Now'),
            ),
          ),
        ],
      ),
    );
  }
}
