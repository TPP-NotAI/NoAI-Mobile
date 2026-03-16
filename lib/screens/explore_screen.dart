import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/app_colors.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/tag_repository.dart';
import '../repositories/mention_repository.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/tip_modal.dart';
import 'package:rooverse/widgets/shimmer_loading.dart';
import 'profile/profile_screen.dart';
import 'hashtag_feed_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

enum _ExploreTab { forYou, trending, latest, top }

enum _ContentFilter { all, photos, videos, text }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();

  _ExploreTab _activeTab = _ExploreTab.forYou;
  _ContentFilter _contentFilter = _ContentFilter.all;

  List<TrendingTag> _trendingTags = [];
  bool _isLoadingTags = true;
  List<Map<String, dynamic>> _userSearchResults = [];

  // Who to follow
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isLoadingSuggested = true;

  bool _suggestedUsersLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTrendingTags();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_suggestedUsersLoaded) {
      _suggestedUsersLoaded = true;
      _loadSuggestedUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingTags() async {
    try {
      final tags = await _tagRepository.getTrendingTags(limit: 10);
      if (mounted) {
        setState(() {
          _trendingTags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.currentUser?.id ?? '';
    final currentCountry = userProvider.currentUser?.countryCode ?? '';
    try {
      final excluded = {
        if (currentUserId.isNotEmpty) currentUserId,
        ...userProvider.blockedUserIds,
        ...userProvider.blockedByUserIds,
        ...userProvider.mutedUserIds,
      };

      // Fetch profiles — no filter on user_id if we don't have it yet
      var query = SupabaseService().client
          .from('profiles')
          .select('user_id, username, display_name, avatar_url, verified_human, country_code');

      if (currentUserId.isNotEmpty) {
        query = query.neq('user_id', currentUserId);
      }

      final profilesResponse = await query.limit(50);

      debugPrint('ExploreScreen: profiles fetched = ${(profilesResponse as List).length}');

      final profiles = (profilesResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((u) => !excluded.contains(u['user_id']))
          .toList();

      if (profiles.isEmpty) {
        if (mounted) setState(() => _isLoadingSuggested = false);
        return;
      }

      // Fetch follower counts
      final userIds = profiles.map((u) => u['user_id'] as String).toList();
      final followsResponse = await SupabaseService().client
          .from('follows')
          .select('following_id')
          .inFilter('following_id', userIds);

      final followerCounts = <String, int>{};
      for (final row in (followsResponse as List<dynamic>)) {
        final id = row['following_id'] as String;
        followerCounts[id] = (followerCounts[id] ?? 0) + 1;
      }

      final users = profiles.map((u) {
        final id = u['user_id'] as String;
        return {...u, '_follower_count': followerCounts[id] ?? 0};
      }).toList();

      // Sort: same country first, then by follower count descending
      users.sort((a, b) {
        final aLocal = (a['country_code'] as String? ?? '') == currentCountry ? 1 : 0;
        final bLocal = (b['country_code'] as String? ?? '') == currentCountry ? 1 : 0;
        if (aLocal != bLocal) return bLocal - aLocal;
        return (b['_follower_count'] as int).compareTo(a['_follower_count'] as int);
      });

      if (mounted) {
        setState(() {
          _suggestedUsers = users.take(10).toList();
          _isLoadingSuggested = false;
        });
      }
    } catch (e) {
      debugPrint('ExploreScreen: _loadSuggestedUsers error - $e');
      if (mounted) setState(() => _isLoadingSuggested = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _userSearchResults = []);
      return;
    }
    try {
      final userProvider = context.read<UserProvider>();
      final results = await _mentionRepository.searchUsers(
        query,
        blockedUserIds: userProvider.blockedUserIds,
        blockedByUserIds: userProvider.blockedByUserIds,
        mutedUserIds: userProvider.mutedUserIds,
      );
      if (mounted) setState(() => _userSearchResults = results);
    } catch (_) {
      if (mounted) setState(() => _userSearchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final posts = context.watch<FeedProvider>().posts;
    final filteredPosts = _getFilteredPosts(posts);
    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Explore'.tr(context),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),

            // ── Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: () {
                    setState(() {});
                    _searchUsers(_searchController.text);
                  },
                  onHashtagSearch: _searchHashtag,
                ),
              ),
            ),

            // ── User search results (when searching)
            if (isSearching && _userSearchResults.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'People'.tr(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _UserSearchResult(
                    user: _userSearchResults[i],
                    onTap: () =>
                        _openProfile(context, _userSearchResults[i]['user_id']),
                  ),
                  childCount: _userSearchResults.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Divider(color: colors.outline, height: 1),
                ),
              ),
            ],

            // ── Who to Follow (when not searching)
            if (!isSearching) ...[
              // ── Tab bar (For You / Trending / Latest / Top)
              SliverToBoxAdapter(
                child: _TabBar(
                  active: _activeTab,
                  onSelect: (tab) => setState(() => _activeTab = tab),
                ),
              ),

              // ── Who to Follow
              SliverToBoxAdapter(
                child: _WhoToFollow(
                  users: _suggestedUsers,
                  isLoading: _isLoadingSuggested,
                  onTap: (userId) => _openProfile(context, userId),
                ),
              ),

              // ── Content type filter (All / Photos / Videos / Text)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _ContentFilter.values.map((f) {
                        final labels = {
                          _ContentFilter.all: 'All',
                          _ContentFilter.photos: 'Photos',
                          _ContentFilter.videos: 'Videos',
                          _ContentFilter.text: 'Text',
                        };
                        final icons = {
                          _ContentFilter.all: Icons.grid_view_rounded,
                          _ContentFilter.photos: Icons.image_outlined,
                          _ContentFilter.videos: Icons.videocam_outlined,
                          _ContentFilter.text: Icons.text_fields_rounded,
                        };
                        final isActive = _contentFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _contentFilter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.primary
                                      : colors.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icons[f],
                                    size: 14,
                                    color: isActive
                                        ? AppColors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    labels[f]!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? AppColors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── Spotlight card (top post, only on For You tab)
              if (_activeTab == _ExploreTab.forYou && filteredPosts.isNotEmpty)
                SliverToBoxAdapter(
                  child: _SpotlightCard(
                    post: _getSpotlightPost(filteredPosts),
                    onCommentTap: (p) => _openComments(context, p),
                    onTipTap: (p) => _openTip(context, p),
                    onProfileTap: (uid) => _openProfile(context, uid),
                    onHashtagTap: (tag) => _openHashtagFeed(context, tag),
                  ),
                ),
            ],

            // ── Trending topics strip (when not searching)
            if (!isSearching)
              SliverToBoxAdapter(
                  child: _buildTrendingSection(colors, theme)),

            // ── Feed
            if (filteredPosts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    isSearching
                        ? 'No results found.'
                        : 'No posts to explore yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // On For You tab, spotlight shows post[0], so feed starts at index 1
                    final postIndex = (!isSearching && _activeTab == _ExploreTab.forYou)
                        ? index + 1
                        : index;
                    if (postIndex >= filteredPosts.length) return null;
                    final post = filteredPosts[postIndex];
                    return PostCard(
                      post: post,
                      onCommentTap: () => _openComments(context, post),
                      onTipTap: () => _openTip(context, post),
                      onProfileTap: () =>
                          _openProfile(context, post.author.userId ?? ''),
                      onHashtagTap: (tag) => _openHashtagFeed(context, tag),
                    );
                  },
                  childCount: (!isSearching && _activeTab == _ExploreTab.forYou)
                      ? (filteredPosts.length - 1).clamp(0, filteredPosts.length)
                      : filteredPosts.length,
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  // ── Trending section strip

  Widget _buildTrendingSection(ColorScheme colors, ThemeData theme) {
    if (_isLoadingTags) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 8),
                child: ShimmerLoading(
                  isLoading: true,
                  child: ShimmerBox(width: 80, height: 32, borderRadius: 16),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_trendingTags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Trending Topics'.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _trendingTags.length,
            itemBuilder: (context, i) {
              final tag = _trendingTags[i];
              return _TrendingTagChip(
                tag: tag,
                onTap: () => _openHashtagFeed(context, tag.name),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
              color: Theme.of(context).colorScheme.outline, height: 1),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Helpers

  dynamic _getSpotlightPost(List posts) {
    final sorted = [...posts]
      ..sort((a, b) => (b.likes + b.comments).compareTo(a.likes + a.comments));
    return sorted.first;
  }

  void _searchHashtag(String query) {
    if (query.startsWith('#') && query.length > 1) {
      final hashtag = query.substring(1).trim();
      if (hashtag.isNotEmpty) {
        _openHashtagFeed(context, hashtag);
        _searchController.clear();
        setState(() {});
      }
    }
  }

  void _openHashtagFeed(BuildContext context, String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HashtagFeedScreen(hashtag: hashtag)),
    );
  }

  void _openComments(BuildContext context, post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(post: post),
    );
  }

  void _openTip(BuildContext context, post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TipModal(post: post),
    );
  }

  void _openProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId, showAppBar: true),
      ),
    );
  }

  List<dynamic> _getFilteredPosts(List<dynamic> posts) {
    var filtered = posts;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered.where((p) {
        if (p.content.toLowerCase().contains(q)) return true;
        if (p.author.username.toLowerCase().contains(q)) return true;
        if (p.author.displayName.toLowerCase().contains(q)) return true;
        if (p.tags != null) {
          for (final tag in p.tags!) {
            if (tag.name.toLowerCase().contains(q)) return true;
          }
        }
        return false;
      }).toList();
    }

    // Tab filter
    switch (_activeTab) {
      case _ExploreTab.trending:
        filtered = filtered.where((p) => p.likes > 0 || p.comments > 0).toList();
        filtered = [...filtered]
          ..sort((a, b) =>
              (b.likes + b.comments).compareTo(a.likes + a.comments));
        break;
      case _ExploreTab.latest:
        filtered = [...filtered]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case _ExploreTab.top:
        filtered = filtered.where((p) => p.likes > 0).toList();
        filtered = [...filtered]..sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case _ExploreTab.forYou:
        break;
    }

    // Content type filter
    switch (_contentFilter) {
      case _ContentFilter.photos:
        filtered = filtered.where((p) {
          final hasMedia = p.hasMedia as bool;
          if (!hasMedia) return false;
          final firstType = (p.mediaList as List?)?.isNotEmpty == true
              ? (p.mediaList!.first.mediaType as String)
              : 'image';
          return firstType == 'image';
        }).toList();
        break;
      case _ContentFilter.videos:
        filtered = filtered.where((p) {
          final hasMedia = p.hasMedia as bool;
          if (!hasMedia) return false;
          final firstType = (p.mediaList as List?)?.isNotEmpty == true
              ? (p.mediaList!.first.mediaType as String)
              : 'image';
          return firstType == 'video';
        }).toList();
        break;
      case _ContentFilter.text:
        filtered = filtered.where((p) => !(p.hasMedia as bool)).toList();
        break;
      case _ContentFilter.all:
        break;
    }

    return filtered;
  }
}

