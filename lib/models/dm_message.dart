class DmMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  DmMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory DmMessage.fromSupabase(Map<String, dynamic> data) {
    return DmMessage(
      id: data['id'] as String,
      threadId: data['thread_id'] as String,
      senderId: data['sender_id'] as String,
      body: data['body'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'thread_id': threadId,
      'sender_id': senderId,
      'body': body,
    };
  }

  DmMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? body,
    DateTime? createdAt,
  }) {
    return DmMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
