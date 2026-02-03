import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/post_repository.dart';
import '../../repositories/comment_repository.dart';
import '../../utils/time_utils.dart';
import 'appeal_form_screen.dart';

class ModQueueScreen extends StatefulWidget {
  const ModQueueScreen({super.key});

  @override
  State<ModQueueScreen> createState() => _ModQueueScreenState();
}

class _ModQueueScreenState extends State<ModQueueScreen> {
  // Filters (Visual only for now, could be wired up later)
  final String _selectedFilter = 'Priority';
  final String _selectedSort = 'Most Reported';
  final String _selectedType = 'Violation Type';

  List<dynamic> _mergedQueue = [];
  Map<String, Map<String, dynamic>> _modMetadata = {};
  Map<String, Map<String, dynamic>> _commentModMetadata = {};
  bool _isLoading = true;
  String? _currentUserId;

  final PostRepository _postRepo = PostRepository();
  final CommentRepository _commentRepo = CommentRepository();

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().currentUser?.id;
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    setState(() => _isLoading = true);
    try {
      // Fetch flagged posts and comments in parallel
      final results = await Future.wait([
        _postRepo.getModerationQueue(),
        _commentRepo.getFlaggedComments(),
      ]);
      final posts = results[0] as List<Post>;
      final comments = results[1] as List<Comment>;

      // Fetch moderation metadata for both
      final metadataResults = await Future.wait([
        _postRepo.getModerationMetadata(posts.map((p) => p.id).toList()),
        _commentRepo.getCommentModerationMetadata(
          comments.map((c) => c.id).toList(),
        ),
      ]);

      if (mounted) {
        // Merge and sort by timestamp descending
        final List<dynamic> merged = [...posts, ...comments];
        merged.sort((a, b) {
          final timeA = a is Post ? a.timestamp : (a as Comment).timestamp;
          final timeB = b is Post ? b.timestamp : (b as Comment).timestamp;
          return DateTime.parse(timeB).compareTo(DateTime.parse(timeA));
        });

        setState(() {
          _mergedQueue = merged;
          _modMetadata = metadataResults[0];
          _commentModMetadata = metadataResults[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading queue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mod Queue',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: scheme.onSurface,
            onPressed: _fetchQueue,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards (Mock for now or could count list)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.warning,
                    iconColor: Colors.orange,
                    label: 'BACKLOG',
                    value: _mergedQueue.length.toString(),
                    subtitle: 'Pending Review',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.check_circle,
                    iconColor: Colors.blue,
                    label: 'DAILY ACTIONS',
                    value: '45', // Placeholder
                    subtitle: 'Target: 100',
                  ),
                ),
              ],
            ),
          ),

