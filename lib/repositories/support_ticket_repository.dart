import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/support_ticket.dart';
import '../models/support_ticket_message.dart';
import '../services/supabase_service.dart';
import 'notification_repository.dart';

class SupportTicketRepository {
  final _client = SupabaseService().client;
  final NotificationRepository _notificationRepository = NotificationRepository();

  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final row = await _client
          .from(SupabaseConfig.adminUsersTable)
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      return row != null;
    } catch (e) {
      debugPrint('SupportTicketRepository: Failed admin check - $e');
      return false;
    }
  }

  Future<String?> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
    String? requesterName,
    String? requesterEmail,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final mappedCategory = _normalizeCategory(category);
      final mappedPriority = _normalizePriority(priority);

      final insertedTicket = await _client
          .from(SupabaseConfig.supportTicketsTable)
          .insert({
            'user_id': userId,
            'subject': subject.trim(),
            'category': mappedCategory,
            'priority': mappedPriority,
            'status': 'open',
          })
          .select('id')
          .single();

      final ticketId = insertedTicket['id'] as String;

      final headerLines = <String>[
        if (requesterName != null && requesterName.trim().isNotEmpty)
          'Name: ${requesterName.trim()}',
        if (requesterEmail != null && requesterEmail.trim().isNotEmpty)
          'Email: ${requesterEmail.trim()}',
      ];
      final enrichedMessage = headerLines.isEmpty
          ? message.trim()
          : [...headerLines, '', message.trim()].join('\n');

      await _client.from(SupabaseConfig.supportTicketMessagesTable).insert({
        'ticket_id': ticketId,
        'sender_id': userId,
        'message': enrichedMessage,
        'is_staff': false,
      });

      await _notifyAdminsOfSupportMessage(
        senderId: userId,
        subject: subject.trim(),
        messagePreview: message.trim(),
        isNewTicket: true,
      );

      return ticketId;
    } catch (e) {
      debugPrint('SupportTicketRepository: Failed to create ticket - $e');
      return null;
    }
  }

  Future<SupportTicket?> getLatestCurrentUserTicket() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final row = await _client
          .from(SupabaseConfig.supportTicketsTable)
          .select(
            '''
id,
user_id,
subject,
category,
priority,
status,
assigned_to,
created_at,
updated_at,
resolved_at,
profiles!support_tickets_user_id_fkey(username, display_name),
support_ticket_messages(message, created_at)
''',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return SupportTicket.fromSupabase(row);
    } catch (e) {
      debugPrint('SupportTicketRepository: Failed to fetch latest user ticket - $e');
      return null;
    }
  }

  Future<SupportTicket?> getCurrentUserTicketById(String ticketId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final row = await _client
          .from(SupabaseConfig.supportTicketsTable)
          .select(
            '''
id,
user_id,
subject,
category,
priority,
status,
assigned_to,
created_at,
updated_at,
resolved_at,
profiles!support_tickets_user_id_fkey(username, display_name),
support_ticket_messages(message, created_at)
''',
          )
          .eq('id', ticketId)
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return SupportTicket.fromSupabase(row);
    } catch (e) {
      debugPrint(
        'SupportTicketRepository: Failed to fetch current user ticket by id - $e',
      );
      return null;
    }
  }

  Stream<List<SupportTicketMessage>> subscribeToTicketMessages(String ticketId) {
    return _client
        .from(SupabaseConfig.supportTicketMessagesTable)
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map((e) => SupportTicketMessage.fromSupabase(e))
              .where((m) => m.message.isNotEmpty)
              .toList(),
        );
  }

  Future<bool> sendTicketMessage({
    required String ticketId,
    required String message,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
      final trimmed = message.trim();
      if (trimmed.isEmpty) return false;

      await _client.from(SupabaseConfig.supportTicketMessagesTable).insert({
        'ticket_id': ticketId,
        'sender_id': userId,
        'message': trimmed,
        'is_staff': false,
      });

      final ticketRow = await _client
          .from(SupabaseConfig.supportTicketsTable)
          .select('subject')
          .eq('id', ticketId)
          .maybeSingle();

      await _notifyAdminsOfSupportMessage(
        senderId: userId,
        subject: (ticketRow?['subject'] as String?)?.trim(),
        messagePreview: trimmed,
        isNewTicket: false,
      );

      return true;
    } catch (e) {
      debugPrint('SupportTicketRepository: Failed to send ticket message - $e');
      return false;
    }
  }

  Future<List<SupportTicket>> getAdminTickets({int limit = 100}) async {
    try {
      final response = await _client
          .from(SupabaseConfig.supportTicketsTable)
          .select(
            '''
id,
user_id,
subject,
category,
priority,
status,
assigned_to,
created_at,
updated_at,
resolved_at,
profiles!support_tickets_user_id_fkey(username, display_name),
support_ticket_messages(message, created_at)
''',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = response as List<dynamic>;
      return rows
          .map((e) => SupportTicket.fromSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupportTicketRepository: Failed to fetch admin tickets - $e');
      return [];
    }
  }

  String _normalizeCategory(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'account':
        return 'account';
      case 'moderation':
      case 'report':
      case 'content':
        return 'content';
      case 'roocoin':
      case 'wallet':
        return 'wallet';
      case 'technical':
        return 'technical';
      case 'verification':
        return 'verification';
      default:
        return 'other';
    }
  }

  String _normalizePriority(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'low':
        return 'low';
      case 'high':
        return 'high';
      case 'urgent':
        return 'urgent';
      case 'normal':
      case 'medium':
      default:
        return 'medium';
    }
  }

  Future<void> _notifyAdminsOfSupportMessage({
    required String senderId,
    String? subject,
    required String messagePreview,
    required bool isNewTicket,
  }) async {
    try {
      final adminRows = await _client
          .from(SupabaseConfig.adminUsersTable)
          .select('user_id');
      final adminIds = (adminRows as List<dynamic>)
          .map((e) => e['user_id'] as String?)
          .whereType<String>()
          .where((id) => id != senderId)
          .toSet();
      if (adminIds.isEmpty) return;

      final senderProfile = await _client
          .from(SupabaseConfig.profilesTable)
          .select('username, display_name')
          .eq('user_id', senderId)
          .maybeSingle();
      final senderName =
          (senderProfile?['display_name'] as String?)?.trim().isNotEmpty == true
          ? (senderProfile!['display_name'] as String).trim()
          : ((senderProfile?['username'] as String?) ?? 'User');

      final safePreview = messagePreview.length > 140
          ? '${messagePreview.substring(0, 140)}...'
          : messagePreview;
      final title = isNewTicket ? 'New Support Ticket' : 'Support Chat Message';
      final ticketLabel =
          (subject != null && subject.isNotEmpty) ? subject : 'Support request';
      final body = isNewTicket
          ? '$senderName opened "$ticketLabel": $safePreview'
          : '$senderName replied in "$ticketLabel": $safePreview';

      for (final adminId in adminIds) {
        await _notificationRepository.createNotification(
          userId: adminId,
          type: 'support_chat',
          title: title,
          body: body,
          actorId: null,
        );
      }
    } catch (e) {
      debugPrint(
        'SupportTicketRepository: Failed to create support chat notifications - $e',
      );
    }
  }
}
