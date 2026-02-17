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
    final status = story.status?.trim().toLowerCase();
    return status == 'pass';
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
      _logStoryVisibilityDiagnostics(source: 'loadStories');
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
        _stories.insert(0, newStory);
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
  /// For text-only stories, pass an empty mediaItems list with textOverlay set.
  Future<List<Story>> createStories({
    required List<StoryMediaInput> mediaItems,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return [];

    // Allow empty mediaItems for text-only stories (must have textOverlay)
    if (mediaItems.isEmpty &&
        (textOverlay == null || textOverlay.trim().isEmpty)) {
      return [];
    }

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
          final story = newStories[i];
          final mediaUrl = i < mediaItems.length ? mediaItems[i].url : '';
          final mediaType = i < mediaItems.length
              ? mediaItems[i].mediaType
              : 'text';
          _triggerAiDetection(
            story,
            mediaUrl,
            mediaType,
            caption ?? textOverlay,
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

  /// Create a text-only story without media.
  Future<Story?> createTextStory({
    required String text,
    String? backgroundColor,
    Map<String, dynamic>? textPosition,
  }) async {
    final stories = await createStories(
      mediaItems: [],
      textOverlay: text,
      backgroundColor: backgroundColor ?? '#000000',
      textPosition: textPosition,
    );
    return stories.isNotEmpty ? stories.first : null;
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

        bool exists = false;
        _stories = _stories.map((s) {
          if (s.id != story.id) return s;
          exists = true;
          return s.copyWith(aiScore: score, status: status);
        }).toList();

        // If story wasn't in local list yet but passed, surface it now.
        final normalizedStatus = status.trim().toLowerCase();
        if (!exists &&
            (normalizedStatus == 'pass' ||
                normalizedStatus == 'passed' ||
                normalizedStatus == 'published' ||
                normalizedStatus == 'approved' ||
                normalizedStatus == 'human')) {
          _stories.insert(0, story.copyWith(aiScore: score, status: status));
        }

        _logStoryVisibilityDiagnostics(source: 'aiDetection:${story.id}');
        notifyListeners();
        _showStoryAiResultSnackBar(status);
      }
    } catch (e) {
      debugPrint('StoryProvider: AI detection trigger failed - $e');
    }
  }

  void _showStoryAiResultSnackBar(String _status) {
    // AI status snackbars are handled centrally by NotificationProvider via
    // real-time notifications. Suppress local duplicate snackbars here.
    return;
  }

  void _logStoryVisibilityDiagnostics({required String source}) {
    final statusCounts = <String, int>{};
    final hiddenStories = <String>[];
    final visibleStories = <String>[];

    for (final story in _stories) {
      final status = story.status?.trim().toLowerCase() ?? 'null';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      if (_canViewStory(story)) {
        visibleStories.add('${story.id}[$status]');
      } else {
        hiddenStories.add('${story.id}[$status]');
      }
    }

    debugPrint(
      'StoryProvider: diagnostics source=$source total=${_stories.length} '
      'visible=${visibleStories.length} hidden=${hiddenStories.length} '
      'statuses=$statusCounts',
    );

    if (hiddenStories.isNotEmpty) {
      debugPrint(
        'StoryProvider: hidden stories sample=${hiddenStories.take(10).toList()}',
      );
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
