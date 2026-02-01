import 'user.dart';
import 'dm_message.dart';

class DmThread {
  final String id;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final List<User> participants;
  final DmMessage? lastMessage;
  final int unreadCount;

  DmThread({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    this.lastMessageAt,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory DmThread.fromSupabase(
    Map<String, dynamic> data, {
    List<User> participants = const [],
    DmMessage? lastMessage,
    int unreadCount = 0,
  }) {
    return DmThread(
      id: data['id'] as String,
      createdBy: data['created_by'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      lastMessageAt: data['last_message_at'] != null
          ? DateTime.parse(data['last_message_at'] as String)
          : null,
      participants: participants,
      lastMessage: lastMessage,
      unreadCount: unreadCount,
    );
  }

  User otherParticipant(String currentUserId) {
    if (participants.isEmpty) {
      return User(id: 'unknown', username: 'unknown', displayName: 'Unknown');
    }
    return participants.firstWhere(
      (u) => u.id != currentUserId,
      orElse: () => participants.first,
    );
  }

  DmThread copyWith({
    String? id,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<User>? participants,
    DmMessage? lastMessage,
    int? unreadCount,
  }) {
    return DmThread(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
