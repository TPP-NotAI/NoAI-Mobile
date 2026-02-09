/// Types of user activities
enum UserActivityType {
  postCreated,
  postLiked,
  postCommented,
  postReposted,
  userFollowed,
  roocoinEarned,
  roocoinSpent,
  roocoinTransferred,
  storyCreated,
  bookmarkAdded,
}

/// Represents a user's app activity
class UserActivity {
  final String id;
  final UserActivityType type;
  final DateTime timestamp;
  final String? postId;
  final String? postContent;
  final String? postMediaUrl;
  final String? targetUserId;
  final String? targetUsername;
  final String? targetDisplayName;
  final String? targetAvatarUrl;
  final double? amount;
  final String? transactionType;
  final String? commentContent;

  UserActivity({
    required this.id,
    required this.type,
    required this.timestamp,
    this.postId,
    this.postContent,
    this.postMediaUrl,
    this.targetUserId,
    this.targetUsername,
    this.targetDisplayName,
    this.targetAvatarUrl,
    this.amount,
    this.transactionType,
    this.commentContent,
  });

  /// Get display title for the activity
  String get displayTitle {
    switch (type) {
      case UserActivityType.postCreated:
        return 'Created a post';
      case UserActivityType.postLiked:
        return 'Liked a post';
      case UserActivityType.postCommented:
        return 'Commented on a post';
      case UserActivityType.postReposted:
        return 'Reposted';
      case UserActivityType.userFollowed:
        return 'Followed ${targetDisplayName ?? '@$targetUsername'}';
      case UserActivityType.roocoinEarned:
        return 'Earned ${amount?.toStringAsFixed(1)} ROO';
      case UserActivityType.roocoinSpent:
        return 'Spent ${amount?.toStringAsFixed(1)} ROO';
      case UserActivityType.roocoinTransferred:
        return 'Transferred ${amount?.toStringAsFixed(1)} ROO to @$targetUsername';
      case UserActivityType.storyCreated:
        return 'Created a story';
      case UserActivityType.bookmarkAdded:
        return 'Bookmarked a post';
    }
  }

  /// Get icon name for the activity
  String get iconName {
    switch (type) {
      case UserActivityType.postCreated:
        return 'edit_note';
      case UserActivityType.postLiked:
        return 'favorite';
      case UserActivityType.postCommented:
        return 'chat_bubble';
      case UserActivityType.postReposted:
        return 'repeat';
      case UserActivityType.userFollowed:
        return 'person_add';
      case UserActivityType.roocoinEarned:
        return 'add_circle';
      case UserActivityType.roocoinSpent:
        return 'remove_circle';
      case UserActivityType.roocoinTransferred:
        return 'send';
      case UserActivityType.storyCreated:
        return 'auto_stories';
      case UserActivityType.bookmarkAdded:
        return 'bookmark';
    }
  }

  /// Get color for the activity type
  String get colorHex {
    switch (type) {
      case UserActivityType.postCreated:
        return '#3B82F6'; // blue
      case UserActivityType.postLiked:
        return '#EF4444'; // red
      case UserActivityType.postCommented:
        return '#8B5CF6'; // purple
      case UserActivityType.postReposted:
        return '#10B981'; // green
      case UserActivityType.userFollowed:
        return '#F59E0B'; // amber
      case UserActivityType.roocoinEarned:
        return '#10B981'; // green
      case UserActivityType.roocoinSpent:
        return '#EF4444'; // red
      case UserActivityType.roocoinTransferred:
        return '#F59E0B'; // amber
      case UserActivityType.storyCreated:
        return '#EC4899'; // pink
      case UserActivityType.bookmarkAdded:
        return '#6366F1'; // indigo
    }
  }

  /// Get preview content for the activity
  String? get previewContent {
    if (postContent != null && postContent!.isNotEmpty) {
      return postContent!.length > 80
          ? '${postContent!.substring(0, 80)}...'
          : postContent;
    }
    if (commentContent != null && commentContent!.isNotEmpty) {
      return commentContent!.length > 80
          ? '${commentContent!.substring(0, 80)}...'
          : commentContent;
    }
    return null;
  }

}
