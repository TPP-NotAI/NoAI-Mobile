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
  final String name;

  PostTag({required this.id, required this.name});

  factory PostTag.fromJson(Map<String, dynamic> json) =>
      _$PostTagFromJson(json);
  Map<String, dynamic> toJson() => _$PostTagToJson(this);

  factory PostTag.fromSupabase(Map<String, dynamic> json) {
    return PostTag(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
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
  final double tips; // Matches total_tips_rc
  final String timestamp; // created_at
  final bool isNFT;
  final bool isLiked;
  final String?
  userReaction; // Current user's reaction type (like, love, laugh, sad, angry, wow) or null
  final Map<String, int>
  reactionCounts; // Breakdown: {'like': 5, 'love': 2, ...}
  final int totalReactions; // Total count of all reactions
  final List<Comment>? commentList;

  // New fields from schema
  final String? title;
  final String bodyFormat;
  final int reposts; // reposts_count
  final int views; // views_count
  final int shares; // shares_count
  final double publishFee; // publish_fee_rc
  final bool isSensitive;
  final String? sensitiveReason;
  final String? scheduledAt;
  final String? publishedAt;
  final int editCount;
  final String? lastEditedAt;
  final String? updatedAt;

  // AI-related fields from schema
  final bool humanCertified;
  final double? aiScore; // Same as aiConfidenceScore
  final String? aiScoreStatus; // Same as detectionStatus
  final String? authenticityNotes;
  final String? verificationMethod;
  final String? verificationSessionId;
  final Map<String, dynamic>? aiMetadata; // Full AI detection metadata JSONB

  // AI verification fields (matching web - kept for compatibility)
  final double? aiConfidenceScore; // 0-100 probability of AI generation
  final String?
  detectionStatus; // 'pass', 'review', 'flagged' (from ai_score_status column)
  final String
  status; // 'draft', 'published', 'under_review', 'hidden', 'deleted', 'scheduled'

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
    this.humanCertified = false,
    this.aiScore,
    this.aiScoreStatus,
    this.authenticityNotes,
    this.verificationMethod,
    this.verificationSessionId,
    this.aiMetadata,
    this.aiConfidenceScore,
    this.detectionStatus,
    this.status = 'published',
    this.reposter,
    this.repostedAt,
    this.title,
    this.bodyFormat = 'plain',
    this.reposts = 0,
    this.views = 0,
    this.shares = 0,
    this.publishFee = 0,
    this.isSensitive = false,
    this.sensitiveReason,
    this.scheduledAt,
    this.publishedAt,
    this.editCount = 0,
    this.lastEditedAt,
    this.updatedAt,
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
    bool? humanCertified,
    double? aiScore,
    String? aiScoreStatus,
    String? authenticityNotes,
    String? verificationMethod,
    String? verificationSessionId,
    Map<String, dynamic>? aiMetadata,
    double? aiConfidenceScore,
    String? detectionStatus,
    String? status,
    PostAuthor? reposter,
    String? repostedAt,
    String? title,
    String? bodyFormat,
    int? reposts,
    int? views,
    int? shares,
    double? publishFee,
    bool? isSensitive,
    String? sensitiveReason,
    String? scheduledAt,
    String? publishedAt,
    int? editCount,
    String? lastEditedAt,
    String? updatedAt,
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
      userReaction: clearUserReaction
          ? null
          : (userReaction ?? this.userReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      totalReactions: totalReactions ?? this.totalReactions,
      commentList: commentList ?? this.commentList,
      humanCertified: humanCertified ?? this.humanCertified,
      aiScore: aiScore ?? this.aiScore,
      aiScoreStatus: aiScoreStatus ?? this.aiScoreStatus,
      authenticityNotes: authenticityNotes ?? this.authenticityNotes,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      verificationSessionId:
          verificationSessionId ?? this.verificationSessionId,
      aiMetadata: aiMetadata ?? this.aiMetadata,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      detectionStatus: detectionStatus ?? this.detectionStatus,
      status: status ?? this.status,
      reposter: reposter ?? this.reposter,
      repostedAt: repostedAt ?? this.repostedAt,
      title: title ?? this.title,
      bodyFormat: bodyFormat ?? this.bodyFormat,
      reposts: reposts ?? this.reposts,
      views: views ?? this.views,
      shares: shares ?? this.shares,
      publishFee: publishFee ?? this.publishFee,
      isSensitive: isSensitive ?? this.isSensitive,
      sensitiveReason: sensitiveReason ?? this.sensitiveReason,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      publishedAt: publishedAt ?? this.publishedAt,
      editCount: editCount ?? this.editCount,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$path';
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

    // Build reaction counts map
    final reactionCounts = <String, int>{};
    String? userReaction;
    for (final r in reactions) {
      final type = r['reaction_type'] as String;
      reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
      if (currentUserId != null && r['user_id'] == currentUserId) {
        userReaction = type;
      }
    }

    final isLiked = userReaction == 'like';
    // Use schema count if available, otherwise fallback to reactions length
    final likesCount =
        json['likes_count'] as int? ?? reactionCounts['like'] ?? 0;
    final totalReactions = reactions.length;

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

    // Fallback tip total from completed tip transactions linked to this post.
    final tipTransactions = json['roocoin_transactions'] as List<dynamic>? ?? [];
    double tipsFromTransactions = 0.0;
    for (final tx in tipTransactions) {
      final txMap = tx as Map<String, dynamic>;
      final status = txMap['status']?.toString();
      if (status != 'completed') continue;

      final metadata = txMap['metadata'];
      final activityType = metadata is Map ? metadata['activityType'] : null;
      if (activityType?.toString() != 'tip') continue;

      tipsFromTransactions += (txMap['amount_rc'] as num?)?.toDouble() ?? 0.0;
    }

    final persistedTipTotal = (json['total_tips_rc'] as num?)?.toDouble();
    final legacyTipTotal = (json['tip_total'] as num?)?.toDouble();
    final resolvedTips =
        persistedTipTotal ??
        legacyTipTotal ??
        (tipsFromTransactions > 0 ? tipsFromTransactions : 0.0);

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
      comments:
          json['comments_count'] as int? ??
          (json['comments'] as List<dynamic>?)?.length ??
          0,
      tips: resolvedTips,
      timestamp: json['created_at'] ?? DateTime.now().toIso8601String(),
      isNFT: json['is_nft'] ?? false,
      isLiked: isLiked,
      userReaction: userReaction,
      reactionCounts: reactionCounts,
      totalReactions: totalReactions,
      humanCertified: json['human_certified'] ?? false,
      aiScore: (json['ai_score'] as num?)?.toDouble(),
      aiScoreStatus: json['ai_score_status'] as String?,
      authenticityNotes: json['authenticity_notes'] as String?,
      verificationMethod: json['verification_method'] as String?,
      verificationSessionId: json['verification_session_id'] as String?,
      aiMetadata: json['ai_metadata'] as Map<String, dynamic>?,
      aiConfidenceScore: (json['ai_score'] as num?)?.toDouble(),
      detectionStatus: json['ai_score_status'] as String?,
      status: json['status'] as String? ?? 'published',
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
      title: json['title'] as String?,
      bodyFormat: json['body_format'] as String? ?? 'plain',
      reposts: json['reposts_count'] as int? ?? 0,
      views: json['views_count'] as int? ?? 0,
      shares: json['shares_count'] as int? ?? 0,
      publishFee: (json['publish_fee_rc'] as num?)?.toDouble() ?? 0.0,
      isSensitive: json['is_sensitive'] ?? false,
      sensitiveReason: json['sensitive_reason'] as String?,
      scheduledAt: json['scheduled_at'] as String?,
      publishedAt: json['published_at'] as String?,
      editCount: json['edit_count'] as int? ?? 0,
      lastEditedAt: json['last_edited_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Convert to Supabase insert format.
  Map<String, dynamic> toSupabase(String authorId) {
    return {
      'author_id': authorId,
      'body': content,
      'title': title,
      'visibility': visibility,
      'body_format': bodyFormat,
      'status': status,
      'location': location,
      'human_certified': humanCertified,
      'ai_score': aiScore,
      'ai_score_status': aiScoreStatus,
      'authenticity_notes': authenticityNotes,
      'verification_method': verificationMethod,
      'verification_session_id': verificationSessionId,
      'is_sensitive': isSensitive,
      'sensitive_reason': sensitiveReason,
      'scheduled_at': scheduledAt,
      'published_at': publishedAt,
    };
  }
}
