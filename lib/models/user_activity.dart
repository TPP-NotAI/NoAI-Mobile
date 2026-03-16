/// Types of user activities
enum UserActivityType {
  postCreated,
  postLiked,
  postCommented,
  postReposted,
  userFollowed,
  roochipEarned,
  roochipSpent,
  roochipTransferred,
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
        final followedLabel =
            (targetDisplayName != null && targetDisplayName!.trim().isNotEmpty)
            ? targetDisplayName!.trim()
            : (targetUsername != null && targetUsername!.trim().isNotEmpty)
            ? '@${targetUsername!.trim()}'
            : 'a user';
        return 'Followed $followedLabel';
      case UserActivityType.roochipEarned:
        return 'Earned ${amount?.toStringAsFixed(2)} ROO';
      case UserActivityType.roochipSpent:
        return 'Spent ${amount?.toStringAsFixed(2)} ROO';
      case UserActivityType.roochipTransferred:
        final recipientLabel =
            (targetDisplayName != null &&
                targetDisplayName!.trim().isNotEmpty &&
                targetDisplayName!.trim().toLowerCase() != 'null')
            ? targetDisplayName!.trim()
            : (targetUsername != null &&
                  targetUsername!.trim().isNotEmpty &&
                  targetUsername!.trim().toLowerCase() != 'null')
            ? '@${targetUsername!.trim()}'
            : 'recipient';
        return 'Transferred ${amount?.toStringAsFixed(2)} ROO to $recipientLabel';
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
      case UserActivityType.roochipEarned:
        return 'add_circle';
      case UserActivityType.roochipSpent:
        return 'remove_circle';
      case UserActivityType.roochipTransferred:
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
        return '#DEA331'; // brand gold
      case UserActivityType.userFollowed:
        return '#F59E0B'; // amber
      case UserActivityType.roochipEarned:
        return '#DEA331'; // brand gold
      case UserActivityType.roochipSpent:
        return '#EF4444'; // red
      case UserActivityType.roochipTransferred:
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
