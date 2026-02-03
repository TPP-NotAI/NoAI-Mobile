// GENERATED CODE - HAND WRITTEN FOR NOW (json_serializable stub)

part of 'story.dart';

Story _$StoryFromJson(Map<String, dynamic> json) => Story(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      caption: json['caption'] as String?,
      backgroundColor: json['background_color'] as String?,
      textOverlay: json['text_overlay'] as String?,
      textPosition: json['text_position'] as Map<String, dynamic>?,
      isViewed: json['isViewed'] as bool? ?? false,
    );

Map<String, dynamic> _$StoryToJson(Story instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'media_url': instance.mediaUrl,
      'media_type': instance.mediaType,
      'caption': instance.caption,
      'background_color': instance.backgroundColor,
      'text_overlay': instance.textOverlay,
      'text_position': instance.textPosition,
      'view_count': instance.viewCount,
      'expires_at': instance.expiresAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'author': instance.author.toJson(),
      'isViewed': instance.isViewed,
    };
