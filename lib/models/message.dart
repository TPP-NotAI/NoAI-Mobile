import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  final String id;
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'sender_id')
  final String senderId;
  final String content;
  @JsonKey(name: 'message_type')
  final String messageType;
  @JsonKey(name: 'media_url')
  final String? mediaUrl;
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  @JsonKey(name: 'reply_content')
  final String? replyContent;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'is_read')
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.replyToId,
    this.replyContent,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  factory Message.fromSupabase(Map<String, dynamic> data) {
    return Message(
      id: data['id'] as String,
      conversationId: data['conversation_id'] as String,
      senderId: data['sender_id'] as String,
      content: data['content'] as String,
      messageType: data['message_type'] as String? ?? 'text',
      mediaUrl: data['media_url'] as String?,
      replyToId: data['reply_to_id'] as String?,
      replyContent: data['reply_content'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      isRead: data['is_read'] as bool? ?? false,
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? messageType,
    String? mediaUrl,
    String? replyToId,
    String? replyContent,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      replyToId: replyToId ?? this.replyToId,
      replyContent: replyContent ?? this.replyContent,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
