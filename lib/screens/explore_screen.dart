import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/tag_repository.dart';
import '../repositories/mention_repository.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/tip_modal.dart';
import 'package:rooverse/widgets/shimmer_loading.dart';
import 'profile/profile_screen.dart';
import 'hashtag_feed_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();
  String _selectedFilter = 'All';
  List<TrendingTag> _trendingTags = [];
  bool _isLoadingTags = true;
  List<Map<String, dynamic>> _userSearchResults = [];

  @override
  void initState() {
    super.initState();
    _loadTrendingTags();
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
      if (mounted) {
        setState(() => _isLoadingTags = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _userSearchResults = []);
      return;
    }

    setState(() {});

    Set<String> blockedUserIds = {};
    Set<String> blockedByUserIds = {};
    Set<String> mutedUserIds = {};
    try {
      final userProvider = context.read<UserProvider>();
      blockedUserIds = userProvider.blockedUserIds;
      blockedByUserIds = userProvider.blockedByUserIds;
      mutedUserIds = userProvider.mutedUserIds;
    } catch (_) {
      // UserProvider might not be available
    }

    try {
      final results = await _mentionRepository.searchUsers(
        query,
        blockedUserIds: blockedUserIds,
        blockedByUserIds: blockedByUserIds,
        mutedUserIds: mutedUserIds,
      );
      if (mounted) {
        setState(() {
          _userSearchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userSearchResults = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final posts = context.watch<FeedProvider>().posts;
    final filteredPosts = _getFilteredPosts(posts);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ───────── SEARCH
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

            // ───────── USER SEARCH RESULTS
            if (_searchController.text.isNotEmpty &&
                _userSearchResults.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('People'.tr(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final user = _userSearchResults[index];
                  return _UserSearchResult(
                    user: user,
                    onTap: () => _openProfile(context, user['user_id']),
                  );
                }, childCount: _userSearchResults.length),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Divider(color: colors.outline, height: 1),
                ),
              ),
            ],

            // ───────── TRENDING HASHTAGS
            if (_searchController.text.isEmpty) ...[
              SliverToBoxAdapter(child: _buildTrendingSection(colors, theme)),
            ],

            // ───────── FILTERS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0).copyWith(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: _FilterChip(label: 'All', selected: _selectedFilter, onSelect: _select)),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Trending', selected: _selectedFilter, onSelect: _select)),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Latest', selected: _selectedFilter, onSelect: _select)),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Most Liked', selected: _selectedFilter, onSelect: _select)),
                  ],
                ),
              ),
            ),

            // ───────── EMPTY STATE
            if (filteredPosts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'No posts to explore yet.'
                        : 'No results found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            // ───────── FEED
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = filteredPosts[index];
                  return PostCard(
                    post: post,
                    onCommentTap: () => _openComments(context, post),
                    onTipTap: () => _openTip(context, post),
                    onProfileTap: () =>
                        _openProfile(context, post.author.userId ?? ''),
                    onHashtagTap: (tag) => _openHashtagFeed(context, tag),
                  );
                }, childCount: filteredPosts.length),
              ),
            // Added bottom safe padding to ensure last item is fully accessible
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  // ───────────────── TRENDING SECTION

  Widget _buildTrendingSection(ColorScheme colors, ThemeData theme) {
    if (_isLoadingTags) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              5,
              (index) => const Padding(
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

    if (_trendingTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Trending Topics'.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
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
            itemBuilder: (context, index) {
              final tag = _trendingTags[index];
              return _TrendingTagChip(
                tag: tag,
                onTap: () => _openHashtagFeed(context, tag.name),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: colors.outline, height: 1),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ───────────────── HELPERS

  void _select(String value) {
    setState(() => _selectedFilter = value);
  }

  void _searchHashtag(String query) {
    // If search starts with #, navigate to hashtag feed
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

  // ───────────────── FILTER LOGIC

  List<dynamic> _getFilteredPosts(List<dynamic> posts) {
    var filtered = posts;

    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered.where((p) {
        // Search in content
        if (p.content.toLowerCase().contains(q)) return true;
        // Search in author
        if (p.author.username.toLowerCase().contains(q)) return true;
        if (p.author.displayName.toLowerCase().contains(q)) return true;
        // Search in hashtags
        if (p.tags != null) {
          for (final tag in p.tags!) {
            if ('#${tag.name}'.toLowerCase().contains(q) ||
                tag.name.toLowerCase().contains(q)) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }

    switch (_selectedFilter) {
      case 'Trending':
        // Filter out posts with no likes AND no comments - they shouldn't be trending
        filtered = filtered
            .where((p) => p.likes > 0 || p.comments > 0)
            .toList();
        // Sort by highest engagement (likes + comments)
        filtered = [...filtered]
          ..sort(
            (a, b) => (b.likes + b.comments).compareTo(a.likes + a.comments),
          );
        break;
      case 'Latest':
        filtered = [...filtered]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Most Liked':
        // Filter out posts with no likes
        filtered = filtered.where((p) => p.likes > 0).toList();
        filtered = [...filtered]..sort((a, b) => b.likes.compareTo(a.likes));
        break;
    }

    return filtered;
  }
}

/* ───────────────── SEARCH FIELD ───────────────── */

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
        hintText: 'Search posts, users, or #hashtags',
        prefixIcon: Icon(Icons.search, size: 20),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
    );
  }
}

/* ───────────────── FILTER CHIP ───────────────── */

class _FilterChip extends StatelessWidget {
  final String label;
  final String selected;
  final Function(String) onSelect;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isActive = selected == label;

    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── TRENDING TAG CHIP ───────────────── */

class _TrendingTagChip extends StatelessWidget {
  final TrendingTag tag;
  final VoidCallback onTap;

  const _TrendingTagChip({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('#${tag.name}'.tr(context),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (tag.postCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${tag.postCount}'.tr(context),
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
      ),
    );
  }
}

/* ───────────────── USER SEARCH RESULT ───────────────── */

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
                  ? NetworkImage(user['avatar_url'])
                  : null,
              backgroundColor: colors.surfaceVariant,
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
                        user['display_name'] ?? user['username'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      if (user['verified_human'] == 'verified') ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: colors.primary),
                      ],
                    ],
                  ),
                  if (user['display_name'] != null &&
                      user['display_name'] != user['username']) ...[
                    const SizedBox(height: 2),
                    Text('@${user['username']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
