import 'package:json_annotation/json_annotation.dart';

part 'comment.g.dart';

@JsonSerializable()
class CommentAuthor {
  final String displayName;
  final String username;
  final String? avatar;
  final bool isVerified;
  final String?
  commentsVisibility; // Privacy setting: 'everyone', 'followers', 'private'

  CommentAuthor({
    required this.displayName,
    required this.username,
    this.isVerified = false,
    this.avatar,
    this.commentsVisibility,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommentAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$CommentAuthorToJson(this);
}

@JsonSerializable()
class Comment {
  final String id;
  final String? authorId;
  final CommentAuthor author;
  final String text;
  final String timestamp;
  final int likes;
  final bool isLiked;
  final List<Comment>? replies;
  final String? mediaUrl;
  final String? mediaType;
  Comment({
    required this.id,
    this.authorId,
    required this.author,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.isLiked = false,
    this.replies,
    this.mediaUrl,
    this.mediaType,
  });

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
  Map<String, dynamic> toJson() => _$CommentToJson(this);

  Comment copyWith({
    String? id,
    String? authorId,
    CommentAuthor? author,
    String? text,
    String? timestamp,
    int? likes,
    bool? isLiked,
    List<Comment>? replies,
    String? mediaUrl,
    String? mediaType,
  }) {
    return Comment(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
    );
  }

  /// Create a Comment from Supabase response with joined profile data.
  factory Comment.fromSupabase(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    // Parse reactions to check if current user liked this comment
    final reactions = json['reactions'] as List<dynamic>? ?? [];
    final isLiked =
        currentUserId != null &&
        reactions.any(
          (r) => r['user_id'] == currentUserId && r['reaction'] == 'like',
        );
    final likesCount = reactions.where((r) => r['reaction'] == 'like').length;

    // Parse nested replies
    final repliesData = json['replies'] as List<dynamic>? ?? [];
    final replies = repliesData
        .map(
          (r) => Comment.fromSupabase(
            r as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();

    return Comment(
      id: json['id'] as String,
      authorId: json['author_id'] as String?,
      author: CommentAuthor(
        displayName:
            profile?['display_name'] ?? profile?['username'] ?? 'Unknown',
        username: profile?['username'] ?? 'unknown',
        isVerified: profile?['verified_human'] == 'verified',
        avatar: profile?['avatar_url'] as String?,
        commentsVisibility: profile?['comments_visibility'] as String?,
      ),
      text: json['body'] ?? '',
      timestamp: json['created_at'] ?? DateTime.now().toIso8601String(),
      likes: likesCount,
      isLiked: isLiked,
      replies: replies.isNotEmpty ? replies : null,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }

  /// Convert to Supabase insert format.
  Map<String, dynamic> toSupabase({
    required String postId,
    required String authorId,
    String? parentCommentId,
  }) {
    return {
      'post_id': postId,
      'author_id': authorId,
      'parent_comment_id': parentCommentId,
      'body': text,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    };
  }
}
