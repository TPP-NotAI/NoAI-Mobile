import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/support_ticket.dart';
import '../models/support_ticket_message.dart';
import '../services/supabase_service.dart';

class SupportTicketRepository {
  final _client = SupabaseService().client;

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
}
