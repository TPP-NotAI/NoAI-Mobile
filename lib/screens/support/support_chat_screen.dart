import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/support_ticket.dart';
import '../../models/support_ticket_message.dart';
import '../../repositories/support_ticket_repository.dart';
import '../../services/supabase_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final SupportTicketRepository _repository = SupportTicketRepository();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<SupportTicketMessage>>? _messagesSub;
  SupportTicket? _ticket;
  List<SupportTicketMessage> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = await _repository.getLatestCurrentUserTicket();
      if (!mounted) return;

      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });

      if (ticket != null) {
        _subscribeToMessages(ticket.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to open support chat: $e';
      });
    }
  }

  void _subscribeToMessages(String ticketId) {
    _messagesSub?.cancel();
    _messagesSub = _repository.subscribeToTicketMessages(ticketId).listen(
      (messages) {
        if (!mounted) return;
        setState(() => _messages = messages);
        _scrollToBottom();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to load support messages.';
        });
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      var ticket = _ticket;

      if (ticket == null) {
        final ticketId = await _repository.createTicket(
          subject: 'Support Chat',
          category: 'general',
          priority: 'normal',
          message: text,
        );

        if (ticketId == null) {
          throw Exception('Could not start support chat');
        }

        ticket = await _repository.getLatestCurrentUserTicket();
        if (ticket == null) {
          throw Exception('Support chat started, but ticket could not be loaded');
        }

        if (!mounted) return;
        setState(() => _ticket = ticket);
        _subscribeToMessages(ticket.id);
      } else {
        final ok = await _repository.sendTicketMessage(
          ticketId: ticket.id,
          message: text,
        );
        if (!ok) {
          throw Exception('Failed to send message');
        }
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isCurrentUserMessage(SupportTicketMessage message) {
    final userId = SupabaseService().client.auth.currentUser?.id;
    return message.senderId == userId;
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Support Chat'),
            if (_ticket != null)
              Text(
                _ticket!.subject,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _initialize,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _ticket == null
                        ? 'Start a support chat. Your messages here will go to the same support ticket channel the admin team uses.'
                        : 'No messages yet. Send a message to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMine = _isCurrentUserMessage(msg);
                  final bubbleColor = isMine
                      ? scheme.primary
                      : msg.isStaff
                      ? scheme.secondaryContainer
                      : scheme.surfaceVariant;
                  final textColor = isMine
                      ? scheme.onPrimary
                      : msg.isStaff
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant;

                  return Align(
                    alignment:
                        isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine && msg.isStaff)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Support',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textColor.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            Text(msg.message, style: TextStyle(color: textColor)),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(msg.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type your support message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: FilledButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
