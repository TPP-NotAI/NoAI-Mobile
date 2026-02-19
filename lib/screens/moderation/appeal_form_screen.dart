import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../models/story.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/appeal_repository.dart';

class AppealFormScreen extends StatefulWidget {
  final Post? post;
  final Comment? comment;
  final Story? story;

  const AppealFormScreen({
    super.key,
    this.post,
    this.comment,
    this.story,
  }) : assert(
          (post != null ? 1 : 0) +
                  (comment != null ? 1 : 0) +
                  (story != null ? 1 : 0) ==
              1,
          'Provide exactly one of post, comment, or story.',
        );

  @override
  State<AppealFormScreen> createState() => _AppealFormScreenState();
}

class _AppealFormScreenState extends State<AppealFormScreen> {
  final _statementController = TextEditingController();
  final _appealRepo = AppealRepository();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final statement = _statementController.text.trim();
    if (statement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please explain why you are appealing.')),
      );
      return;
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      final postId = widget.post?.id;
      final commentId = widget.comment?.id;
      final storyId = widget.story?.id;

      // Check for existing appeal
      final alreadyAppealed = await _appealRepo.hasExistingAppeal(
        userId: currentUser.id,
        postId: postId,
        commentId: commentId,
        storyId: storyId,
      );

      if (alreadyAppealed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already submitted an appeal for this item.'),
            ),
          );
        }
        return;
      }

      // Create moderation case if needed
      final aiConfidence = widget.post?.aiConfidenceScore ??
          widget.comment?.aiScore ??
          widget.story?.aiScore ??
          0.0;

      final caseId = await _appealRepo.getOrCreateModerationCase(
        postId: postId,
        commentId: commentId,
        storyId: storyId,
        reportedUserId: currentUser.id,
        aiConfidence: aiConfidence,
      );

      if (caseId == null) {
        throw Exception('Failed to create moderation case');
      }

      // Submit the appeal
      final success = await _appealRepo.submitAppeal(
        userId: currentUser.id,
        moderationCaseId: caseId,
        statement: statement,
      );

      if (!success) {
        throw Exception('Failed to submit appeal');
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Appeal Submitted'),
            content: const Text(
              'Your appeal has been received. Our team will review it.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // true = appeal was submitted
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting appeal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final post = widget.post;
    final comment = widget.comment;
    final story = widget.story;
    final title = post != null
        ? 'Post Appeal'
        : story != null
        ? 'Story Appeal'
        : 'Comment Appeal';
    final bodyPreview = post?.content ?? comment?.text ?? story?.caption ?? '';

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context card showing flagged post
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post != null
                        ? 'FLAGGED POST'
                        : story != null
                        ? 'FLAGGED STORY'
                        : 'FLAGGED COMMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bodyPreview,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                  if (post?.aiConfidenceScore != null ||
                      comment?.aiScore != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'AI Confidence: ${post != null ? post.aiConfidenceScore!.toStringAsFixed(1) : (comment?.aiScore ?? 0).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Your Statement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Explain why this post should not be flagged as AI-generated.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statementController,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Write your appeal statement...',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
                        'Submit Appeal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
