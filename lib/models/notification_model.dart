import 'package:json_annotation/json_annotation.dart';
import '../utils/time_utils.dart';

part 'notification_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class NotificationModel {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String type; // 'like', 'comment', 'mention', 'follow', etc.
  final String? title;
  final String? body;
  @JsonKey(name: 'is_read')
  final bool isRead;
  @JsonKey(name: 'actor_id')
  final String? actorId;
  @JsonKey(name: 'post_id')
  final String? postId;
  @JsonKey(name: 'comment_id')
  final String? commentId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  // Related data from joins (excluded from JSON serialization)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final ActorProfile? actor;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final PostPreview? post;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final CommentPreview? comment;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.body,
    this.isRead = false,
    this.actorId,
    this.postId,
    this.commentId,
    required this.createdAt,
    this.actor,
    this.post,
    this.comment,
  });

  /// Create from Supabase response with joined data
  factory NotificationModel.fromSupabase(Map<String, dynamic> json) {
    // Parse actor profile if present
    ActorProfile? actor;
    if (json['actor'] != null) {
      final actorData = json['actor'] is List
          ? (json['actor'] as List).isNotEmpty
                ? json['actor'][0]
                : null
          : json['actor'];
      if (actorData != null) {
        actor = ActorProfile(
          id: actorData['user_id'] as String? ?? '',
          username: actorData['username'] as String? ?? '',
          displayName: actorData['display_name'] as String? ?? '',
          avatarUrl: actorData['avatar_url'] as String?,
        );
      }
    }

    // Parse post preview if present
    PostPreview? post;
    if (json['post'] != null) {
      final postData = json['post'] is List
          ? (json['post'] as List).isNotEmpty
                ? json['post'][0]
                : null
          : json['post'];
      if (postData != null) {
        post = PostPreview(
          id: postData['id'] as String? ?? '',
          title: postData['title'] as String?,
          body: postData['body'] as String? ?? '',
        );
      }
    }

    // Parse comment preview if present
    CommentPreview? comment;
    if (json['comment'] != null) {
      final commentData = json['comment'] is List
          ? (json['comment'] as List).isNotEmpty
                ? json['comment'][0]
                : null
          : json['comment'];
      if (commentData != null) {
        comment = CommentPreview(
          id: commentData['id'] as String? ?? '',
          body: commentData['body'] as String? ?? '',
        );
      }
    }

    // Parse created_at
    DateTime createdAt;
    if (json['created_at'] is String) {
      createdAt = DateTime.parse(json['created_at'] as String);
    } else if (json['created_at'] != null) {
      createdAt = DateTime.parse(json['created_at'].toString());
    } else {
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String?,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      actorId: json['actor_id'] as String?,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      createdAt: createdAt,
      actor: actor,
      post: post,
      comment: comment,
    );
  }

  /// Generate a human-readable title based on type and actor
  String getDisplayTitle() {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }

    final actorName = actor?.displayName ?? actor?.username ?? 'Someone';
    switch (type) {
      case 'like':
      case 'reaction':
        return '$actorName liked your post';
      case 'comment':
        return '$actorName commented on your post';
      case 'reply':
        return '$actorName replied to your comment';
      case 'roocoin_received':
        return 'Received RooCoin';
      case 'roocoin_sent':
        return 'Sent RooCoin';
      case 'mention':
        return '$actorName mentioned you';
      case 'follow':
        return '$actorName started following you';
      // AI Check notification types
      case 'post_published':
        return 'Post Published';
      case 'post_review':
        return 'Post Under Review';
      case 'post_flagged':
        return 'Post Not Published';
      case 'comment_published':
        return 'Comment Published';
      case 'comment_review':
        return 'Comment Under Review';
      case 'comment_flagged':
        return 'Comment Not Published';
      case 'story_published':
        return 'Story Published';
      case 'story_review':
        return 'Story Under Review';
      case 'story_flagged':
        return 'Story Not Published';
      default:
        return title ?? 'New notification';
    }
  }

  /// Generate a human-readable body based on type and content
  String getDisplayBody() {
    if (body != null && body!.isNotEmpty) {
      return body!;
    }

    switch (type) {
      case 'comment':
      case 'reply':
        if (comment != null && comment!.body.isNotEmpty) {
          // Truncate long comments
          final commentText = comment!.body;
          return commentText.length > 100
              ? '${commentText.substring(0, 100)}...'
              : commentText;
        }
        return type == 'reply' ? 'Replied to your comment' : 'Left a comment';
      case 'mention':
        if (post != null && post!.body.isNotEmpty) {
          final postText = post!.body;
          return postText.length > 100
              ? '${postText.substring(0, 100)}...'
              : postText;
        }
        if (comment != null && comment!.body.isNotEmpty) {
          final commentText = comment!.body;
          return commentText.length > 100
              ? '${commentText.substring(0, 100)}...'
              : commentText;
        }
        return 'Mentioned you';
      case 'like':
      case 'reaction':
        if (post != null && post!.title != null && post!.title!.isNotEmpty) {
          return post!.title!;
        }
        if (post != null && post!.body.isNotEmpty) {
          final postText = post!.body;
          return postText.length > 100
              ? '${postText.substring(0, 100)}...'
              : postText;
        }
        return '';
      case 'follow':
        return '';
      default:
        return body ?? '';
    }
  }

  /// Get human-readable time
  String getTimeAgo() {
    return humanReadableTime(createdAt.toIso8601String());
  }

  /// Get icon for notification type
  String getIcon() {
    switch (type) {
      case 'like':
      case 'reaction':
        return '❤️';
      case 'comment':
      case 'reply':
        return '💬';
      case 'mention':
        return '@';
      case 'follow':
        return '👤';
      // ROO transfer notifications
      case 'roocoin_received':
        return '💰';
      case 'roocoin_sent':
        return '💸';
      // AI Check notification types
      case 'post_published':
      case 'comment_published':
      case 'story_published':
        return '✅';
      case 'post_review':
      case 'comment_review':
      case 'story_review':
        return '🔍';
      case 'post_flagged':
      case 'comment_flagged':
      case 'story_flagged':
        return '⚠️';
      default:
        return '🔔';
    }
  }

  /// Check if this is a system notification (no actor)
  bool get isSystemNotification {
    return type.startsWith('post_') ||
        type.startsWith('comment_') ||
        type.startsWith('story_') ||
        type == 'roocoin_received' ||
        type == 'roocoin_sent';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    bool? isRead,
    String? actorId,
    String? postId,
    String? commentId,
    DateTime? createdAt,
    ActorProfile? actor,
    PostPreview? post,
    CommentPreview? comment,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      actorId: actorId ?? this.actorId,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      createdAt: createdAt ?? this.createdAt,
      actor: actor ?? this.actor,
      post: post ?? this.post,
      comment: comment ?? this.comment,
    );
  }
}

/// Actor profile data from join
class ActorProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  ActorProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });
}

/// Post preview data from join
class PostPreview {
  final String id;
  final String? title;
  final String body;

  PostPreview({required this.id, this.title, required this.body});
}

/// Comment preview data from join
class CommentPreview {
  final String id;
  final String body;

  CommentPreview({required this.id, required this.body});
}
