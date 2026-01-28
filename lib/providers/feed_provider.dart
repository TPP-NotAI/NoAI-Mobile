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

  List<Post> _posts = [];
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
          if (interestSet.contains(tag.tag.toLowerCase())) {
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

  // Toggle like on a post
  Future<void> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final wasLiked = post.isLiked;
    final newLikes = wasLiked ? post.likes - 1 : post.likes + 1;

    // Optimistic update
    _posts[index] = post.copyWith(likes: newLikes, isLiked: !wasLiked);
    notifyListeners();

    try {
      await _reactionRepository.togglePostLike(postId: postId, userId: userId);
    } catch (e) {
      // Revert on failure
      _posts[index] = post;
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
  Future<void> tipPost(String postId, double amount) async {
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
  Future<Comment?> addComment(
    String postId,
    String body, {
    String? tempId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

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
    final updatedComments = [...?post.commentList, newComment];

    _posts[index] = post.copyWith(
      comments: post.comments + 1,
      commentList: updatedComments,
    );

    notifyListeners();
  }

  // Add comment with media to a post (saves to Supabase)
  Future<Comment?> addCommentWithMedia(
    String postId,
    String body, {
    String? tempId,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

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
      return savedComment;
    } catch (e) {
      debugPrint('Failed to add comment with media: $e');
      return null;
    }
  }

  // Toggle like on a comment
  Future<void> toggleCommentLike(String postId, String commentId) async {
    final userId = _currentUserId;
    if (userId == null) return;

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
  Future<void> addReply(
    String postId,
    String commentId,
    String body,
    String tempId,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;

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
        return comment.copyWith(replies: [...?comment.replies, reply]);
      } else if (comment.replies != null && comment.replies!.isNotEmpty) {
        return comment.copyWith(
          replies: _addReplyRecursive(comment.replies!, commentId, reply),
        );
      }
      return comment;
    }).toList();
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

  Future<void> toggleRepost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) return;

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
  Future<Post?> createPost(
    String body, {
    String? title,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    List<String>? tags,
    String? location,
    List<String>? mentionedUserIds,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final newPost = await _postRepository.createPost(
        authorId: userId,
        body: body,
        title: title,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        tags: tags,
        location: location,
        mentionedUserIds: mentionedUserIds,
      );

      if (newPost != null) {
        // Add to the beginning of the feed
        _posts.insert(0, newPost);
        notifyListeners();
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
    final success = await _postRepository.deletePost(postId);
    if (success) {
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return success;
  }

  Future<bool> unpublishPost(String postId) async {
    final success = await _postRepository.unpublishPost(postId);
    if (success) {
      _posts.removeWhere((p) => p.id == postId);
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
    final success = await _postRepository.updatePost(
      postId: postId,
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
        final url = await _mediaRepository.uploadMedia(
          file: newMediaFiles[i],
          userId: userId,
          mediaType: newMediaTypes[i],
        );

        if (url != null) {
          await _mediaRepository.createPostMedia(
            postId: postId,
            mediaType: newMediaTypes[i],
            storagePath: url,
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
