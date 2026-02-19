class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? requesterUsername;
  final String? requesterDisplayName;
  final String? latestMessage;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.assignedTo,
    this.updatedAt,
    this.resolvedAt,
    this.requesterUsername,
    this.requesterDisplayName,
    this.latestMessage,
  });

  factory SupportTicket.fromSupabase(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final messages = json['support_ticket_messages'] as List<dynamic>?;
    String? latestMessage;
    if (messages != null && messages.isNotEmpty) {
      final first = messages.first as Map<String, dynamic>;
      latestMessage = first['message'] as String?;
    }

    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      requesterUsername: profile?['username'] as String?,
      requesterDisplayName: profile?['display_name'] as String?,
      latestMessage: latestMessage,
    );
  }
}
