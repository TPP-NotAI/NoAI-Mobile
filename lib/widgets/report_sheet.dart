import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import 'report_confirmation_dialog.dart';

class ReportSheet extends StatefulWidget {
  final String reportType; // 'post', 'user', 'comment'
  final String
  referenceId; // postId, userId (for user report, this is reportedUserId), commentId
  final String
  reportedUserId; // The user ID of the person being reported (redundant for user report but good for consistency)
  final String? username; // Optional username for display in confirmation

  const ReportSheet({
    super.key,
    required this.reportType,
    required this.referenceId,
    required this.reportedUserId,
    this.username,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _reportReasons = [
    {
      'icon': Icons.shield_outlined,
      'label': 'Spam or misleading',
      'value': 'spam',
    },
    {
      'icon': Icons.sentiment_dissatisfied,
      'label': 'Harassment or hate speech',
      'value': 'harassment',
    },
    {
      'icon': Icons.warning_amber,
      'label': 'Violence or dangerous content',
      'value': 'violence',
    },
    {
      'icon': Icons.visibility_off,
      'label': 'Inappropriate content',
      'value': 'inappropriate',
    },
    {
      'icon': Icons.copyright,
      'label': 'Copyright infringement',
      'value': 'copyright',
    },
    {
      'icon': Icons.smart_toy,
      'label': 'Suspected AI-generated content',
      'value': 'ai_generated',
    },
    {'icon': Icons.report_outlined, 'label': 'Other', 'value': 'other'},
  ];

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    bool success = false;
    String? error;

    if (widget.reportType == 'post') {
      final feedProvider = context.read<FeedProvider>();
      success = await feedProvider.reportPost(
        postId: widget.referenceId,
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
      );
    } else if (widget.reportType == 'user') {
      final userProvider = context.read<UserProvider>();
      success = await userProvider.reportUser(
        reportedUserId:
            widget.referenceId, // For user report, referenceId is the userId
        reason: _selectedReason!,
      );
      error = userProvider.error;
    } else {
      // TODO: Handle comment reporting if needed
      error = 'Reporting comments not implemented yet';
    }

    if (!mounted) return;

    // Close the bottom sheet
    Navigator.pop(context);

    // Show confirmation dialog or error
    if (success) {
      await ReportConfirmationDialog.show(
        context,
        type: widget.reportType,
        username: widget.username,
      );
    } else {
      // Show error snackbar if report failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to submit report. Please try again.'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = widget.reportType == 'user' ? 'Report User' : 'Report Post';

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.reportType == 'user'
                  ? 'Why are you reporting this user?'
                  : 'Why are you reporting this post?',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Report reasons
            ...List.generate(_reportReasons.length, (index) {
              final reason = _reportReasons[index];
              final isSelected = _selectedReason == reason['value'];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedReason = reason['value']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.1)
                        : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : colors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        reason['icon'] as IconData,
                        color: isSelected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          reason['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: colors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitReport,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
