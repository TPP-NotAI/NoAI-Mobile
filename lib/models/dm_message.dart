class DmMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final double? aiScore;
  final String? aiScoreStatus;
  final String? status;
  final String? replyToId;

  DmMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.aiScore,
    this.aiScoreStatus,
    this.status,
    this.replyToId,
  });

  factory DmMessage.fromSupabase(Map<String, dynamic> data) {
    return DmMessage(
      id: data['id'] as String,
      threadId: data['thread_id'] as String,
      senderId: data['sender_id'] as String,
      body: data['body'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      aiScore: (data['ai_score'] as num?)?.toDouble(),
      aiScoreStatus: data['ai_score_status'] as String?,
      status: data['status'] as String?,
      replyToId: data['reply_to_id'] as String?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {'thread_id': threadId, 'sender_id': senderId, 'body': body};
  }

  DmMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? body,
    DateTime? createdAt,
    double? aiScore,
    String? aiScoreStatus,
    String? status,
    String? replyToId,
  }) {
    return DmMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      aiScore: aiScore ?? this.aiScore,
      aiScoreStatus: aiScoreStatus ?? this.aiScoreStatus,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
    );
  }
}
