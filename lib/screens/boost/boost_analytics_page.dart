import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class BoostAnalyticsPage extends StatefulWidget {
  /// If provided, shows analytics for this specific post only.
  /// If null, shows all boosts across all posts.
  final Post? post;

  const BoostAnalyticsPage({super.key, this.post});

  @override
  State<BoostAnalyticsPage> createState() => _BoostAnalyticsPageState();
}

class _BoostAnalyticsPageState extends State<BoostAnalyticsPage> {
  List<_BoostRecord> _boosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final client = SupabaseService().client;

      // Query boost transactions for this user
      var query = client
          .from('roocoin_transactions')
          .select()
          .eq('from_user_id', userId)
          .eq('tx_type', 'fee');

      final List<dynamic> rows = await query
          .order('created_at', ascending: false)
          .limit(100);

      // Filter to POST_BOOST only
      final boostRows = rows.where((r) {
        final meta = r['metadata'] as Map<String, dynamic>?;
        return meta?['activityType'] == 'POST_BOOST';
      }).toList();

      // Fetch associated post data
      final postIds = boostRows
          .map((r) {
            final meta = r['metadata'] as Map<String, dynamic>?;
            return meta?['referencePostId'] as String?;
          })
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> postData = {};
      if (postIds.isNotEmpty) {
        final postRows = await client
            .from('posts')
            .select('id, body, title, views_count, likes_count, comments_count, reposts_count, shares_count')
            .inFilter('id', postIds);
        for (final p in postRows as List<dynamic>) {
          postData[p['id'] as String] = p as Map<String, dynamic>;
        }
      }

      // Build records — filter to specific post if provided
      final records = boostRows.map((r) {
        final meta = r['metadata'] as Map<String, dynamic>?;
        final postId = meta?['referencePostId'] as String?;
        final pd = postId != null ? postData[postId] : null;
        return _BoostRecord(
          txId: r['id'] as String,
          postId: postId,
          amountRoo: (r['amount_rc'] as num).toDouble(),
          targetUsers: (meta?['targetUsers'] as num?)?.toInt() ?? 0,
          boostedAt: DateTime.parse(r['created_at'] as String),
          postTitle: pd?['title'] as String? ??
              (pd?['body'] as String? ?? '').split('\n').first,
          postViews: (pd?['views_count'] as num?)?.toInt() ?? 0,
          postLikes: (pd?['likes_count'] as num?)?.toInt() ?? 0,
          postComments: (pd?['comments_count'] as num?)?.toInt() ?? 0,
          postReposts: (pd?['reposts_count'] as num?)?.toInt() ?? 0,
        );
      }).where((rec) {
        if (widget.post == null) return true;
        return rec.postId == widget.post!.id;
      }).toList();

      setState(() {
        _boosts = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSpecificPost = widget.post != null;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          isSpecificPost ? 'Boost Analytics' : 'All Boosts',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _load)
          : _boosts.isEmpty
          ? _EmptyState(isSpecificPost: isSpecificPost)
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── Summary header ──────────────────────────
                  SliverToBoxAdapter(
                    child: _SummaryHeader(boosts: _boosts, colors: colors, theme: theme),
                  ),

                  // ── Boost cards ─────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _BoostCard(
                          boost: _boosts[i],
                          showPostTitle: !isSpecificPost,
                          theme: theme,
                          colors: colors,
                        ),
                        childCount: _boosts.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Summary header ─────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final List<_BoostRecord> boosts;
  final ColorScheme colors;
  final ThemeData theme;

