import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'comment.dart';
import '../config/supabase_config.dart';
part 'post.g.dart';

/// Represents a media attachment for a post
@JsonSerializable()
class PostMedia {
  final String id;
  final String postId;
  final String mediaType; // 'image', 'video'
  final String storagePath;
  final String? mimeType;
  final int? width;
  final int? height;
  final double? durationSeconds;

  PostMedia({
    required this.id,
    required this.postId,
    required this.mediaType,
    required this.storagePath,
    this.mimeType,
    this.width,
    this.height,
    this.durationSeconds,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) =>
      _$PostMediaFromJson(json);
  Map<String, dynamic> toJson() => _$PostMediaToJson(this);

  factory PostMedia.fromSupabase(Map<String, dynamic> json) {
    return PostMedia(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      storagePath: json['storage_path']?.toString() ?? '',
      mimeType: json['mime_type'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'post_id': postId,
      'media_type': mediaType,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'width': width,
      'height': height,
      'duration_seconds': durationSeconds,
    };
  }
}

/// Represents a tag/topic for a post
@JsonSerializable()
class PostTag {
  final String id;
  final String tag;

  PostTag({required this.id, required this.tag});

  factory PostTag.fromJson(Map<String, dynamic> json) =>
      _$PostTagFromJson(json);
  Map<String, dynamic> toJson() => _$PostTagToJson(this);

  factory PostTag.fromSupabase(Map<String, dynamic> json) {
    return PostTag(
      id: json['id']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
    );
  }
}

@JsonSerializable()
class PostAuthor {
  final String? userId;
  final String displayName;
  final String username;
  final String avatar;
  final bool isVerified;
  final bool isFollowing;
  final String?
  postsVisibility; // Privacy setting: 'everyone', 'followers', 'private'

  PostAuthor({
    this.userId,
    required this.displayName,
    required this.username,
    required this.avatar,
    this.isVerified = false,
    this.isFollowing = false,
    this.postsVisibility,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) =>
      _$PostAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$PostAuthorToJson(this);

  PostAuthor copyWith({
    String? userId,
    String? displayName,
    String? username,
    String? avatar,
    bool? isVerified,
    bool? isFollowing,
    String? postsVisibility,
  }) {
    return PostAuthor(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      isVerified: isVerified ?? this.isVerified,
      isFollowing: isFollowing ?? this.isFollowing,
      postsVisibility: postsVisibility ?? this.postsVisibility,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class Post {
  final String id;
  final PostAuthor author;
  final String content;
  final String? mediaUrl;
  final List<PostMedia>? mediaList; // Multiple media support
  final List<PostTag>? tags; // Tags/topics
  final String? location; // Location string
  final List<String>? mentionedUserIds; // Tagged users
  final int likes;
  final int comments;
  final String visibility; // 'everyone', 'followers', 'private'
  final double tips;
  final String timestamp;
  final bool isNFT;
  final bool isLiked;
  final String? userReaction; // Current user's reaction type (like, love, laugh, sad, angry, wow) or null
  final Map<String, int> reactionCounts; // Breakdown: {'like': 5, 'love': 2, ...}
  final int totalReactions; // Total count of all reactions
  final List<Comment>? commentList;

  // AI verification fields (matching web)
  final double? aiConfidenceScore; // 0-100 probability of AI generation
  final String? detectionStatus; // 'pending', 'approved', 'flagged', 'removed'

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.mediaUrl,
    this.mediaList,
    this.tags,
    this.location,
    this.mentionedUserIds,
    this.likes = 0,
    this.visibility = 'everyone', // Default to everyone
    this.comments = 0,
    this.tips = 0,
    required this.timestamp,
    this.isNFT = false,
    this.isLiked = false,
    this.userReaction,
    this.reactionCounts = const {},
    this.totalReactions = 0,
    this.commentList,
    this.aiConfidenceScore,
    this.detectionStatus,
    this.reposter,
    this.repostedAt,
  });

  final PostAuthor? reposter;
  final String? repostedAt;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({
    String? id,
    PostAuthor? author,
    String? content,
    String? mediaUrl,
    List<PostMedia>? mediaList,
    List<PostTag>? tags,
    String? location,
    List<String>? mentionedUserIds,
    int? likes,
    String? visibility,
    int? comments,
    double? tips,
    String? timestamp,
    bool? isNFT,
    bool? isLiked,
    String? userReaction,
    bool clearUserReaction = false,
    Map<String, int>? reactionCounts,
    int? totalReactions,
    List<Comment>? commentList,
    double? aiConfidenceScore,
    String? detectionStatus,
    PostAuthor? reposter,
    String? repostedAt,
  }) {
    return Post(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaList: mediaList ?? this.mediaList,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      likes: likes ?? this.likes,
      visibility: visibility ?? this.visibility,
      comments: comments ?? this.comments,
      tips: tips ?? this.tips,
      timestamp: timestamp ?? this.timestamp,
      isNFT: isNFT ?? this.isNFT,
      isLiked: isLiked ?? this.isLiked,
      userReaction: clearUserReaction ? null : (userReaction ?? this.userReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      totalReactions: totalReactions ?? this.totalReactions,
      commentList: commentList ?? this.commentList,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      detectionStatus: detectionStatus ?? this.detectionStatus,
      reposter: reposter ?? this.reposter,
      repostedAt: repostedAt ?? this.repostedAt,
    );
  }

  // Helper to check if post is human verified (AI confidence < 20%)
  bool get isHumanVerified =>
      aiConfidenceScore != null && aiConfidenceScore! < 20;

  // Helper to get first media URL (for backward compatibility)
  String? get primaryMediaUrl {
    if (mediaUrl != null) return mediaUrl;
    if (mediaList != null && mediaList!.isNotEmpty) {
      final path = mediaList!.first.storagePath;
      if (path.startsWith('http')) return path;
      return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/media/$path';
    }
    return null;
  }

  // Check if post has media
  bool get hasMedia =>
      mediaUrl != null || (mediaList != null && mediaList!.isNotEmpty);

  String get authorId => author.userId ?? '';

  /// Create a Post from Supabase response with joined profile data.
  factory Post.fromSupabase(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    // Parse reactions - build per-type counts and find current user's reaction
    final reactions = json['reactions'] as List<dynamic>? ?? [];

    debugPrint(
      'Post.fromSupabase: Post ${json['id']} has ${reactions.length} reactions, currentUserId=$currentUserId',
    );

    // Build reaction counts map
    final reactionCounts = <String, int>{};
    String? userReaction;
    for (final r in reactions) {
      final type = r['reaction'] as String;
      reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
      if (currentUserId != null && r['user_id'] == currentUserId) {
        userReaction = type;
      }
    }

    final isLiked = userReaction == 'like';
    final likesCount = reactionCounts['like'] ?? 0;
    final totalReactions = reactions.length;

    debugPrint('Post.fromSupabase: userReaction=$userReaction, likesCount=$likesCount, totalReactions=$totalReactions');

    // Parse media list
    final mediaJson = json['post_media'] as List<dynamic>? ?? [];
    final mediaList = mediaJson.isNotEmpty
        ? mediaJson
              .map((m) => PostMedia.fromSupabase(m as Map<String, dynamic>))
              .toList()
        : null;

    // Parse tags through post_tags junction
    final postTagsJson = json['post_tags'] as List<dynamic>? ?? [];
    List<PostTag>? tags;
    if (postTagsJson.isNotEmpty) {
      tags = postTagsJson
          .where((pt) => pt['tags'] != null)
          .map((pt) => PostTag.fromSupabase(pt['tags'] as Map<String, dynamic>))
          .toList();
    }

    // Parse mentions
    final mentionsJson = json['mentions'] as List<dynamic>? ?? [];
    List<String>? mentionedUserIds;
    if (mentionsJson.isNotEmpty) {
      mentionedUserIds = mentionsJson
          .map((m) => m['mentioned_user_id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();
    }

    return Post(
      id: json['id']?.toString() ?? '',
      author: PostAuthor(
        userId: profile?['user_id'] as String?,
        displayName: profile?['display_name'] ?? '',
        username: profile?['username'] ?? 'unknown',
        avatar: profile?['avatar_url'] ?? '',
        isVerified: profile?['verified_human'] == 'verified',
        isFollowing: false, // Will be populated separately if needed
        postsVisibility: profile?['posts_visibility'] as String?,
      ),
      content: json['body'] ?? '',
      mediaUrl: json['media_url'] as String?,
      mediaList: mediaList,
      tags: tags,
      location: json['location'] as String?,
      mentionedUserIds: mentionedUserIds,
      likes: likesCount,
      visibility: json['visibility'] as String? ?? 'everyone',
      comments: (json['comments'] as List<dynamic>?)?.length ?? 0,
      tips: (json['tip_total'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['created_at'] ?? DateTime.now().toIso8601String(),
      isNFT: json['is_nft'] ?? false,
      isLiked: isLiked,
      userReaction: userReaction,
      reactionCounts: reactionCounts,
      totalReactions: totalReactions,
      aiConfidenceScore: (json['ai_confidence_score'] as num?)?.toDouble(),
      detectionStatus: json['status'] as String?,
      reposter: json['reposter'] != null
          ? PostAuthor(
              userId: json['reposter']['user_id'] as String?,
              displayName: json['reposter']['display_name'] ?? '',
              username: json['reposter']['username'] ?? 'unknown',
              avatar: json['reposter']['avatar_url'] ?? '',
              isVerified: json['reposter']['verified_human'] == 'verified',
            )
          : null,
      repostedAt: json['reposted_at'] as String?,
    );
  }

  /// Convert to Supabase insert format.
  Map<String, dynamic> toSupabase(String authorId) {
    return {
      'author_id': authorId,
      'body': content,
      'title': null,
      'visibility': visibility, // Add visibility here
      'body_format': 'plain',
      'status': 'published',
    };
  }
}
