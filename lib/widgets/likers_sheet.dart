import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/reaction_repository.dart';
import '../repositories/follow_repository.dart';
import '../screens/profile/profile_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

void showLikersSheet(BuildContext context, String postId, int likeCount) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LikersSheet(postId: postId, likeCount: likeCount),
  );
}

class LikersSheet extends StatefulWidget {
  final String postId;
  final int likeCount;

  const LikersSheet({super.key, required this.postId, required this.likeCount});

  @override
  State<LikersSheet> createState() => _LikersSheetState();
}

class _LikersSheetState extends State<LikersSheet> {
  final _repo = ReactionRepository();
  late final FollowRepository _followRepo;
  String? _currentUserId;

  List<Map<String, dynamic>> _likers = [];
  // userId -> isFollowing
  final Map<String, bool> _followStates = {};
  final Set<String> _followLoading = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _followRepo = FollowRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await _repo.getPostLikers(
        postId: widget.postId,
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _likers = results;
          _hasMore = results.length == _pageSize;
          _isLoading = false;
        });
        _loadFollowStates(results);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFollowStates(List<Map<String, dynamic>> items) async {
    final me = _currentUserId;
    if (me == null) return;
    for (final item in items) {
      final profile = item['profiles'] as Map<String, dynamic>? ?? {};
      final uid = profile['user_id'] as String? ?? '';
      if (uid.isEmpty || uid == me || _followStates.containsKey(uid)) continue;
      final following = await _followRepo.isFollowing(me, uid);
      if (mounted) setState(() => _followStates[uid] = following);
    }
  }

  Future<void> _toggleFollow(String targetId) async {
    final me = _currentUserId;
    if (me == null || _followLoading.contains(targetId)) return;
    setState(() => _followLoading.add(targetId));
    try {
      final isFollowing = _followStates[targetId] ?? false;
      if (isFollowing) {
        await _followRepo.unfollowUser(me, targetId);
      } else {
        await _followRepo.followUser(me, targetId);
      }
      if (mounted) setState(() => _followStates[targetId] = !isFollowing);
    } finally {
      if (mounted) setState(() => _followLoading.remove(targetId));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final results = await _repo.getPostLikers(
        postId: widget.postId,
        limit: _pageSize,
        offset: _likers.length,
      );
      if (mounted) {
        setState(() {
          _likers.addAll(results);
          _hasMore = results.length == _pageSize;
          _isLoadingMore = false;
        });
        _loadFollowStates(results);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildFollowButton(ColorScheme scheme, String userId) {
    final isFollowing = _followStates[userId] ?? false;
    return GestureDetector(
      onTap: () => _toggleFollow(userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : scheme.primary,
          border: Border.all(
            color: isFollowing
                ? scheme.outline.withValues(alpha: 0.5)
                : scheme.primary,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFollowing ? 'Following'.tr(context) : 'Follow'.tr(context),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFollowing ? scheme.onSurface : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            children: [
              // Handle pill
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title — centered, Instagram style
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Likes'.tr(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ),

              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _likers.isEmpty
                    ? Center(
                        child: Text(
                          'No likes yet'.tr(context),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _likers.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _likers.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final item = _likers[index];
                            final profile = item['profiles'] as Map<String, dynamic>? ?? {};
                            final userId = profile['user_id'] as String? ?? '';
                            final username = profile['username'] as String? ?? '';
                            final displayName = (profile['display_name'] as String?)?.trim();
                            final hasDisplayName = displayName != null && displayName.isNotEmpty;
                            final avatarUrl = profile['avatar_url'] as String?;
                            final isVerified = profile['verified_human'] == 'verified';

                            return InkWell(
                              onTap: userId.isNotEmpty
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(userId: userId, showAppBar: true),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with ring
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.outline.withValues(alpha: 0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: scheme.primaryContainer,
                                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: avatarUrl == null || avatarUrl.isEmpty
                                            ? Text(
                                                username.isNotEmpty
                                                    ? username[0].toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: scheme.onPrimaryContainer,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Username + display name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  username,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: scheme.onSurface,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isVerified) ...[
                                                const SizedBox(width: 3),
                                                Icon(
                                                  Icons.verified_rounded,
                                                  size: 14,
                                                  color: scheme.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (hasDisplayName)
                                            Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: scheme.onSurfaceVariant,
                                                height: 1.3,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Follow button (hidden for own profile)
                                    if (userId.isNotEmpty && userId != _currentUserId)
                                      _followLoading.contains(userId)
                                          ? const SizedBox(
                                              width: 70,
                                              height: 30,
                                              child: Center(
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            )
                                          : _buildFollowButton(scheme, userId),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
