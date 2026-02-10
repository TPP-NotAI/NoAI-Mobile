import 'package:flutter/material.dart';

/// A dialog for reporting a user with predefined reasons.
class ReportUserDialog extends StatefulWidget {
  final String username;

  const ReportUserDialog({super.key, required this.username});

  /// Shows the dialog and returns the report data if submitted.
  /// Returns a Map with 'reason' and optional 'details', or null if cancelled.
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String username,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => ReportUserDialog(username: username),
    );
  }

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();

  static const _reasons = [
    'Spam or fake account',
    'Harassment or bullying',
    'Hate speech or symbols',
    'Violence or dangerous content',
    'Nudity or sexual content',
    'Impersonation',
    'Scam or fraud',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.flag_outlined, color: colors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Report @${widget.username}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this user?',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((reason) => _ReasonTile(
                  reason: reason,
                  selected: _selectedReason == reason,
                  onTap: () => setState(() => _selectedReason = reason),
                )),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Please provide more details...',
                  hintStyle: TextStyle(color: colors.onSurfaceVariant),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  Navigator.pop(context, {
                    'reason': _selectedReason!,
                    if (_detailsController.text.trim().isNotEmpty)
                      'details': _detailsController.text.trim(),
                  });
                },
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
          ),
          child: const Text('Submit Report'),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.errorContainer.withValues(alpha: 0.3)
                : colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.error : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? colors.error : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: colors.onSurface,
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
}
