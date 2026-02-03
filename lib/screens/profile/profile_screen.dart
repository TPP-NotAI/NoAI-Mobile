import 'package:flutter/material.dart';
import 'package:noai/models/user.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../widgets/shimmer_loading.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/report_user_dialog.dart';
import '../../widgets/report_confirmation_dialog.dart';
import '../../providers/chat_provider.dart';
import '../chat/conversation_thread_page.dart';
import '../post_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final bool showAppBar;

  const ProfileScreen({super.key, this.userId, this.showAppBar = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tabIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();
      final String? targetId = widget.userId ?? authProvider.currentUser?.id;
      if (targetId != null) {
        userProvider.fetchUser(targetId);
        // Load follow and block status if viewing another user's profile
        if (widget.userId != null &&
            widget.userId != authProvider.currentUser?.id) {
          userProvider.loadFollowStatus(targetId);
          userProvider.loadBlockStatus(targetId);
        } else {
          // Load draft posts for own profile
          context.read<FeedProvider>().loadDraftPosts();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTabs() {
    // Scroll to tabs section when switching tabs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate approximate position of tabs (profile card + metrics)
        final position = 400.0; // Approximate height
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final feedProvider = context.watch<FeedProvider>();

    // Check if viewing own profile - either no userId passed OR userId matches current user
    final currentUserId = authProvider.currentUser?.id;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUserId;
    final user = userProvider.getUser(widget.userId);

    if (user == null) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: widget.showAppBar ? AppBar() : null,
        body: const ShimmerLoading(
          isLoading: true,
          child: SingleChildScrollView(child: ProfileHeaderShimmer()),
        ),
      );
    }

    final isFollowing = !isOwnProfile && userProvider.isFollowing(user.id);
    final isBlocked = !isOwnProfile && userProvider.isBlocked(user.id);
    final isBlockedByUser =
        !isOwnProfile && userProvider.isBlockedByUser(user.id);

    // Show blocked message if this user has blocked the current user
    if (isBlockedByUser) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: widget.showAppBar
            ? AppBar(
                elevation: 0,
                backgroundColor: colors.surface,
                surfaceTintColor: colors.surface,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              )
            : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block, size: 48, color: colors.error),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile Unavailable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You cannot view this profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final posts = feedProvider.allPosts
        .where(
          (p) =>
              p.author.username == user.username ||
              p.reposter?.username == user.username,
        )
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: widget.showAppBar
          ? AppBar(
              elevation: 0,
              backgroundColor: colors.surface,
              surfaceTintColor: colors.surface,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                isOwnProfile ? 'My Profile' : 'Profile Details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ───────── PROFILE CARD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _ProfileHeader(
                          user: user,
                          isOwn: isOwnProfile,
                          isFollowing: isFollowing,
                        ),
                        _RooCoinBalance(user: user, colors: colors),
                        const SizedBox(height: 16),
                        _ActionRow(
                          isOwn: isOwnProfile,
                          isFollowing: isFollowing,
                          isBlocked: isBlocked,
                          user: user,
                          onEdit: () =>
                              _open(context, const EditProfileScreen()),
                          onFollow: () => userProvider.toggleFollow(user.id),
                          onBlock: () => _handleBlock(context, user, isBlocked),
                          onReport: () => _handleReport(context, user),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ───────── HUMANITY METRICS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _HumanityMetricsCompact(user: user, colors: colors),
              ),
            ),

            // ───────── STICKY TABS
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: _TabBar(
                  currentIndex: _tabIndex,
                  onTabChanged: (index) {
                    setState(() => _tabIndex = index);
                    _scrollToTabs();
                  },
                  colors: colors,
                  isOwnProfile: isOwnProfile,
                ),
              ),
            ),

            // ───────── TAB CONTENT
            if (_tabIndex == 0)
              _ActivityLog(posts: posts, colors: colors)
            else if (_tabIndex == 1)
              _Statistics(user: user, colors: colors)
            else if (_tabIndex == 2)
              _PostsGrid(posts: posts, colors: colors)
            else if (_tabIndex == 3 && isOwnProfile)
              _DraftsGrid(
                posts: feedProvider.draftPosts,
                colors: colors,
                onRepublish: (postId) async {
                  final success = await feedProvider.republishPost(postId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Post republished'
                              : 'Failed to republish post',
                        ),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _handleBlock(
    BuildContext context,
    User user,
    bool isBlocked,
  ) async {
    final userProvider = context.read<UserProvider>();

    if (!isBlocked) {
      // Show confirmation dialog before blocking
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Block User'),
          content: Text(
            'Are you sure you want to block @${user.username}? '
            'They won\'t be able to see your posts or contact you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final success = await userProvider.toggleBlock(user.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isBlocked
                      ? 'Unblocked @${user.username}'
                      : 'Blocked @${user.username}')
                : userProvider.error ?? 'Something went wrong',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleReport(BuildContext context, User user) async {
    final userProvider = context.read<UserProvider>();

    final result = await ReportUserDialog.show(
      context,
      username: user.username,
    );

    if (result == null || !context.mounted) return;

    final success = await userProvider.reportUser(
      reportedUserId: user.id,
      reason: result['reason']!,
      details: result['details'],
    );

    if (!context.mounted) return;

    // Show confirmation dialog on success
    if (success) {
      await ReportConfirmationDialog.show(
        context,
        type: 'profile',
        username: user.username,
      );
    } else {
      // Show error snackbar if report failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userProvider.error ?? 'Failed to submit report. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }
}

/* ───────────────── HEADER ───────────────── */

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final bool isOwn;
  final bool isFollowing;

  const _ProfileHeader({
    required this.user,
    required this.isOwn,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: user.avatar != null
                  ? NetworkImage(user.avatar!)
                  : null,
              backgroundColor: colors.surfaceContainerHighest,
              child: user.avatar == null
                  ? Icon(Icons.person, size: 48, color: colors.onSurfaceVariant)
                  : null,
            ),
            if (user.isVerified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 3),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.displayName.isNotEmpty ? user.displayName : user.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 8),
              Icon(Icons.verified, size: 20, color: colors.primary),
            ],
          ],
        ),
        if (user.displayName.isNotEmpty &&
            user.displayName.toLowerCase() != user.username.toLowerCase()) ...[
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          user.createdAt != null
              ? 'Member since ${DateFormat('MMM yyyy').format(user.createdAt!)}'
              : '',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        // Location and website
        if (user.location != null && user.location!.isNotEmpty ||
            user.websiteUrl != null && user.websiteUrl!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (user.location != null && user.location!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (user.websiteUrl != null && user.websiteUrl!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 14, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      user.websiteUrl!.replaceFirst(RegExp(r'^https?://'), ''),
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Badges: verified human status + achievements from DB
        if (user.verifiedHuman == 'verified' || user.achievements.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.verifiedHuman == 'verified')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF052E1C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Verified Human',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final achievement in user.achievements)
                _AchievementBadge(achievement: achievement),
            ],
          ),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            user.bio!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/* ───────────────── ACHIEVEMENT BADGE ───────────────── */

class _AchievementBadge extends StatelessWidget {
  final UserAchievement achievement;

  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final tierColors = _getTierColors(achievement.tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tierColors.$1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColors.$2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIconData(achievement.icon), size: 14, color: tierColors.$2),
          const SizedBox(width: 6),
          Text(
            achievement.name,
            style: TextStyle(
              fontSize: 11,
              color: tierColors.$2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Background and border color per achievement tier.
  (Color, Color) _getTierColors(String tier) {
    switch (tier) {
      case 'gold':
        return (const Color(0xFF451A03), const Color(0xFFF59E0B));
      case 'silver':
        return (const Color(0xFF1E293B), const Color(0xFF94A3B8));
      case 'platinum':
        return (const Color(0xFF1E1B4B), const Color(0xFF8B5CF6));
      case 'bronze':
      default:
        return (const Color(0xFF1C1917), const Color(0xFFCD7F32));
    }
  }

  /// Map icon name string from DB to a Material icon.
  IconData _getIconData(String icon) {
    switch (icon) {
      case 'stars':
        return Icons.stars;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'verified':
        return Icons.verified;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'favorite':
        return Icons.favorite;
      case 'shield':
        return Icons.shield;
      default:
        return Icons.star;
    }
  }
}

/* ───────────────── ROOCOIN BALANCE ───────────────── */

class _RooCoinBalance extends StatelessWidget {
  final dynamic user;
  final ColorScheme colors;

  const _RooCoinBalance({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'RooCoin Balance',
          style: TextStyle(
            fontSize: 13,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                '${user.balance.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'R00',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: user.balance / 15000,
            minHeight: 8,
            backgroundColor: colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ],
    );
  }
}

/* ───────────────── HUMANITY METRICS COMPACT ───────────────── */

class _HumanityMetricsCompact extends StatelessWidget {
  final dynamic user;
  final ColorScheme colors;

  const _HumanityMetricsCompact({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'HUMANITY METRICS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.info_outline,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Trust Score
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trust Score',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${user.trustScore.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 2),
                          child: Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (user.trustScore > 80
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B))
                          .withOpacity(0.15),
                  border: Border.all(
                    color: user.trustScore > 80
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    user.trustScore > 90
                        ? 'A+'
                        : user.trustScore > 80
                        ? 'A'
                        : user.trustScore > 70
                        ? 'B'
                        : 'C',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: user.trustScore > 80
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Human-Verified Posts
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Human-Verified Posts',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${user.humanVerifiedPostsCount}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.content_paste,
                size: 32,
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Reputation Score
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Likelihood Score',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${user.mlScore.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, left: 6),
                          child: Text(
                            'AI Prob.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.workspace_premium,
                size: 32,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────── ACTIONS ───────────────── */

class _ActionRow extends StatelessWidget {
  final bool isOwn;
  final bool isFollowing;
  final bool isBlocked;
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onFollow;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _ActionRow({
    required this.isOwn,
    required this.isFollowing,
    required this.isBlocked,
    required this.user,
    required this.onEdit,
    required this.onFollow,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (isOwn) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: onEdit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: isBlocked ? null : onFollow,
                style: FilledButton.styleFrom(
                  backgroundColor: isBlocked
                      ? colors.surfaceContainerHighest
                      : null,
                ),
                child: Text(
                  isBlocked
                      ? 'Blocked'
                      : (isFollowing ? 'Following' : 'Follow'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: isBlocked
                  ? null
                  : () async {
                      final chatProvider = context.read<ChatProvider>();
                      final conversation = await chatProvider.startConversation(
                        user.id,
                      );
                      if (conversation != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationThreadPage(
                              conversation: conversation,
                            ),
                          ),
                        );
                      }
                    },
              child: const Icon(Icons.mail_outline),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'block') {
                  onBlock();
                } else if (value == 'report') {
                  onReport();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        isBlocked ? Icons.check_circle_outline : Icons.block,
                        size: 20,
                        color: isBlocked ? colors.primary : colors.error,
                      ),
                      const SizedBox(width: 12),
                      Text(isBlocked ? 'Unblock' : 'Block'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 20, color: colors.error),
                      const SizedBox(width: 12),
                      const Text('Report'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (isBlocked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 16, color: colors.error),
                const SizedBox(width: 8),
                Text(
                  'You have blocked this user',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/* ───────────────── ACTIVITY LOG ───────────────── */

class _ActivityLog extends StatelessWidget {
  final List posts;
  final ColorScheme colors;

  const _ActivityLog({required this.posts, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No activity yet')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              _ActivityItem(post: posts[i], colors: colors, postNumber: i + 1),
          childCount: posts.length > 5 ? 5 : posts.length,
        ),
      ),
    );
  }
}

/* ───────────────── ACTIVITY ITEM ───────────────── */

class _ActivityItem extends StatelessWidget {
  final dynamic post;
  final ColorScheme colors;
  final int postNumber;

  const _ActivityItem({
    required this.post,
    required this.colors,
    required this.postNumber,
  });

  @override
  Widget build(BuildContext context) {
    final aiScore = post.aiConfidenceScore;
    final dateStr = post.timestamp != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(post.timestamp))
        : 'Recently';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Post number badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'POST #${post.id.substring(0, 4).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (aiScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: aiScore < 20
                          ? const Color(0xFF052E1C)
                          : aiScore < 60
                          ? const Color(0xFF451A03)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: aiScore < 20
                            ? const Color(0xFF10B981)
                            : aiScore < 60
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${aiScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: aiScore < 20
                            ? const Color(0xFF10B981)
                            : aiScore < 60
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content.length > 60
                  ? '${post.content.substring(0, 60)}...'
                  : post.content,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.smartphone, size: 16, color: colors.primary),
                const SizedBox(width: 4),
                Text(
                  'Device Metadata',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (post.detectionStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: post.detectionStatus == 'pass'
                          ? const Color(0xFF052E1C)
                          : post.detectionStatus == 'review'
                          ? const Color(0xFF451A03)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.detectionStatus!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: post.detectionStatus == 'pass'
                            ? const Color(0xFF10B981)
                            : post.detectionStatus == 'review'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── STATISTICS ───────────────── */

class _Statistics extends StatelessWidget {
  final User user;
  final ColorScheme colors;

  const _Statistics({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _StatItem(
            label: 'Total Posts',
            value: user.postsCount.toString(),
            colors: colors,
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'Total Followers',
            value: user.followersCount.toString(),
            colors: colors,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FollowListScreen(
                    userId: user.id,
                    type: FollowListType.followers,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'Following',
            value: user.followingCount.toString(),
            colors: colors,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FollowListScreen(
                    userId: user.id,
                    type: FollowListType.following,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'Trust Score',
            value: '${user.trustScore.toStringAsFixed(0)}/100',
            colors: colors,
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'AI Likelihood',
            value: '${user.mlScore.toStringAsFixed(2)}%',
            colors: colors,
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'RooCoin Balance',
            value: user.balance.toStringAsFixed(1),
            colors: colors,
          ),
          const SizedBox(height: 12),
          _StatItem(
            label: 'Verification Status',
            value: user.verifiedHuman == 'verified'
                ? 'Verified'
                : user.verifiedHuman == 'pending'
                ? 'Pending'
                : 'Unverified',
            colors: colors,
          ),
          if (user.achievements.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StatItem(
              label: 'Achievements',
              value: user.achievements.length.toString(),
              colors: colors,
            ),
          ],
        ]),
      ),
    );
  }
}

/* ───────────────── STAT ITEM ───────────────── */

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colors;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: container,
      );
    }
    return container;
  }
}

/* ───────────────── POSTS GRID ───────────────── */

/* ───────────────── DRAFTS GRID ───────────────── */

class _DraftsGrid extends StatelessWidget {
  final List posts;
  final ColorScheme colors;
  final Future<void> Function(String postId) onRepublish;

  const _DraftsGrid({
    required this.posts,
    required this.colors,
    required this.onRepublish,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No drafts yet')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _DraftGridItem(
            post: posts[i],
            colors: colors,
            onRepublish: onRepublish,
          ),
          childCount: posts.length,
        ),
      ),
    );
  }
}

/* ───────────────── DRAFT GRID ITEM ───────────────── */

class _DraftGridItem extends StatelessWidget {
  final dynamic post;
  final ColorScheme colors;
  final Future<void> Function(String postId) onRepublish;

  const _DraftGridItem({
    required this.post,
    required this.colors,
    required this.onRepublish,
  });

  bool _isVideo(dynamic post) {
    if (post.mediaList != null && (post.mediaList as List).isNotEmpty) {
      return (post.mediaList as List).first.mediaType == 'video';
    }
    if (post.mediaUrl != null) {
      final url = (post.mediaUrl as String).toLowerCase();
      return url.endsWith('.mp4') ||
          url.endsWith('.mov') ||
          url.endsWith('.avi');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryMediaUrl = post.primaryMediaUrl;
    final hasMedia = primaryMediaUrl != null && primaryMediaUrl.isNotEmpty;
    final isVideo = _isVideo(post);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Republish Post?'),
            content: const Text(
              'This will make the post visible in the public feed again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Republish'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await onRepublish(post.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media image or content preview
              if (hasMedia)
                isVideo
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white.withOpacity(0.8),
                            size: 48,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: primaryMediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ShimmerLoading(
                          isLoading: true,
                          child: ShimmerBox(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          padding: const EdgeInsets.all(8),
                          color: colors.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              size: 24,
                            ),
                          ),
                        ),
                      )
              else
                // Text-only post background
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      post.content.length > 50
                          ? '${post.content.substring(0, 50)}...'
                          : post.content,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // DRAFT badge
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DRAFT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colors.onTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  final List posts;
  final ColorScheme colors;

  const _PostsGrid({required this.posts, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No posts yet')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _PostGridItem(post: posts[i], colors: colors),
          childCount: posts.length,
        ),
      ),
    );
  }
}

/* ───────────────── POST GRID ITEM ───────────────── */

class _PostGridItem extends StatelessWidget {
  final dynamic post;
  final ColorScheme colors;

  const _PostGridItem({required this.post, required this.colors});

  bool _isVideo(dynamic post) {
    if (post.mediaList != null && (post.mediaList as List).isNotEmpty) {
      return (post.mediaList as List).first.mediaType == 'video';
    }
    // Fallback check by extension if legacy
    if (post.mediaUrl != null) {
      final url = (post.mediaUrl as String).toLowerCase();
      return url.endsWith('.mp4') ||
          url.endsWith('.mov') ||
          url.endsWith('.avi');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryMediaUrl = post.primaryMediaUrl;
    final hasMedia = primaryMediaUrl != null && primaryMediaUrl.isNotEmpty;
    final isVideo = _isVideo(post);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media image or content preview
              if (hasMedia)
                isVideo
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white.withOpacity(0.8),
                            size: 48,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: primaryMediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ShimmerLoading(
                          isLoading: true,
                          child: ShimmerBox(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          padding: const EdgeInsets.all(8),
                          color: colors.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              size: 24,
                            ),
                          ),
                        ),
                      )
              else
                // Text-only post background
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      post.content.length > 50
                          ? '${post.content.substring(0, 50)}...'
                          : post.content,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Post stats at bottom
              Positioned(
                bottom: 4,
                left: 6,
                right: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (post.likes > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            post.likes > 999
                                ? '${(post.likes / 1000).toStringAsFixed(1)}k'
                                : post.likes.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    if (post.comments > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            post.comments > 999
                                ? '${(post.comments / 1000).toStringAsFixed(1)}k'
                                : post.comments.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Media type indicator
              if (hasMedia)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      isVideo ? Icons.videocam : Icons.image,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),

              // ML Score badge
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF052E1C),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    post.aiConfidenceScore != null
                        ? '${post.aiConfidenceScore!.toStringAsFixed(1)}%'
                        : '0.05%',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── STICKY TAB BAR ───────────────── */

class _TabBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabChanged;
  final ColorScheme colors;
  final bool isOwnProfile;

  const _TabBar({
    required this.currentIndex,
    required this.onTabChanged,
    required this.colors,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Activity Log',
            index: 0,
            isSelected: currentIndex == 0,
            onTap: () => onTabChanged(0),
            colors: colors,
          ),
          _TabButton(
            label: 'Statistics',
            index: 1,
            isSelected: currentIndex == 1,
            onTap: () => onTabChanged(1),
            colors: colors,
          ),
          _TabButton(
            label: 'Posts',
            index: 2,
            isSelected: currentIndex == 2,
            onTap: () => onTabChanged(2),
            colors: colors,
          ),
          if (isOwnProfile)
            _TabButton(
              label: 'Drafts',
              index: 3,
              isSelected: currentIndex == 3,
              onTap: () => onTabChanged(3),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _TabButton({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? colors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── STICKY TAB BAR DELEGATE ───────────────── */

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