          // Filters (Visual Only)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: _selectedFilter,
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedSort,
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedType,
                  isPrimary: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Queue Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mergedQueue.isEmpty
                ? Center(
                    child: Text(
                      'All caught up!',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _mergedQueue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _mergedQueue[index];
                      if (item is Post) {
                        return _buildPostItem(context, item);
                      } else if (item is Comment) {
                        return _buildCommentItem(context, item);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isPrimary,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? AppColors.primary : scheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : scheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: isPrimary ? Colors.white : scheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(BuildContext context, Post post) {
    final scheme = Theme.of(context).colorScheme;
    final confidence = post.aiConfidenceScore ?? 0;
    final violationColor = confidence >= 75
        ? Colors.red
        : confidence >= 50
        ? Colors.orange
        : Colors.yellow.shade800;
    final confidenceLabel = confidence >= 75
        ? 'High Confidence'
        : confidence >= 50
        ? 'Medium Confidence'
        : 'Low Confidence';

    // Get moderation case metadata for this post
    final modCase = _modMetadata[post.id];
    final rawMetadata = modCase?['ai_metadata'];
    final aiMetadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : <String, dynamic>{};
    final rationale = aiMetadata['rationale'] as String?;
    final combinedEvidence = (aiMetadata['combined_evidence'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final consensusStrength = aiMetadata['consensus_strength'] as String?;
    final classification = aiMetadata['classification'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Violation Header
          Row(
            children: [
              Icon(Icons.auto_awesome, color: violationColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  classification ?? 'AI Content Detected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: violationColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: violationColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  confidenceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: violationColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // User Info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.onSurface.withOpacity(0.1),
                backgroundImage: post.author.avatar.isNotEmpty
                    ? NetworkImage(post.author.avatar)
                    : null,
                child: post.author.avatar.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: scheme.onSurface.withOpacity(0.5),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author.username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          humanReadableTime(post.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    if (post.author.isVerified)
                      Row(
                        children: const [
                          Icon(Icons.verified, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Verified Human',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content
          Text(
            post.content,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
          ),

          if (post.hasMedia && post.primaryMediaUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.background,
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(post.primaryMediaUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          // AI Analysis Results (collapsible)
          const SizedBox(height: 12),
          _AiAnalysisCard(
            confidence: confidence,
            violationColor: violationColor,
            consensusStrength: consensusStrength,
            rationale: rationale,
            combinedEvidence: combinedEvidence,
          ),

          // Moderation action buttons (for moderators, not the post author)
          if (_currentUserId != null &&
              post.author.userId != _currentUserId) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleModeration(post.id, 'approve'),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleModeration(post.id, 'reject'),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Appeal button — only for current user's own posts
          if (_currentUserId != null &&
              post.author.userId == _currentUserId) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppealFormScreen(post: post),
                    ),
                  );
                },
                icon: const Icon(Icons.gavel, size: 18),
                label: const Text('Appeal This Decision'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(BuildContext context, Comment comment) {
    final scheme = Theme.of(context).colorScheme;
    final confidence = comment.aiScore ?? 0;
    final violationColor = confidence >= 75
        ? Colors.red
        : confidence >= 50
        ? Colors.orange
        : Colors.yellow.shade800;
    final confidenceLabel = confidence >= 75
        ? 'High Confidence'
        : confidence >= 50
        ? 'Medium Confidence'
        : 'Low Confidence';

    // Get moderation case metadata for this comment
    final modCase = _commentModMetadata[comment.id];
    final rawMetadata = modCase?['ai_metadata'];
    final aiMetadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : <String, dynamic>{};
    final rationale = aiMetadata['rationale'] as String?;
    final combinedEvidence = (aiMetadata['combined_evidence'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final consensusStrength = aiMetadata['consensus_strength'] as String?;
    final classification = aiMetadata['classification'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment label + violation header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'COMMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.auto_awesome, color: violationColor, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  classification ?? 'AI Content Detected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: violationColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: violationColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  confidenceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: violationColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Comment author
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.onSurface.withOpacity(0.1),
                backgroundImage:
                    comment.author.avatar != null &&
                        comment.author.avatar!.isNotEmpty
                    ? NetworkImage(comment.author.avatar!)
                    : null,
                child:
                    (comment.author.avatar == null ||
                        comment.author.avatar!.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: 18,
                        color: scheme.onSurface.withOpacity(0.5),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                comment.author.username,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                humanReadableTime(comment.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Comment text
          Text(
            comment.text,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
          ),

          // AI Analysis (collapsible)
          const SizedBox(height: 12),
          _AiAnalysisCard(
            confidence: confidence,
            violationColor: violationColor,
            consensusStrength: consensusStrength,
            rationale: rationale,
            combinedEvidence: combinedEvidence,
          ),

          // Appeal entry point for comments
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppealFormScreen(comment: comment),
                  ),
                );
              },
              icon: const Icon(Icons.gavel, size: 18),
              label: const Text('Appeal This Decision'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleModeration(String postId, String action) async {
    final success = await _postRepo.moderatePost(
      postId: postId,
      action: action,
      moderatorId: _currentUserId,
    );
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approve'
                  ? 'Post approved and published'
                  : 'Post rejected',
            ),
          ),
        );
        _fetchQueue(); // Refresh the queue
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to moderate post')),
        );
      }
    }
  }
}

/// Collapsible AI analysis card that shows confidence by default
/// and expands to show rationale + evidence on tap.
class _AiAnalysisCard extends StatefulWidget {
  final double confidence;
  final Color violationColor;
  final String? consensusStrength;
  final String? rationale;
  final List<String>? combinedEvidence;

  const _AiAnalysisCard({
    required this.confidence,
    required this.violationColor,
    this.consensusStrength,
    this.rationale,
    this.combinedEvidence,
  });

  @override
  State<_AiAnalysisCard> createState() => _AiAnalysisCardState();
}

class _AiAnalysisCardState extends State<_AiAnalysisCard> {
  bool _expanded = false;

  bool get _hasDetails =>
      (widget.rationale != null && widget.rationale!.isNotEmpty) ||
      (widget.combinedEvidence != null && widget.combinedEvidence!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — always visible
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI ANALYSIS RESULTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (widget.consensusStrength != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.consensusStrength!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Confidence score — always visible
          Row(
            children: [
              Text(
                'Confidence: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '${widget.confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.violationColor,
                ),
              ),
            ],
          ),

          // Expanded details (rationale + evidence)
          if (_expanded) ...[
            if (widget.rationale != null && widget.rationale!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Rationale',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.rationale!,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
            if (widget.combinedEvidence != null &&
                widget.combinedEvidence!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Evidence',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              ...widget.combinedEvidence!.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ' \u2022 ',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.8),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          // "Read more" / "Show less" toggle
          if (_hasDetails) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
