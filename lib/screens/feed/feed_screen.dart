import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rooverse/providers/user_provider.dart';
import 'package:rooverse/screens/create/create_post_screen.dart';
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

import 'package:rooverse/l10n/hardcoded_l10n.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _newPostsTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StoryProvider>().refresh();
    });
    // Periodically check for new content every 60 seconds
    _newPostsTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      context.read<FeedProvider>().checkForNewPosts();
    });
  }

  @override
  void dispose() {
    _newPostsTimer?.cancel();
    _scrollController.removeListener(_onScroll);
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

    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
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
                          child: const StoriesCarousel(),
                        ),
                      ),
                    ),
                  ),

                  /// ───────────────── CREATE POST (WEB STYLE) ─────────────────
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: const CreatePostCard(),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.largePlus.responsive(context),
        vertical: AppSpacing.small.responsive(context),
      ),
      child: Row(
        children: [
          _FilterTab(
            label: 'For You'.tr(context),
            icon: Icons.auto_awesome_outlined,
            isActive: activeFilter == FeedFilter.forYou,
            onTap: () => onFilterChanged(FeedFilter.forYou),
            colors: colors,
          ),
          SizedBox(width: AppSpacing.standard.responsive(context)),
          _FilterTab(
            label: 'Following'.tr(context),
            icon: Icons.people_outline,
            isActive: activeFilter == FeedFilter.following,
            onTap: () => onFilterChanged(FeedFilter.following),
            colors: colors,
          ),
          SizedBox(width: AppSpacing.standard.responsive(context)),
          _FilterTab(
            label: 'Trending'.tr(context),
            icon: Icons.trending_up,
            isActive: activeFilter == FeedFilter.trending,
            onTap: () => onFilterChanged(FeedFilter.trending),
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _FilterTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.largePlus.responsive(context),
          vertical: AppSpacing.mediumSmall.responsive(context),
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppSpacing.responsiveRadius(context, 20),
          border: Border.all(
            color: isActive ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppTypography.responsiveIconSize(context, 16),
              color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            SizedBox(width: AppSpacing.small.responsive(context)),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  AppTypography.small,
                ),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
  const CreatePostCard({super.key});

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreatePostScreen(initialPostType: 'Photo'),
                    ),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.videocam_outlined,
                label: 'Video',
                color: colors.error,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreatePostScreen(initialPostType: 'Video'),
                    ),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.article_outlined,
                label: 'Text',
                color: colors.tertiary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreatePostScreen(initialPostType: 'Text'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
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
