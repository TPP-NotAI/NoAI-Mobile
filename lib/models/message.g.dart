// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  conversationId: json['conversation_id'] as String,
  senderId: json['sender_id'] as String,
  content: json['content'] as String,
  messageType: json['message_type'] as String? ?? 'text',
  mediaUrl: json['media_url'] as String?,
  replyToId: json['reply_to_id'] as String?,
  replyContent: json['reply_content'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  isRead: json['is_read'] as bool? ?? false,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'conversation_id': instance.conversationId,
  'sender_id': instance.senderId,
  'content': instance.content,
  'message_type': instance.messageType,
  'media_url': instance.mediaUrl,
  'reply_to_id': instance.replyToId,
  'reply_content': instance.replyContent,
  'created_at': instance.createdAt.toIso8601String(),
  'is_read': instance.isRead,
};