  const _SummaryHeader({
    required this.boosts,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final totalRoo = boosts.fold(0.0, (s, b) => s + b.amountRoo);
    final totalUsers = boosts.fold(0, (s, b) => s + b.targetUsers);
    final totalBoosts = boosts.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Boost Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatPill(
                label: 'Total Boosts',
                value: '$totalBoosts',
                icon: Icons.rocket_launch,
              ),
              const SizedBox(width: 12),
              _StatPill(
                label: 'Users Reached',
                value: _fmt(totalUsers),
                icon: Icons.people,
              ),
              const SizedBox(width: 12),
              _StatPill(
                label: 'ROO Spent',
                value: totalRoo.toStringAsFixed(0),
                icon: Icons.toll,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Per-boost card ──────────────────────────────────────────────────────────

class _BoostCard extends StatelessWidget {
  final _BoostRecord boost;
  final bool showPostTitle;
  final ThemeData theme;
  final ColorScheme colors;

  const _BoostCard({
    required this.boost,
    required this.showPostTitle,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.rocket_launch,
                  color: Color(0xFFF97316),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPostTitle && boost.postTitle.isNotEmpty)
                      Text(
                        boost.postTitle.length > 50
                            ? '${boost.postTitle.substring(0, 50)}…'
                            : boost.postTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      _formatDate(boost.boostedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Cost badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${boost.amountRoo.toStringAsFixed(0)} ROO',
                  style: const TextStyle(
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Metrics grid ────────────────────────────────
          Row(
            children: [
              _MetricCell(
                icon: Icons.people_outline,
                label: 'Notified',
                value: _fmt(boost.targetUsers),
                colors: colors,
                theme: theme,
              ),
              _MetricCell(
                icon: Icons.visibility_outlined,
                label: 'Views',
                value: _fmt(boost.postViews),
                colors: colors,
                theme: theme,
              ),
              _MetricCell(
                icon: Icons.favorite_border,
                label: 'Likes',
                value: _fmt(boost.postLikes),
                colors: colors,
                theme: theme,
              ),
              _MetricCell(
                icon: Icons.chat_bubble_outline,
                label: 'Comments',
                value: _fmt(boost.postComments),
                colors: colors,
                theme: theme,
              ),
              _MetricCell(
                icon: Icons.repeat,
                label: 'Reposts',
                value: _fmt(boost.postReposts),
                colors: colors,
                theme: theme,
              ),
            ],
          ),

          // ── Engagement rate ─────────────────────────────
          if (boost.targetUsers > 0) ...[
            const SizedBox(height: 14),
            _EngagementBar(boost: boost, colors: colors, theme: theme),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _MetricCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colors;
  final ThemeData theme;

  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementBar extends StatelessWidget {
  final _BoostRecord boost;
  final ColorScheme colors;
  final ThemeData theme;

  const _EngagementBar({
    required this.boost,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final totalEngagements =
        boost.postLikes + boost.postComments + boost.postReposts;
    final rate = boost.targetUsers > 0
        ? (totalEngagements / boost.targetUsers * 100).clamp(0.0, 100.0)
        : 0.0;
    final rateStr = rate.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Engagement Rate',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$rateStr%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: rate >= 5
                    ? Colors.green.shade600
                    : rate >= 2
                    ? Colors.orange.shade600
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            minHeight: 6,
            backgroundColor: colors.outlineVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              rate >= 5
                  ? Colors.green.shade600
                  : rate >= 2
                  ? Colors.orange.shade600
                  : colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty / error states ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSpecificPost;
  const _EmptyState({required this.isSpecificPost});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, size: 56, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              isSpecificPost
                  ? 'This post hasn\'t been boosted yet'
                  : 'You haven\'t boosted any posts yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap ··· on a post you authored and select Boost Post to reach more people.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class _BoostRecord {
  final String txId;
  final String? postId;
  final double amountRoo;
  final int targetUsers;
  final DateTime boostedAt;
  final String postTitle;
  final int postViews;
  final int postLikes;
  final int postComments;
  final int postReposts;

  const _BoostRecord({
    required this.txId,
    required this.postId,
    required this.amountRoo,
    required this.targetUsers,
    required this.boostedAt,
    required this.postTitle,
    required this.postViews,
    required this.postLikes,
    required this.postComments,
    required this.postReposts,
  });
}
