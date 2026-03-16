import 'package:flutter/material.dart';
import 'package:rooverse/providers/user_provider.dart';
import 'package:provider/provider.dart';

import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/feed_provider.dart';
import '../../providers/story_provider.dart';
import '../../utils/responsive_extensions.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/tip_modal.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/stories_carousel.dart';
import '../profile/profile_screen.dart';
import '../../providers/platform_config_provider.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

class FeedScreen extends StatefulWidget {
  /// Increment this notifier's value to trigger a scroll-to-top + refresh
  /// from outside (e.g., when the home tab is re-tapped).
  final ValueNotifier<int>? returnToTopNotifier;

  /// Called when the user taps a create-post entry point in the feed.
  /// [initialPostType] is null for the generic composer, or 'Photo'/'Video'/'Text'.
  final void Function({String? initialPostType})? onNavigateToCreate;

  const FeedScreen({super.key, this.returnToTopNotifier, this.onNavigateToCreate});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.returnToTopNotifier?.addListener(_onReturnToTop);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FeedProvider>().initializeFeed();
      context.read<StoryProvider>().refresh();
    });
  }

  void _onReturnToTop() {
    if (!mounted) return;
    _scrollToTopAndRefresh(context.read<FeedProvider>());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    widget.returnToTopNotifier?.removeListener(_onReturnToTop);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.85) {
      context.read<FeedProvider>().loadMorePosts();
    }
  }

  void _showComments(BuildContext context, post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(post: post),
    );
  }

  void _showTipModal(BuildContext context, post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TipModal(post: post),
    );
  }

  void _scrollToTopAndRefresh(FeedProvider feed) {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    feed.refreshFeed();
    context.read<StoryProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Selector rebuilds only when structural state changes (list length, loading,
    // filter, new-posts banner) — NOT on individual post reaction/bookmark updates.
    return Selector<FeedProvider, _FeedViewState>(
      selector: (_, feed) => _FeedViewState(
        postCount: feed.posts.length,
        isLoading: feed.isLoading,
        newPostsAvailable: feed.newPostsAvailable,
        activeFilter: feed.activeFilter,
        postsIdentity: feed.posts,
      ),
      shouldRebuild: (prev, next) =>
          prev.postCount != next.postCount ||
          prev.isLoading != next.isLoading ||
          prev.newPostsAvailable != next.newPostsAvailable ||
          prev.activeFilter != next.activeFilter ||
          !identical(prev.postsIdentity, next.postsIdentity),
      builder: (context, _, __) {
        final feed = context.read<FeedProvider>();
        return RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: () async {
            await Future.wait([
              feed.refreshFeed(),
              context.read<StoryProvider>().refresh(),
            ]);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              /// Web feed column width
              final maxWidth = constraints.maxWidth > 720
                  ? 720.0
                  : constraints.maxWidth;

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Stories / status row
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: AppSpacing.standard.responsive(context),
                            bottom: 0,
                          ),
                          child: context.watch<PlatformConfigProvider>().config.enableStories
                              ? const StoriesCarousel()
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  /// ───────────────── CREATE POST (WEB STYLE) ─────────────────
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: CreatePostCard(onNavigateToCreate: widget.onNavigateToCreate),
                      ),
                    ),
                  ),

                  /// ───────────────── FILTER TABS ─────────────────
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: _FeedFilterTabs(
                          activeFilter: feed.activeFilter,
                          onFilterChanged: (f) => feed.setFilter(f),
                        ),
                      ),
                    ),
                  ),

                  /// ───────────────── NEW POSTS BANNER ─────────────────
                  if (feed.newPostsAvailable)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: _NewPostsBanner(
                            onTap: () => _scrollToTopAndRefresh(feed),
                          ),
                        ),
                      ),
                    ),

                  /// ───────────────── EMPTY STATE ─────────────────
                  if (feed.posts.isEmpty && !feed.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: AppTypography.responsiveIconSize(
                                context,
                                64,
                              ),
                              color: colors.onSurfaceVariant.withOpacity(0.4),
                            ),
                            SizedBox(
                              height: AppSpacing.largePlus.responsive(context),
                            ),
                            Text(
                              feed.activeFilter == FeedFilter.following
                                  ? 'Follow people to see their posts here'.tr(context)
                                  : 'No posts yet'.tr(context),
                              style: TextStyle(
                                fontSize: AppTypography.responsiveFontSize(
                                  context,
                                  AppTypography.base,
                                ),
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  /// ───────────────── POSTS ─────────────────
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = feed.posts[index];

                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: PostCard(
                              post: post,
                              onCommentTap: () => _showComments(context, post),
                              onTipTap: () => _showTipModal(context, post),
                              onProfileTap: () {
                                disposeFeedVideoCache();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      userId: post.author.userId,
                                      showAppBar: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }, childCount: feed.posts.length),
                    ),

                  /// ───────────────── LOADING ─────────────────
                  if (feed.isLoading && feed.posts.isEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: const ShimmerLoading(
                              isLoading: true,
                              child: PostCardShimmer(),
                            ),
                          ),
                        ),
                        childCount: 4,
                      ),
                    )
                  else if (feed.isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.triple.responsive(context),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  // Added bottom safe padding to ensure last post action buttons are fully accessible
                  SliverPadding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/* ───────────────── FEED FILTER TABS ───────────────── */

class _FeedFilterTabs extends StatelessWidget {
  final FeedFilter activeFilter;
  final ValueChanged<FeedFilter> onFilterChanged;

  const _FeedFilterTabs({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  static const _filters = [FeedFilter.forYou, FeedFilter.following, FeedFilter.trending];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeIndex = _filters.indexOf(activeFilter);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _filters.length; i++)
            Expanded(
              child: _FilterTab(
                label: switch (_filters[i]) {
                  FeedFilter.forYou => 'All'.tr(context),
                  FeedFilter.following => 'Following'.tr(context),
                  FeedFilter.trending => 'Trending'.tr(context),
                },
                isActive: i == activeIndex,
                onTap: () => onFilterChanged(_filters[i]),
                colors: colors,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _FilterTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: AppTypography.small,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? colors.primary : colors.onSurfaceVariant,
              ),
              child: Text(label),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2,
            decoration: BoxDecoration(
              color: isActive ? colors.primary : Colors.transparent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── NEW POSTS BANNER ───────────────── */

class _NewPostsBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _NewPostsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.largePlus.responsive(context),
          vertical: AppSpacing.small.responsive(context),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.largePlus.responsive(context),
          vertical: AppSpacing.mediumSmall.responsive(context),
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: AppSpacing.responsiveRadius(context, 24),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_upward,
              size: AppTypography.responsiveIconSize(context, 16),
              color: colors.onPrimary,
            ),
            SizedBox(width: AppSpacing.small.responsive(context)),
            Text(
              'New posts available'.tr(context),
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  AppTypography.small,
                ),
                fontWeight: FontWeight.w700,
                color: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── CREATE POST CARD ───────────────── */

class CreatePostCard extends StatelessWidget {
  final void Function({String? initialPostType})? onNavigateToCreate;

  const CreatePostCard({super.key, this.onNavigateToCreate});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().currentUser;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.largePlus.responsive(context),
        vertical: AppSpacing.standard.responsive(context),
      ),
      padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusExtraLarge,
        ),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 8.responsive(context),
            offset: Offset(0, 2.responsive(context)),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              onNavigateToCreate?.call();
            },
            child: Row(
              children: [
                /// Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20.responsive(context, min: 17, max: 23),
                    backgroundColor: colors.surfaceContainerHighest,
                    backgroundImage:
                        user != null && user.avatar?.isNotEmpty == true
                        ? NetworkImage(user.avatar!)
                        : null,
                    child: user == null || (user.avatar?.isEmpty ?? true)
                        ? Icon(
                            Icons.person,
                            color: colors.onSurfaceVariant,
                            size: AppTypography.responsiveIconSize(context, 20),
                          )
                        : null,
                  ),
                ),

                SizedBox(width: AppSpacing.standard.responsive(context)),

                /// Input placeholder
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.largePlus.responsive(context),
                      vertical: AppSpacing.standard.responsive(context),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: AppSpacing.responsiveRadius(context, 24),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Text('Share your verified insights...'.tr(context),
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.mediumText,
                        ),
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.standard.responsive(context)),

          /// Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.image_outlined,
                label: 'Photo',
                color: colors.primary,
                onTap: () => onNavigateToCreate?.call(initialPostType: 'Photo'),
              ),
              _ActionButton(
                icon: Icons.videocam_outlined,
                label: 'Video',
                color: colors.primary,
                onTap: () => onNavigateToCreate?.call(initialPostType: 'Video'),
              ),
              _ActionButton(
                icon: Icons.article_outlined,
                label: 'Text',
                color: colors.primary,
                onTap: () => onNavigateToCreate?.call(initialPostType: 'Text'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Holds only the structural feed state needed to decide when to rebuild the
/// feed UI. Individual post mutations (likes, bookmarks) do NOT change this.
class _FeedViewState {
  final int postCount;
  final bool isLoading;
  final bool newPostsAvailable;
  final FeedFilter activeFilter;
  final List<dynamic> postsIdentity;

  const _FeedViewState({
    required this.postCount,
    required this.isLoading,
    required this.newPostsAvailable,
    required this.activeFilter,
    required this.postsIdentity,
  });
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.responsiveRadius(
            context,
            AppSpacing.radiusSmall,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.mediumSmall.responsive(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: AppTypography.responsiveIconSize(context, 20),
                ),
                SizedBox(width: AppSpacing.small.responsive(context)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.small,
                    ),
                    fontWeight: FontWeight.w600,
                    color: color,
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
