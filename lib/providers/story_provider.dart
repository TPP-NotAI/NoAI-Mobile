import 'package:flutter/foundation.dart';

import '../models/story.dart';
import '../models/story_media_input.dart';
import '../services/supabase_service.dart';
import '../repositories/story_repository.dart';
import '../repositories/reaction_repository.dart';

/// Provider to manage feed stories/statuses.
class StoryProvider extends ChangeNotifier {
  final StoryRepository _storyRepository = StoryRepository();
  final ReactionRepository _reactionRepository = ReactionRepository();
  final SupabaseService _supabase = SupabaseService();

  List<Story> _stories = [];
  bool _isLoading = false;
  String? _error;

  StoryProvider() {
    loadStories();
  }

  List<Story> get stories => _stories.where(_canViewStory).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _canViewStory(Story story) {
    if (story.status == 'flagged') return false;
    final currentUserId = _supabase.currentUser?.id;
    if (story.status == 'review' && story.userId != currentUserId) {
      return false;
    }
    return true;
  }

  /// Latest (newest) story per user, sorted by most recent.
  List<Story> get latestStoriesPerUser {
    final Map<String, Story> latestByUser = {};
    for (final story in _stories) {
      if (!_canViewStory(story)) continue;
      final existing = latestByUser[story.userId];
      if (existing == null || existing.createdAt.isBefore(story.createdAt)) {
        latestByUser[story.userId] = story;
      }
    }
    final list = latestByUser.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Story> get currentUserStories {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return [];
    final stories =
        _stories
            .where((story) => story.userId == userId)
            .where(_canViewStory)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return stories;
  }

  Future<void> loadStories() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) {
      _stories = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _stories = await _storyRepository.fetchFeedStories(currentUserId: userId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load stories';
      debugPrint('StoryProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadStories();

  Future<void> markViewed(Story story) async {
    final viewerId = _supabase.currentUser?.id;
    if (viewerId == null || story.isViewed) return;

    final inserted = await _storyRepository.markStoryViewed(
      storyId: story.id,
      viewerId: viewerId,
    );

    _stories = _stories.map((s) {
      if (s.id != story.id) return s;
      return s.copyWith(
        isViewed: true,
        viewCount: inserted ? s.viewCount + 1 : s.viewCount,
      );
    }).toList();
    notifyListeners();
  }

  Future<Story?> createStory({
    required String mediaUrl,
    required String mediaType,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final newStory = await _storyRepository.createStory(
        userId: userId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
        backgroundColor: backgroundColor,
        textOverlay: textOverlay,
        textPosition: textPosition,
      );

      if (newStory != null) {
        _stories.insert(0, newStory); // Add to the beginning of the list
        notifyListeners();

        // Trigger AI detection
        _triggerAiDetection(newStory, mediaUrl, mediaType, caption);
      }

      return newStory;
    } catch (e) {
      _error = 'Failed to create story';
      debugPrint('StoryProvider: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create multiple stories from a batch of media uploads.
  Future<List<Story>> createStories({
    required List<StoryMediaInput> mediaItems,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null || mediaItems.isEmpty) return [];

    _isLoading = true;
    notifyListeners();

    try {
      final newStories = await _storyRepository.createStories(
        userId: userId,
        mediaItems: mediaItems,
        caption: caption,
        backgroundColor: backgroundColor,
        textOverlay: textOverlay,
        textPosition: textPosition,
      );

      if (newStories.isNotEmpty) {
        _stories = [...newStories, ..._stories];
        notifyListeners();

        // Trigger AI detection for each
        for (int i = 0; i < newStories.length; i++) {
          _triggerAiDetection(
            newStories[i],
            mediaItems[i].url,
            mediaItems[i].mediaType,
            caption,
          );
        }
      }

      return newStories;
    } catch (e) {
      _error = 'Failed to create stories';
      debugPrint('StoryProvider: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _triggerAiDetection(
    Story story,
    String mediaUrl,
    String mediaType,
    String? caption,
  ) async {
    try {
      final result = await _storyRepository.runAiDetection(
        storyId: story.id,
        authorId: story.userId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
      );

      if (result != null) {
        final score = result['score'] as double;
        final status = result['status'] as String;

        // Update local state
        _stories = _stories.map((s) {
          if (s.id != story.id) return s;
          return s.copyWith(aiScore: score, status: status);
        }).toList();

        notifyListeners();
      }
    } catch (e) {
      debugPrint('StoryProvider: AI detection trigger failed - $e');
    }
  }

  /// Delete a story owned by the current user.
  Future<bool> deleteStory(String storyId) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return false;

    final success = await _storyRepository.deleteStory(
      storyId: storyId,
      userId: userId,
    );

    if (success) {
      _stories = _stories.where((s) => s.id != storyId).toList();
      notifyListeners();
    }

    return success;
  }

  /// Fetch viewers list for a story.
  Future<List<Map<String, dynamic>>> fetchViewers(String storyId) async {
    return _storyRepository.fetchStoryViewers(storyId: storyId);
  }

  Future<void> toggleLike(Story story) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;

    // Optimistic update
    final bool currentlyLiked = story.isLiked ?? false;
    final int currentLikes = story.likes ?? 0;

    _stories = _stories.map((s) {
      if (s.id != story.id) return s;
      return s.copyWith(
        isLiked: !currentlyLiked,
        likes: currentlyLiked ? currentLikes - 1 : currentLikes + 1,
      );
    }).toList();
    notifyListeners();

    try {
      final isLiked = await _reactionRepository.toggleStoryLike(
        storyId: story.id,
        userId: userId,
      );

      // Verify and update if server returned different result (unlikely but safe)
      _stories = _stories.map((s) {
        if (s.id != story.id) return s;
        if (s.isLiked == isLiked) return s;
        return s.copyWith(
          isLiked: isLiked,
          likes: isLiked ? currentLikes + 1 : currentLikes - 1,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('StoryProvider: Failed to toggle like - $e');
      // Revert on error
      _stories = _stories.map((s) {
        if (s.id != story.id) return s;
        return s.copyWith(isLiked: currentlyLiked, likes: currentLikes);
      }).toList();
      notifyListeners();
    }
  }
}
