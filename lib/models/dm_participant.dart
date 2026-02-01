class DmParticipant {
  final String threadId;
  final String userId;
  final DateTime joinedAt;
  final bool muted;

  DmParticipant({
    required this.threadId,
    required this.userId,
    required this.joinedAt,
    this.muted = false,
  });

  factory DmParticipant.fromSupabase(Map<String, dynamic> data) {
    return DmParticipant(
      threadId: data['thread_id'] as String,
      userId: data['user_id'] as String,
      joinedAt: DateTime.parse(data['joined_at'] as String),
      muted: data['muted'] as bool? ?? false,
    );
  }

  DmParticipant copyWith({
    String? threadId,
    String? userId,
    DateTime? joinedAt,
    bool? muted,
  }) {
    return DmParticipant(
      threadId: threadId ?? this.threadId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      muted: muted ?? this.muted,
    );
  }
}
