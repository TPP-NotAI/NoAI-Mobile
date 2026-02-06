// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Story _$StoryFromJson(Map<String, dynamic> json) => Story(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mediaUrl: json['mediaUrl'] as String,
  mediaType: json['mediaType'] as String,
  viewCount: (json['viewCount'] as num).toInt(),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  author: User.fromJson(json['author'] as Map<String, dynamic>),
  caption: json['caption'] as String?,
  backgroundColor: json['backgroundColor'] as String?,
  textOverlay: json['textOverlay'] as String?,
  textPosition: json['textPosition'] as Map<String, dynamic>?,
  isViewed: json['isViewed'] as bool? ?? false,
  aiScore: (json['aiScore'] as num?)?.toDouble(),
  status: json['status'] as String?,
  likes: (json['likes'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
);

Map<String, dynamic> _$StoryToJson(Story instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mediaUrl': instance.mediaUrl,
  'mediaType': instance.mediaType,
  'caption': instance.caption,
  'backgroundColor': instance.backgroundColor,
  'textOverlay': instance.textOverlay,
  'textPosition': instance.textPosition,
  'viewCount': instance.viewCount,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'author': instance.author,
  'isViewed': instance.isViewed,
  'aiScore': instance.aiScore,
  'status': instance.status,
  'likes': instance.likes,
  'isLiked': instance.isLiked,
};
