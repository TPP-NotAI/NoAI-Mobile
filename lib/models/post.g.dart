// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostMedia _$PostMediaFromJson(Map<String, dynamic> json) => PostMedia(
  id: json['id'] as String,
  postId: json['postId'] as String,
  mediaType: json['mediaType'] as String,
  storagePath: json['storagePath'] as String,
  mimeType: json['mimeType'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PostMediaToJson(PostMedia instance) => <String, dynamic>{
  'id': instance.id,
  'postId': instance.postId,
  'mediaType': instance.mediaType,
  'storagePath': instance.storagePath,
  'mimeType': instance.mimeType,
  'width': instance.width,
  'height': instance.height,
  'durationSeconds': instance.durationSeconds,
};

PostTag _$PostTagFromJson(Map<String, dynamic> json) =>
    PostTag(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$PostTagToJson(PostTag instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

PostAuthor _$PostAuthorFromJson(Map<String, dynamic> json) => PostAuthor(
  userId: json['userId'] as String?,
  displayName: json['displayName'] as String,
  username: json['username'] as String,
  avatar: json['avatar'] as String,
  isVerified: json['isVerified'] as bool? ?? false,
  isFollowing: json['isFollowing'] as bool? ?? false,
  postsVisibility: json['postsVisibility'] as String?,
);

Map<String, dynamic> _$PostAuthorToJson(PostAuthor instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'displayName': instance.displayName,
      'username': instance.username,
      'avatar': instance.avatar,
      'isVerified': instance.isVerified,
      'isFollowing': instance.isFollowing,
      'postsVisibility': instance.postsVisibility,
    };

Post _$PostFromJson(Map<String, dynamic> json) => Post(
  id: json['id'] as String,
  author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
  content: json['content'] as String,
  mediaUrl: json['mediaUrl'] as String?,
  mediaList: (json['mediaList'] as List<dynamic>?)
      ?.map((e) => PostMedia.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags: (json['tags'] as List<dynamic>?)
      ?.map((e) => PostTag.fromJson(e as Map<String, dynamic>))
      .toList(),
  location: json['location'] as String?,
  mentionedUserIds: (json['mentionedUserIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  likes: (json['likes'] as num?)?.toInt() ?? 0,
  visibility: json['visibility'] as String? ?? 'everyone',
  comments: (json['comments'] as num?)?.toInt() ?? 0,
  tips: (json['tips'] as num?)?.toDouble() ?? 0,
  timestamp: json['timestamp'] as String,
  isNFT: json['isNFT'] as bool? ?? false,
  isLiked: json['isLiked'] as bool? ?? false,
  userReaction: json['userReaction'] as String?,
  reactionCounts:
      (json['reactionCounts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  totalReactions: (json['totalReactions'] as num?)?.toInt() ?? 0,
  commentList: (json['commentList'] as List<dynamic>?)
      ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
      .toList(),
  humanCertified: json['humanCertified'] as bool? ?? false,
  aiScore: (json['aiScore'] as num?)?.toDouble(),
  aiScoreStatus: json['aiScoreStatus'] as String?,
  authenticityNotes: json['authenticityNotes'] as String?,
  verificationMethod: json['verificationMethod'] as String?,
  verificationSessionId: json['verificationSessionId'] as String?,
  aiConfidenceScore: (json['aiConfidenceScore'] as num?)?.toDouble(),
  detectionStatus: json['detectionStatus'] as String?,
  status: json['status'] as String? ?? 'published',
  reposter: json['reposter'] == null
      ? null
      : PostAuthor.fromJson(json['reposter'] as Map<String, dynamic>),
  repostedAt: json['repostedAt'] as String?,
  title: json['title'] as String?,
  bodyFormat: json['bodyFormat'] as String? ?? 'plain',
  reposts: (json['reposts'] as num?)?.toInt() ?? 0,
  views: (json['views'] as num?)?.toInt() ?? 0,
  shares: (json['shares'] as num?)?.toInt() ?? 0,
  publishFee: (json['publishFee'] as num?)?.toDouble() ?? 0,
  isSensitive: json['isSensitive'] as bool? ?? false,
  sensitiveReason: json['sensitiveReason'] as String?,
  scheduledAt: json['scheduledAt'] as String?,
  publishedAt: json['publishedAt'] as String?,
  editCount: (json['editCount'] as num?)?.toInt() ?? 0,
  lastEditedAt: json['lastEditedAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'id': instance.id,
  'author': instance.author.toJson(),
  'content': instance.content,
  'mediaUrl': instance.mediaUrl,
  'mediaList': instance.mediaList?.map((e) => e.toJson()).toList(),
  'tags': instance.tags?.map((e) => e.toJson()).toList(),
  'location': instance.location,
  'mentionedUserIds': instance.mentionedUserIds,
  'likes': instance.likes,
  'comments': instance.comments,
  'visibility': instance.visibility,
  'tips': instance.tips,
  'timestamp': instance.timestamp,
  'isNFT': instance.isNFT,
  'isLiked': instance.isLiked,
  'userReaction': instance.userReaction,
  'reactionCounts': instance.reactionCounts,
  'totalReactions': instance.totalReactions,
  'commentList': instance.commentList?.map((e) => e.toJson()).toList(),
  'title': instance.title,
  'bodyFormat': instance.bodyFormat,
  'reposts': instance.reposts,
  'views': instance.views,
  'shares': instance.shares,
  'publishFee': instance.publishFee,
  'isSensitive': instance.isSensitive,
  'sensitiveReason': instance.sensitiveReason,
  'scheduledAt': instance.scheduledAt,
  'publishedAt': instance.publishedAt,
  'editCount': instance.editCount,
  'lastEditedAt': instance.lastEditedAt,
  'updatedAt': instance.updatedAt,
  'humanCertified': instance.humanCertified,
  'aiScore': instance.aiScore,
  'aiScoreStatus': instance.aiScoreStatus,
  'authenticityNotes': instance.authenticityNotes,
  'verificationMethod': instance.verificationMethod,
  'verificationSessionId': instance.verificationSessionId,
  'aiConfidenceScore': instance.aiConfidenceScore,
  'detectionStatus': instance.detectionStatus,
  'status': instance.status,
  'reposter': instance.reposter?.toJson(),
  'repostedAt': instance.repostedAt,
};
