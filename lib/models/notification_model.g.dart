// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      actorId: json['actor_id'] as String?,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'type': instance.type,
      'title': instance.title,
      'body': instance.body,
      'is_read': instance.isRead,
      'actor_id': instance.actorId,
      'post_id': instance.postId,
      'comment_id': instance.commentId,
      'created_at': instance.createdAt.toIso8601String(),
    };
