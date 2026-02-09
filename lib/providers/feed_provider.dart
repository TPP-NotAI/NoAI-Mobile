import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../repositories/post_repository.dart';
import '../repositories/comment_repository.dart';
import '../repositories/reaction_repository.dart';
import '../repositories/bookmark_repository.dart';
import '../repositories/repost_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/user_interests_repository.dart';
import '../services/supabase_service.dart';
import '../services/kyc_verification_service.dart';

class FeedProvider with ChangeNotifier {
  final PostRepository _postRepository = PostRepository();
  final CommentRepository _commentRepository = CommentRepository();
  final ReactionRepository _reactionRepository = ReactionRepository();
  final BookmarkRepository _bookmarkRepository = BookmarkRepository();
  final RepostRepository _repostRepository = RepostRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final MediaRepository _mediaRepository = MediaRepository();
  final UserInterestsRepository _interestsRepository =
      UserInterestsRepository();
  final KycVerificationService _kycService = KycVerificationService();

  List<Post> _posts = [];
  List<Post> _draftPosts = [];
  List<String>? _userInterests;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  String? _error;

  // Track bookmarked and reposted posts
  final Set<String> _bookmarkedPostIds = {};
  final Set<String> _repostedPostIds = {};
  final Map<String, int> _repostCounts = {}; // postId -> count

  // Blocked user IDs to filter from feed
  Set<String> _blockedUserIds = {};
  Set<String> _blockedByUserIds = {};
  Set<String> _mutedUserIds = {};

  /// Get posts filtered by blocked users and prioritized by interests.
  /// Hides posts from users you've blocked and users who've blocked you.
  /// Prioritizes posts with tags matching user interests.
  List<Post> get posts {
    // First filter by blocked and muted users
    List<Post> filtered = _posts;
    if (_blockedUserIds.isNotEmpty ||
        _blockedByUserIds.isNotEmpty ||
        _mutedUserIds.isNotEmpty) {
      filtered = _posts.where((post) {
        final authorId = post.author.userId;
        if (authorId == null) return true;
        // Hide posts from users you've blocked, who've blocked you, or you've muted
        return !_blockedUserIds.contains(authorId) &&
            !_blockedByUserIds.contains(authorId) &&
            !_mutedUserIds.contains(authorId);
      }).toList();
    }

    // If no interests, return filtered posts as-is
    if (_userInterests == null || _userInterests!.isEmpty) {
      return filtered;
    }

    // Prioritize posts with matching interests
    final interestSet = _userInterests!.map((i) => i.toLowerCase()).toSet();
    final prioritized = <Post>[];
    final others = <Post>[];

    for (final post in filtered) {
      bool hasMatchingInterest = false;
      if (post.tags != null && post.tags!.isNotEmpty) {
        for (final tag in post.tags!) {
          if (interestSet.contains(tag.name.toLowerCase())) {
            hasMatchingInterest = true;
            break;
          }
        }
      }

      if (hasMatchingInterest) {
        prioritized.add(post);
      } else {
        others.add(post);
      }
    }

    // Return prioritized posts first, then others
    return [...prioritized, ...others];
  }

  /// Get unfiltered posts (for internal use).
  List<Post> get allPosts => _posts;

  /// Get draft (unpublished) posts for the current user.
  List<Post> get draftPosts => _draftPosts;

  /// Update blocked user IDs for filtering.
  void setBlockedUserIds(Set<String> blocked, Set<String> blockedBy) {
    _blockedUserIds = blocked;
    _blockedByUserIds = blockedBy;
    notifyListeners();
  }

