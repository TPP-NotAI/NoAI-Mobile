import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'message.dart';

part 'conversation.g.dart';

@JsonSerializable()
class Conversation {
  final String id;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_message_at')
  final DateTime lastMessageAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final Message? lastMessage;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<User> participants;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int unreadCount;

  Conversation({
    required this.id,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessage,
    this.participants = const [],
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  factory Conversation.fromSupabase(
    Map<String, dynamic> data, {
    List<User> participants = const [],
    Message? lastMessage,
    int unreadCount = 0,
  }) {
    return Conversation(
      id: data['id'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      lastMessageAt: data['last_message_at'] != null
          ? DateTime.parse(data['last_message_at'] as String)
          : DateTime.parse(data['created_at'] as String),
      participants: participants,
      lastMessage: lastMessage,
      unreadCount: unreadCount,
    );
  }

  User otherParticipant(String currentUserId) {
    if (participants.isEmpty) {
      // Fallback or throw if participants are not loaded
      return User(id: 'unknown', username: 'unknown', displayName: 'Unknown');
    }
    return participants.firstWhere(
      (u) => u.id != currentUserId,
      orElse: () => participants.first,
    );
  }

  Conversation copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    Message? lastMessage,
    List<User>? participants,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