/* ─────────────────── TAB BAR ─────────────────── */

class _TabBar extends StatelessWidget {
  final _ExploreTab active;
  final ValueChanged<_ExploreTab> onSelect;

  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tabs = [
      (_ExploreTab.forYou, 'For You'),
      (_ExploreTab.trending, 'Trending'),
      (_ExploreTab.latest, 'Latest'),
      (_ExploreTab.top, 'Top'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final (tab, label) = t;
          final isActive = active == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(tab),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2,
                    color: isActive ? AppColors.primary : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ─────────────────── WHO TO FOLLOW ─────────────────── */

class _WhoToFollow extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isLoading;
  final ValueChanged<String> onTap;

  const _WhoToFollow({
    required this.users,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!isLoading && users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'Who to Follow',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: ShimmerLoading(
                      isLoading: true,
                      child: ShimmerBox(
                          width: 120, height: 160, borderRadius: 12),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: users.length,
                  itemBuilder: (context, i) =>
                      _SuggestedUserCard(user: users[i], onTap: onTap),
                ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: colors.outline, height: 1),
        ),
      ],
    );
  }
}

class _SuggestedUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final ValueChanged<String> onTap;

  const _SuggestedUserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final userProvider = context.watch<UserProvider>();
    final userId = user['user_id'] as String? ?? '';
    final isFollowing = userProvider.isFollowing(userId);

    return GestureDetector(
      onTap: () => onTap(userId),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: user['avatar_url'] != null
                  ? CachedNetworkImageProvider(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Text(
                      ((user['display_name'] as String? ?? '').isNotEmpty
                              ? user['display_name'] as String
                              : (user['username'] as String? ?? '?'))
                          .characters
                          .first,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            // Display name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      user['display_name'] ?? user['username'] ?? '',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (user['verified_human'] == 'verified') ...[
                    const SizedBox(width: 2),
                    Icon(Icons.verified, size: 12, color: AppColors.primary),
                  ],
                ],
              ),
            ),
            // Username
            Text(
              '@${user['username'] ?? ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Follow button
            GestureDetector(
              onTap: () => userProvider.toggleFollow(userId),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.transparent : colors.onSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.onSurface),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isFollowing ? colors.onSurface : colors.surface,
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

/* ─────────────────── SPOTLIGHT CARD ─────────────────── */

class _SpotlightCard extends StatelessWidget {
  final dynamic post;
  final Function(dynamic) onCommentTap;
  final Function(dynamic) onTipTap;
  final Function(String) onProfileTap;
  final Function(String) onHashtagTap;

  const _SpotlightCard({
    required this.post,
    required this.onCommentTap,
    required this.onTipTap,
    required this.onProfileTap,
    required this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gold spotlight header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                'SPOTLIGHT',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                'Top post right now',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        // Post card with rounded bottom corners only
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: PostCard(
                post: post,
                onCommentTap: () => onCommentTap(post),
                onTipTap: () => onTipTap(post),
                onProfileTap: () => onProfileTap(post.author.userId ?? ''),
                onHashtagTap: onHashtagTap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────── SEARCH FIELD ─────────────────── */

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final Function(String) onHashtagSearch;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onHashtagSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: onHashtagSearch,
      decoration: InputDecoration(
        hintText: 'Search posts, people, #hashtags...',
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

/* ─────────────────── TRENDING TAG CHIP ─────────────────── */

class _TrendingTagChip extends StatelessWidget {
  final TrendingTag tag;
  final VoidCallback onTap;

  const _TrendingTagChip({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${tag.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (tag.postCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tag.postCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── USER SEARCH RESULT ─────────────────── */

class _UserSearchResult extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserSearchResult({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user['avatar_url'] != null
                  ? CachedNetworkImageProvider(user['avatar_url'])
                  : null,
              backgroundColor: colors.surfaceContainerHighest,
              child: user['avatar_url'] == null
                  ? Icon(Icons.person, color: colors.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['display_name'] ?? user['username'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      if (user['verified_human'] == 'verified') ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified,
                            size: 16, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if (user['display_name'] != null &&
                      user['display_name'] != user['username'])
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: colors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