  /// Update muted user IDs for filtering.
  void setMutedUserIds(Set<String> muted) {
    debugPrint(
      'FeedProvider: Updating muted user IDs - count: ${muted.length}',
    );
    _mutedUserIds = muted;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;

  String? get _currentUserId => SupabaseService().currentUser?.id;

  FeedProvider() {
    // Load initial feed from Supabase
    _loadInitialFeed();
    // Load user interests
    _loadUserInterests();
  }

  /// Load user interests for feed personalization.
  Future<void> _loadUserInterests() async {
    try {
      _userInterests = await _interestsRepository.getUserInterests();
      notifyListeners();
    } catch (e) {
      debugPrint('FeedProvider: Error loading user interests - $e');
    }
  }

  /// Refresh user interests (call after updating interests).
  Future<void> refreshInterests() async {
    await _loadUserInterests();
  }

  void _deduplicatePosts() {
    final seen = <String>{};
    final unique = <Post>[];
    for (final post in _posts) {
      final key = post.reposter != null
          ? '${post.id}_repost_${post.reposter!.userId}'
          : post.id;
      if (seen.add(key)) {
        unique.add(post);
      }
    }
    _posts = unique;
  }

  Future<void> _loadInitialFeed() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _currentUserId;

      // Load posts, bookmarks, and reposts in parallel
      final results = await Future.wait([
        _postRepository.getFeed(limit: 20, offset: 0, currentUserId: userId),
        if (userId != null)
          _bookmarkRepository.getUserBookmarkIds(userId: userId),
        if (userId != null) _repostRepository.getUserRepostIds(userId: userId),
      ]);

      _posts = results[0] as List<Post>;
      _deduplicatePosts();

      if (userId != null && results.length > 1) {
        _bookmarkedPostIds.clear();
        _bookmarkedPostIds.addAll(results[1] as Set<String>);

        _repostedPostIds.clear();
        _repostedPostIds.addAll(results[2] as Set<String>);

        // Load repost counts for loaded posts
        final postIds = _posts.map((p) => p.id).toList();
        if (postIds.isNotEmpty) {
          final counts = await _repostRepository.getRepostCounts(
            postIds: postIds,
          );
          _repostCounts.clear();
          _repostCounts.addAll(counts);
        }
      }

      _error = null;
      _hasMore = _posts.length >= 20;
    } catch (e) {
      _error = 'Failed to load feed: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Refresh feed (pull-to-refresh)
  Future<void> refreshFeed() async {
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      _posts = await _postRepository.getFeed(
        limit: 20,
        offset: 0,
        currentUserId: _currentUserId,
      );
      _deduplicatePosts();
      _hasMore = _posts.length >= 20;

      // Refresh repost counts
      final postIds = _posts.map((p) => p.id).toList();
      if (postIds.isNotEmpty) {
        final counts = await _repostRepository.getRepostCounts(
          postIds: postIds,
        );
        _repostCounts.clear();
        _repostCounts.addAll(counts);
      }
    } catch (e) {
      _error = 'Failed to refresh feed: $e';
      debugPrint(_error);
    }

    _isRefreshing = false;
    notifyListeners();
  }

  // Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newPosts = await _postRepository.getFeed(
        limit: 20,
        offset: _posts.length,
        currentUserId: _currentUserId,
      );

      if (newPosts.isEmpty) {
        _hasMore = false;
      } else {
        _posts.addAll(newPosts);
        _deduplicatePosts();
        _hasMore = newPosts.length >= 20;

        // Load repost counts for new posts
        final postIds = newPosts.map((p) => p.id).toList();
        final counts = await _repostRepository.getRepostCounts(
          postIds: postIds,
        );
        _repostCounts.addAll(counts);
      }
    } catch (e) {
      _error = 'Failed to load more posts: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update all instances of a post in the feed (original + reposts share the same post ID).
  /// Returns the list of original posts at those indices for rollback, or empty if not found.
  List<MapEntry<int, Post>> _updateAllInstances(
    String postId,
    Post Function(Post post) updater,
  ) {
    final originals = <MapEntry<int, Post>>[];
    for (var i = 0; i < _posts.length; i++) {
      if (_posts[i].id == postId) {
        originals.add(MapEntry(i, _posts[i]));
        _posts[i] = updater(_posts[i]);
      }
    }
    return originals;
  }

  /// Revert optimistic updates using saved originals.
  void _revertInstances(List<MapEntry<int, Post>> originals) {
    for (final entry in originals) {
      if (entry.key < _posts.length) {
        _posts[entry.key] = entry.value;
      }
    }
  }

  // Toggle like on a post
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Require KYC verification before liking
    await _kycService.requireVerification();

    final first = _posts.indexWhere((p) => p.id == postId);
    if (first == -1) return;

    final wasLiked = _posts[first].isLiked;
    final newLikes = wasLiked
        ? _posts[first].likes - 1
        : _posts[first].likes + 1;

    // Optimistic update — apply to ALL instances
    final originals = _updateAllInstances(
      postId,
      (p) => p.copyWith(likes: newLikes, isLiked: !wasLiked),
    );
    notifyListeners();

    try {
      await _reactionRepository.togglePostLike(postId: postId, userId: userId);
    } catch (e) {
      // Revert on failure
      _revertInstances(originals);
      notifyListeners();
      debugPrint('Failed to toggle like: $e');
    }
  }

  // Toggle follow for a user
  void toggleFollow(String username) {
    for (var i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      if (post.author.username == username) {
        _posts[i] = post.copyWith(
          author: post.author.copyWith(isFollowing: !post.author.isFollowing),
        );
      }
    }
    notifyListeners();
  }

  // Add tip to a post
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> tipPost(String postId, double amount) async {
    // Require KYC verification before tipping
    await _kycService.requireVerification();

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final newTotal = post.tips + amount;

    // Optimistic update
    _posts[index] = post.copyWith(tips: newTotal);
    notifyListeners();

    try {
      final success = await _postRepository.tipPost(postId, newTotal);
      if (!success) {
        // Revert on failure
        _posts[index] = post;
        notifyListeners();
      }
    } catch (e) {
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
      debugPrint('Failed to tip post: $e');
    }
  }

  // Add comment to a post (saves to Supabase and updates local comment with real ID)
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<Comment?> addComment(
    String postId,
    String body, {
    String? tempId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    // Require KYC verification before commenting
    await _kycService.requireVerification();

    try {
      final savedComment = await _commentRepository.addComment(
        postId: postId,
        authorId: userId,
        body: body,
      );

      // Optimistically update post comment count locally if needed
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        _posts[index] = post.copyWith(comments: post.comments + 1);
        notifyListeners(); // Update count immediately

        // Update the local comment with the real ID from Supabase if tempId was used
        if (savedComment != null &&
            tempId != null &&
            post.commentList != null) {
          final updatedComments = post.commentList!.map((c) {
            if (c.id == tempId) {
              return savedComment;
            }
            return c;
          }).toList();
          _posts[index] = post.copyWith(commentList: updatedComments);
          notifyListeners();
        }
      }

      // Fire-and-forget: run AI detection on the comment
      if (savedComment != null && body.trim().isNotEmpty) {
        _commentRepository
            .runAiDetection(
              commentId: savedComment.id,
              authorId: userId,
              body: body,
            )
            .then((aiScore) {
              if (aiScore != null) {
                final idx = _posts.indexWhere((p) => p.id == postId);
                if (idx != -1) {
                  final post = _posts[idx];
                  if (post.commentList != null) {
                    if (aiScore >= 95) {
                      // Remove auto-blocked comment from local view (95%+ AI)
                      final updatedComments = _removeCommentRecursive(
                        post.commentList!,
                        savedComment.id,
                      );
                      _posts[idx] = post.copyWith(
                        commentList: updatedComments,
                        comments: (post.comments - 1).clamp(0, 999999),
                      );
                    } else {
                      final updatedComments = _updateCommentAiScoreRecursive(
                        post.commentList!,
                        savedComment.id,
                        aiScore,
                        status: 'published',
                      );
                      _posts[idx] = post.copyWith(commentList: updatedComments);
                    }
                    notifyListeners();
                  }
                }
              }
            });
      }

      return savedComment;
    } catch (e) {
      debugPrint('Failed to add comment: $e');
      return null;
    }
  }

  // Add comment locally (for optimistic updates from UI)
  void addCommentLocally(String postId, Comment newComment) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final updatedComments = [newComment, ...?post.commentList];

    _posts[index] = post.copyWith(
      comments: post.comments + 1,
      commentList: updatedComments,
    );

    notifyListeners();
  }

  // Add comment with media to a post (saves to Supabase)
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<Comment?> addCommentWithMedia(
    String postId,
    String body, {
    String? tempId,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    // Require KYC verification before commenting
    await _kycService.requireVerification();

    try {
      final savedComment = await _commentRepository.addComment(
        postId: postId,
        authorId: userId,
        body: body,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      // Update post comment count locally
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        _posts[index] = post.copyWith(comments: post.comments + 1);
        notifyListeners();

        // Update the local comment with the real ID from Supabase if tempId was used
        if (savedComment != null &&
            tempId != null &&
            post.commentList != null) {
          final updatedComments = post.commentList!.map((c) {
            if (c.id == tempId) {
              return savedComment;
            }
            return c;
          }).toList();
          _posts[index] = post.copyWith(commentList: updatedComments);
          notifyListeners();
        }
      }

      // Fire-and-forget: run AI detection on the comment
      if (savedComment != null && body.trim().isNotEmpty) {
        _commentRepository
            .runAiDetection(
              commentId: savedComment.id,
              authorId: userId,
              body: body,
            )
            .then((aiScore) {
              if (aiScore != null) {
                final idx = _posts.indexWhere((p) => p.id == postId);
                if (idx != -1) {
                  final post = _posts[idx];
                  if (post.commentList != null) {
                    if (aiScore >= 95) {
                      // Remove auto-blocked comment from local view (95%+ AI)
                      final updatedComments = _removeCommentRecursive(
                        post.commentList!,
                        savedComment.id,
                      );
                      _posts[idx] = post.copyWith(
                        commentList: updatedComments,
                        comments: (post.comments - 1).clamp(0, 999999),
                      );
                    } else {
                      final updatedComments = _updateCommentAiScoreRecursive(
                        post.commentList!,
                        savedComment.id,
                        aiScore,
                        status: 'published',
                      );
                      _posts[idx] = post.copyWith(
                        commentList: updatedComments,
                      );
                    }
                    notifyListeners();
                  }
                }
              }
            });
      }

      return savedComment;
    } catch (e) {
      debugPrint('Failed to add comment with media: $e');
      return null;
    }
  }

  // Toggle like on a comment
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> toggleCommentLike(String postId, String commentId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Require KYC verification before liking
    await _kycService.requireVerification();

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    if (post.commentList == null) return;

    // Optimistic update
    final updatedComments = _toggleCommentLikeRecursive(
      post.commentList!,
      commentId,
    );

    _posts[postIndex] = post.copyWith(commentList: updatedComments);
    notifyListeners();

    try {
      await _reactionRepository.toggleCommentLike(
        commentId: commentId,
        userId: userId,
      );
    } catch (e) {
      // Revert on failure
      _posts[postIndex] = post;
      notifyListeners();
      debugPrint('Failed to toggle comment like: $e');
    }
  }

  // Helper method to recursively toggle comment likes (for nested replies)
  List<Comment> _toggleCommentLikeRecursive(
    List<Comment> comments,
    String commentId,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        final newLikes = comment.isLiked
            ? comment.likes - 1
            : comment.likes + 1;
        return comment.copyWith(likes: newLikes, isLiked: !comment.isLiked);
      } else if (comment.replies != null && comment.replies!.isNotEmpty) {
        return comment.copyWith(
          replies: _toggleCommentLikeRecursive(comment.replies!, commentId),
        );
      }
      return comment;
    }).toList();
  }

  // Add reply to a comment (saves to Supabase and updates local reply with real ID)
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> addReply(
    String postId,
    String commentId,
    String body,
    String tempId,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Require KYC verification before replying
    await _kycService.requireVerification();

    try {
      final savedReply = await _commentRepository.addComment(
        postId: postId,
        authorId: userId,
        body: body,
        parentCommentId: commentId,
      );

      // Update the local reply with the real ID from Supabase
      if (savedReply != null) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          final post = _posts[index];
          if (post.commentList != null) {
            final updatedComments = _updateReplyIdRecursive(
              post.commentList!,
              tempId,
              savedReply,
            );
            _posts[index] = post.copyWith(commentList: updatedComments);
            notifyListeners();
          }
        }

        // Fire-and-forget: run AI detection on the reply
        if (body.trim().isNotEmpty) {
          _commentRepository
              .runAiDetection(
                commentId: savedReply.id,
                authorId: userId,
                body: body,
              )
              .then((aiScore) {
                if (aiScore != null) {
                  final idx = _posts.indexWhere((p) => p.id == postId);
                  if (idx != -1) {
                    final post = _posts[idx];
                    if (post.commentList != null) {
                      if (aiScore >= 95) {
                        // Remove auto-blocked reply from local view (95%+ AI)
                        final updatedComments = _removeCommentRecursive(
                          post.commentList!,
                          savedReply.id,
                        );
                        _posts[idx] = post.copyWith(
                          commentList: updatedComments,
                          comments: (post.comments - 1).clamp(0, 999999),
                        );
                      } else {
                        final updatedComments = _updateCommentAiScoreRecursive(
                          post.commentList!,
                          savedReply.id,
                          aiScore,
                          status: 'published',
                        );
                        _posts[idx] =
                            post.copyWith(commentList: updatedComments);
                      }
                      notifyListeners();
                    }
                  }
                }
              });
        }
      }
    } catch (e) {
      debugPrint('Failed to add reply: $e');
    }
  }

  // Helper to update a reply's ID recursively in nested comments
  List<Comment> _updateReplyIdRecursive(
    List<Comment> comments,
    String tempId,
    Comment savedReply,
  ) {
    return comments.map((comment) {
      if (comment.replies != null && comment.replies!.isNotEmpty) {
        final updatedReplies = comment.replies!.map((reply) {
          if (reply.id == tempId) {
            return savedReply;
          }
          return reply;
        }).toList();
        return comment.copyWith(
          replies: _updateReplyIdRecursive(updatedReplies, tempId, savedReply),
        );
      }
      return comment;
    }).toList();
  }

  // Add reply locally (for optimistic updates from UI)
  void addReplyLocally(String postId, String commentId, Comment reply) {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    if (post.commentList == null) return;

    final updatedComments = _addReplyRecursive(
      post.commentList!,
      commentId,
      reply,
    );

    _posts[postIndex] = post.copyWith(
      comments: post.comments + 1,
      commentList: updatedComments,
    );

    notifyListeners();
  }

  // Add reply with media to a comment (saves to Supabase)
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> addReplyWithMedia(
    String postId,
    String commentId,
    String body,
    String tempId, {
    String? mediaUrl,
    String? mediaType,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Require KYC verification before replying
    await _kycService.requireVerification();

    try {
      final savedReply = await _commentRepository.addComment(
        postId: postId,
        authorId: userId,
        body: body,
        parentCommentId: commentId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      // Update the local reply with the real ID from Supabase
      if (savedReply != null) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          final post = _posts[index];
          if (post.commentList != null) {
            final updatedComments = _updateReplyIdRecursive(
              post.commentList!,
              tempId,
              savedReply,
            );
            _posts[index] = post.copyWith(commentList: updatedComments);
            notifyListeners();
          }
        }

        // Fire-and-forget: run AI detection on the reply
        if (body.trim().isNotEmpty) {
          _commentRepository
              .runAiDetection(
                commentId: savedReply.id,
                authorId: userId,
                body: body,
              )
              .then((aiScore) {
                if (aiScore != null) {
                  final idx = _posts.indexWhere((p) => p.id == postId);
                  if (idx != -1) {
                    final post = _posts[idx];
                    if (post.commentList != null) {
                      if (aiScore >= 95) {
                        // Remove auto-blocked reply from local view (95%+ AI)
                        final updatedComments = _removeCommentRecursive(
                          post.commentList!,
                          savedReply.id,
                        );
                        _posts[idx] = post.copyWith(
                          commentList: updatedComments,
                          comments: (post.comments - 1).clamp(0, 999999),
                        );
                      } else {
                        final updatedComments = _updateCommentAiScoreRecursive(
                          post.commentList!,
                          savedReply.id,
                          aiScore,
                          status: 'published',
                        );
                        _posts[idx] =
                            post.copyWith(commentList: updatedComments);
                      }
                      notifyListeners();
                    }
                  }
                }
              });
        }
      }
    } catch (e) {
      debugPrint('Failed to add reply with media: $e');
    }
  }

  // Helper method to recursively add replies to nested comments
  List<Comment> _addReplyRecursive(
    List<Comment> comments,
    String commentId,
    Comment reply,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return comment.copyWith(replies: [reply, ...?comment.replies]);
      } else if (comment.replies != null && comment.replies!.isNotEmpty) {
        return comment.copyWith(
          replies: _addReplyRecursive(comment.replies!, commentId, reply),
        );
      }
      return comment;
    }).toList();
  }

  // Delete a comment (with ownership validation)
  Future<bool> deleteComment(String postId, String commentId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return false;

    final post = _posts[postIndex];
    if (post.commentList == null) return false;

    // Optimistic: remove the comment locally
    final originalComments = post.commentList!;
    final updatedComments = _removeCommentRecursive(
      originalComments,
      commentId,
    );
    final removedCount =
        _countComments(originalComments) - _countComments(updatedComments);
    _posts[postIndex] = post.copyWith(
      commentList: updatedComments,
      comments: post.comments - removedCount,
    );
    notifyListeners();

    try {
      final success = await _commentRepository.deleteComment(
        commentId,
        currentUserId: userId,
      );
      if (!success) {
        // Revert on failure
        _posts[postIndex] = post;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Revert on error
      _posts[postIndex] = post;
      notifyListeners();
      debugPrint('Failed to delete comment: $e');
      return false;
    }
  }

  // Update a comment's text (with ownership validation)
  Future<bool> updateComment(
    String postId,
    String commentId,
    String newText,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return false;

    final post = _posts[postIndex];
    if (post.commentList == null) return false;

    // Optimistic: update the comment text locally
    final originalComments = post.commentList!;
    final updatedComments = _updateCommentTextRecursive(
      originalComments,
      commentId,
      newText,
    );
    _posts[postIndex] = post.copyWith(commentList: updatedComments);
    notifyListeners();

    try {
      final result = await _commentRepository.updateComment(
        commentId: commentId,
        currentUserId: userId,
        newBody: newText,
      );
      if (result == null) {
        // Revert on failure
        _posts[postIndex] = post.copyWith(commentList: originalComments);
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Revert on error
      _posts[postIndex] = post.copyWith(commentList: originalComments);
      notifyListeners();
      debugPrint('Failed to update comment: $e');
      return false;
    }
  }

  // Helper: remove a comment recursively from nested comment list
  List<Comment> _removeCommentRecursive(
    List<Comment> comments,
    String commentId,
  ) {
    return comments.where((c) => c.id != commentId).map((c) {
      if (c.replies != null && c.replies!.isNotEmpty) {
        return c.copyWith(
          replies: _removeCommentRecursive(c.replies!, commentId),
        );
      }
      return c;
    }).toList();
  }

  // Helper: update a comment's text recursively
  List<Comment> _updateCommentTextRecursive(
    List<Comment> comments,
    String commentId,
    String newText,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return comment.copyWith(text: newText);
      } else if (comment.replies != null && comment.replies!.isNotEmpty) {
        return comment.copyWith(
          replies: _updateCommentTextRecursive(
            comment.replies!,
            commentId,
            newText,
          ),
        );
      }
      return comment;
    }).toList();
  }

  // Helper: update a comment's AI score recursively
  List<Comment> _updateCommentAiScoreRecursive(
    List<Comment> comments,
    String commentId,
    double aiScore, {
    String? status,
  }) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return comment.copyWith(
          aiScore: aiScore,
          status: status ?? comment.status,
        );
      } else if (comment.replies != null && comment.replies!.isNotEmpty) {
        return comment.copyWith(
          replies: _updateCommentAiScoreRecursive(
            comment.replies!,
            commentId,
            aiScore,
            status: status,
          ),
        );
      }
      return comment;
    }).toList();
  }

  // Helper: count total comments including replies
  int _countComments(List<Comment> comments) {
    int count = 0;
    for (final c in comments) {
      count++;
      if (c.replies != null) {
        count += _countComments(c.replies!);
      }
    }
    return count;
  }

  // Bookmark functionality
  bool isBookmarked(String postId) {
    return _bookmarkedPostIds.contains(postId);
  }

  Future<void> toggleBookmark(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final wasBookmarked = _bookmarkedPostIds.contains(postId);

    // Optimistic update
    if (wasBookmarked) {
      _bookmarkedPostIds.remove(postId);
    } else {
      _bookmarkedPostIds.add(postId);
    }
    notifyListeners();

    try {
      await _bookmarkRepository.toggleBookmark(postId: postId, userId: userId);
    } catch (e) {
      // Revert on failure
      if (wasBookmarked) {
        _bookmarkedPostIds.add(postId);
      } else {
        _bookmarkedPostIds.remove(postId);
      }
      notifyListeners();
      debugPrint('Failed to toggle bookmark: $e');
    }
  }

  List<Post> get bookmarkedPosts {
    return _posts
        .where((post) => _bookmarkedPostIds.contains(post.id))
        .toList();
  }

  // Repost functionality
  bool isReposted(String postId) {
    return _repostedPostIds.contains(postId);
  }

  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<void> toggleRepost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Require KYC verification before reposting
    await _kycService.requireVerification();

    final wasReposted = _repostedPostIds.contains(postId);
    final oldCount = _repostCounts[postId] ?? 0;

    // Optimistic update
    if (wasReposted) {
      _repostedPostIds.remove(postId);
      _repostCounts[postId] = oldCount - 1;
      if (_repostCounts[postId]! <= 0) {
        _repostCounts.remove(postId);
      }
    } else {
      _repostedPostIds.add(postId);
      _repostCounts[postId] = oldCount + 1;
    }
    notifyListeners();

    try {
      await _repostRepository.toggleRepost(postId: postId, userId: userId);
    } catch (e) {
      // Revert on failure
      if (wasReposted) {
        _repostedPostIds.add(postId);
        _repostCounts[postId] = oldCount;
      } else {
        _repostedPostIds.remove(postId);
        if (oldCount > 0) {
          _repostCounts[postId] = oldCount;
        } else {
          _repostCounts.remove(postId);
        }
      }
      notifyListeners();
      debugPrint('Failed to toggle repost: $e');
    }
  }

  int getRepostCount(String postId) {
    return _repostCounts[postId] ?? 0;
  }

  List<Post> get repostedPosts {
    return _posts.where((post) => _repostedPostIds.contains(post.id)).toList();
  }

  // Report a post
  Future<bool> reportPost({
    required String postId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      return await _reportRepository.reportPost(
        reporterId: userId,
        postId: postId,
        reportedUserId: reportedUserId,
        reason: reason,
        details: details,
      );
    } catch (e) {
      debugPrint('Failed to report post: $e');
      return false;
    }
  }

  // Create a new post with optional media, tags, location, and mentions
  /// Throws [KycNotVerifiedException] if user has not completed KYC verification.
  Future<Post?> createPost(
    String body, {
    String? title,
    List<File>? mediaFiles,
    List<String>? mediaTypes,
    List<String>? tags,
    String? location,
    List<String>? mentionedUserIds,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    // Require KYC verification before posting
    await _kycService.requireVerification();

    try {
      final newPost = await _postRepository.createPost(
        authorId: userId,
        body: body,
        title: title,
        mediaFiles: mediaFiles,
        mediaTypes: mediaTypes,
        tags: tags,
        location: location,
        mentionedUserIds: mentionedUserIds,
      );

      if (newPost != null) {
        // Add to the beginning of the feed
        _posts.insert(0, newPost);
        notifyListeners();

        // Fire-and-forget: run AI detection in the background.
        // The post is visible immediately with a PENDING badge.
        // Once detection completes, update the local post so the
        // badge switches to PASS/FAIL without needing a feed refresh.
        _postRepository
            .runAiDetection(
              postId: newPost.id,
              authorId: userId,
              body: body,
              mediaFiles: mediaFiles,
            )
            .then((confidence) {
              if (confidence != null) {
                // Check if AI score is 95%+ (auto-block threshold)
                // Remove immediately from UI without waiting for backend
                if (confidence >= 95) {
                  final idx = _posts.indexWhere((p) => p.id == newPost.id);
                  if (idx != -1) {
                    _posts.removeAt(idx);
                    notifyListeners();
                  }
                  return;
                }

                // Fetch updated post to get the AI score and status
                _postRepository.getPost(newPost.id, currentUserId: userId).then(
                  (updatedPost) {
                    if (updatedPost != null) {
                      final idx = _posts.indexWhere((p) => p.id == newPost.id);
                      if (idx != -1) {
                        if (updatedPost.status == 'under_review' ||
                            updatedPost.status == 'deleted' ||
                            updatedPost.status == 'hidden') {
                          // Post was flagged or auto-blocked — remove from feed
                          _posts.removeAt(idx);
                        } else {
                          _posts[idx] = updatedPost;
                        }
                        notifyListeners();
                      }
                    }
                  },
                );
              }
            });
      }

      return newPost;
    } catch (e) {
      debugPrint('Failed to create post: $e');
      return null;
    }
  }

  // Load comments for a post (filters out blocked users)
  Future<void> loadCommentsForPost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    try {
      final comments = await _commentRepository.getCommentsForPost(
        postId,
        currentUserId: _currentUserId,
        blockedUserIds: _blockedUserIds,
        blockedByUserIds: _blockedByUserIds,
        mutedUserIds: _mutedUserIds,
      );

      // Count total visible comments including replies
      int visibleCount = 0;
      for (final comment in comments) {
        visibleCount++; // Count the comment itself
        visibleCount += comment.replies?.length ?? 0; // Count replies
      }

      // Update both commentList and the visible comment count
      _posts[index] = _posts[index].copyWith(
        commentList: comments,
        comments: visibleCount,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load comments: $e');
    }
  }

  Future<bool> deletePost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final success = await _postRepository.deletePost(
      postId,
      currentUserId: userId,
    );
    if (success) {
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return success;
  }

  Future<bool> unpublishPost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final success = await _postRepository.unpublishPost(
      postId,
      currentUserId: userId,
    );
    if (success) {
      final post = _posts.firstWhere(
        (p) => p.id == postId,
        orElse: () => _posts.first,
      );
      if (post.id == postId) {
        _draftPosts.insert(0, post);
      }
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return success;
  }

  /// Load draft posts for the current user.
  Future<void> loadDraftPosts() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      _draftPosts = await _postRepository.getDraftsByUser(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('FeedProvider: Error loading draft posts - $e');
    }
  }

  /// Republish a draft post (set status back to 'published').
  Future<bool> republishPost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final success = await _postRepository.republishPost(
      postId,
      currentUserId: userId,
    );
    if (success) {
      final post = _draftPosts.firstWhere(
        (p) => p.id == postId,
        orElse: () => _draftPosts.first,
      );
      if (post.id == postId) {
        _posts.insert(0, post);
      }
      _draftPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return success;
  }

  Future<bool> updatePost(
    String postId, {
    String? body,
    String? title,
    String? location,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final success = await _postRepository.updatePost(
      postId: postId,
      currentUserId: userId,
      body: body,
      title: title,
      location: location,
    );
    if (success) {
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          content: body,
          location: location,
        );
        notifyListeners();
      }
    }
    return success;
  }

  Future<List<Comment>> fetchCommentsForPost(String postId) async {
    try {
      return await _commentRepository.getCommentsForPost(
        postId,
        currentUserId: _currentUserId,
        blockedUserIds: _blockedUserIds,
        blockedByUserIds: _blockedByUserIds,
      );
    } catch (e) {
      debugPrint('FeedProvider: Error fetching comments - $e');
      return [];
    }
  }

  Future<bool> updatePostWithMedia({
    required String postId,
    required String body,
    String? location,
    String? title,
    required List<String> deletedMediaIds,
    required List<File> newMediaFiles,
    required List<String> newMediaTypes,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      // 1. Update basic post details
      final updateSuccess = await _postRepository.updatePost(
        postId: postId,
        currentUserId: userId,
        body: body,
        title: title,
        location: location,
      );

      if (!updateSuccess) return false;

      // 2. Delete removed media
      for (final mediaId in deletedMediaIds) {
        await _mediaRepository.deleteMedia(mediaId);
      }

      // 3. Add new media
      for (var i = 0; i < newMediaFiles.length; i++) {
        final storagePath = await _mediaRepository.uploadMedia(
          file: newMediaFiles[i],
          userId: userId,
          postId: postId,
          mediaType: newMediaTypes[i],
          index: i,
        );

        if (storagePath != null) {
          await _mediaRepository.createPostMedia(
            postId: postId,
            mediaType: newMediaTypes[i],
            storagePath: storagePath,
            mimeType: _mediaRepository.getMimeType(
              newMediaFiles[i].path.split('.').last,
              newMediaTypes[i],
            ),
          );
        }
      }

      // 4. Reload the post to get fresh state
      final updatedPost = await _postRepository.getPost(
        postId,
        currentUserId: userId,
      );

      if (updatedPost != null) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _posts[index] = updatedPost;
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      debugPrint('FeedProvider: Error updating post with media - $e');
      return false;
    }
  }

  Future<Post?> getPostById(String postId) async {
    // Check local cache first
    try {
      return _posts.firstWhere((p) => p.id == postId);
    } catch (_) {
      // Fetch from repository if not in local cache
      return await _postRepository.getPost(
        postId,
        currentUserId: _currentUserId,
      );
    }
  }
}
