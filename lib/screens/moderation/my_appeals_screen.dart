import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
/// A record representing one appeal submitted by the user.
class _AppealRecord {
  final String appealId;
  final String appealStatus; // 'pending' | 'approved' | 'rejected'
  final String? statement;
  final DateTime submittedAt;

  // Moderation case fields
  final String caseStatus; // 'pending' | 'resolved' | 'dismissed'
  final String? postId;
  final String? commentId;
  final String? storyId;

  // Previews fetched from linked content
  final String? contentPreview;
  final String? contentType; // 'post' | 'comment' | 'story'

  const _AppealRecord({
    required this.appealId,
    required this.appealStatus,
    required this.statement,
    required this.submittedAt,
    required this.caseStatus,
    this.postId,
    this.commentId,
    this.storyId,
    this.contentPreview,
    this.contentType,
  });
}

class MyAppealsScreen extends StatefulWidget {
  const MyAppealsScreen({super.key});

  @override
  State<MyAppealsScreen> createState() => _MyAppealsScreenState();
}

class _MyAppealsScreenState extends State<MyAppealsScreen> {
  final _client = SupabaseService().client;

  List<_AppealRecord> _appeals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Fetch appeals joined with moderation_cases
      final rows = await _client
          .from(SupabaseConfig.appealsTable)
          .select(
            'id, status, statement, created_at, '
            'moderation_cases!inner(status, post_id, comment_id, story_id)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final records = <_AppealRecord>[];

      for (final row in rows as List<dynamic>) {
        final modCase =
            row['moderation_cases'] as Map<String, dynamic>? ?? {};
        final postId = modCase['post_id'] as String?;
        final commentId = modCase['comment_id'] as String?;
        final storyId = modCase['story_id'] as String?;

        String? contentPreview;
        String? contentType;

        // Fetch a text preview for the linked content
        if (postId != null) {
          contentType = 'post';
          try {
            final post = await _client
                .from(SupabaseConfig.postsTable)
                .select('content')
                .eq('id', postId)
                .maybeSingle();
            contentPreview = post?['content'] as String?;
          } catch (_) {}
        } else if (commentId != null) {
          contentType = 'comment';
          try {
            final comment = await _client
                .from(SupabaseConfig.commentsTable)
                .select('body')
                .eq('id', commentId)
                .maybeSingle();
            contentPreview = comment?['body'] as String?;
          } catch (_) {}
        } else if (storyId != null) {
          contentType = 'story';
          try {
            final story = await _client
                .from(SupabaseConfig.storiesTable)
                .select('caption, text_overlay')
                .eq('id', storyId)
                .maybeSingle();
            contentPreview = story?['caption'] as String? ??
                story?['text_overlay'] as String?;
          } catch (_) {}
        }

        records.add(_AppealRecord(
          appealId: row['id'] as String,
          appealStatus: (row['status'] as String? ?? 'pending').toLowerCase(),
          statement: row['statement'] as String?,
          submittedAt: DateTime.parse(row['created_at'] as String),
          caseStatus:
              (modCase['status'] as String? ?? 'pending').toLowerCase(),
          postId: postId,
          commentId: commentId,
          storyId: storyId,
          contentPreview: contentPreview,
          contentType: contentType,
        ));
      }

      if (mounted) {
        setState(() {
          _appeals = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load appeals. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text('My Appeals'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: scheme.onSurface),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(scheme)
          : _appeals.isEmpty
          ? _buildEmpty(scheme)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _appeals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _AppealCard(record: _appeals[i]),
              ),
            ),
    );
  }

  Widget _buildError(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: scheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: Text('Retry'.tr(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No Appeals Yet'.tr(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text('Appeals you submit for flagged content will appear here '
              'along with their review status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appeal card
// ─────────────────────────────────────────────────────────────────────────────

class _AppealCard extends StatelessWidget {
  final _AppealRecord record;

  const _AppealCard({required this.record});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.primary;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_top_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'UNDER REVIEW';
    }
  }

  String _contentTypeLabel(String? type) {
    switch (type) {
      case 'comment':
        return 'COMMENT';
      case 'story':
        return 'STORY';
      default:
        return 'POST';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(record.appealStatus);
    final borderColor = statusColor.withValues(alpha: 0.35);
    final headerBg = statusColor.withValues(alpha: 0.07);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(record.appealStatus),
                    color: statusColor, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${_contentTypeLabel(record.contentType)}  ·  '
                    '${_statusLabel(record.appealStatus)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(record.submittedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Content preview ──────────────────────────────────────
          if (record.contentPreview != null &&
              record.contentPreview!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORIGINAL CONTENT'.tr(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.contentPreview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                record.contentType == 'story'
                    ? '[Story — no text content]'
                    : '[Content no longer available]',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // ── Statement ────────────────────────────────────────────
          if (record.statement != null &&
              record.statement!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR STATEMENT'.tr(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.statement!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Status pill ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _StatusPill(
              appealStatus: record.appealStatus,
              caseStatus: record.caseStatus,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status pill — explains what is happening with the appeal
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String appealStatus;
  final String caseStatus;

  const _StatusPill({
    required this.appealStatus,
    required this.caseStatus,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (appealStatus) {
      case 'approved':
        message = 'Your appeal was approved. The flag has been removed.';
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        message =
            'Your appeal was reviewed and the flag was upheld.';
        bgColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      default:
        message =
            'Your appeal is being reviewed by our moderation team. '
            'This usually takes 1–3 business days.';
        bgColor = Colors.orange.withValues(alpha: 0.08);
        textColor = Colors.orange.shade700;
        icon = Icons.schedule_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
