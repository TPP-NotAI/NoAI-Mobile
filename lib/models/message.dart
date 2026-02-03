import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  final String id;
  @JsonKey(name: 'thread_id')
  final String conversationId;
  @JsonKey(name: 'sender_id')
  final String senderId;
  @JsonKey(name: 'body')
  final String content;
  @JsonKey(name: 'media_url')
  final String? mediaUrl;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  @JsonKey(name: 'status')
  final String status;
  @JsonKey(name: 'is_edited')
  final bool isEdited;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'ai_score')
  final double? aiScore;
  @JsonKey(name: 'ai_score_status')
  final String? aiScoreStatus;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.replyToId,
    this.status = 'sent',
    this.isEdited = false,
    required this.createdAt,
    this.aiScore,
    this.aiScoreStatus,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  factory Message.fromSupabase(Map<String, dynamic> data) {
    return Message(
      id: data['id'] as String,
      conversationId: data['thread_id'] as String,
      senderId: data['sender_id'] as String,
      content: data['body'] as String,
      mediaUrl: data['media_url'] as String?,
      mediaType: data['media_type'] as String?,
      replyToId: data['reply_to_id'] as String?,
      status: data['status'] as String? ?? 'sent',
      isEdited: data['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(data['created_at'] as String),
      aiScore: (data['ai_score'] as num?)?.toDouble(),
      aiScoreStatus: data['ai_score_status'] as String?,
    );
  }

  /// Convenience getter: derives message type from media_type for UI compatibility.
  String get messageType => mediaType ?? 'text';

  /// Convenience getter: treat 'read' status as isRead for UI compatibility.
  bool get isRead => status == 'read';

  /// Convenience getter: reply content not stored separately in schema.
  String? get replyContent => null;

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
    String? status,
    bool? isEdited,
    DateTime? createdAt,
    double? aiScore,
    String? aiScoreStatus,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      replyToId: replyToId ?? this.replyToId,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      aiScore: aiScore ?? this.aiScore,
      aiScoreStatus: aiScoreStatus ?? this.aiScoreStatus,
    );
  }
}
