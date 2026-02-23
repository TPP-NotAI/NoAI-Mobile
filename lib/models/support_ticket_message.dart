class SupportTicketMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String message;
  final bool isStaff;
  final DateTime createdAt;

  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.message,
    required this.isStaff,
    required this.createdAt,
  });

  factory SupportTicketMessage.fromSupabase(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      message: (json['message'] as String? ?? '').trim(),
      isStaff: json['is_staff'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
