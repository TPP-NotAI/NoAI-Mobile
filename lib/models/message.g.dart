// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  conversationId: json['thread_id'] as String,
  senderId: json['sender_id'] as String,
  content: json['body'] as String,
  mediaUrl: json['media_url'] as String?,
  mediaType: json['media_type'] as String?,
  replyToId: json['reply_to_id'] as String?,
  status: json['status'] as String? ?? 'sent',
  isEdited: json['is_edited'] as bool? ?? false,
  createdAt: DateTime.parse(json['created_at'] as String),
  aiScore: (json['ai_score'] as num?)?.toDouble(),
  aiScoreStatus: json['ai_score_status'] as String?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'thread_id': instance.conversationId,
  'sender_id': instance.senderId,
  'body': instance.content,
  'media_url': instance.mediaUrl,
  'media_type': instance.mediaType,
  'reply_to_id': instance.replyToId,
  'status': instance.status,
  'is_edited': instance.isEdited,
  'created_at': instance.createdAt.toIso8601String(),
  'ai_score': instance.aiScore,
  'ai_score_status': instance.aiScoreStatus,
};
