import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/conversation.dart';
import '../../models/user.dart';
import '../chat/conversation_thread_page.dart';
import '../../services/supabase_service.dart';
import '../../config/supabase_config.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  bool _isInitializing = true;
  String? _errorMessage;
  Conversation? _supportConversation;

  @override
  void initState() {
    super.initState();
    _initializeSupportChat();
  }

  Future<void> _initializeSupportChat() async {
    try {
      final chatProvider = context.read<ChatProvider>();

      // 1. Find Support User
      // For now, we search for a user with the username 'support' or 'noai_support'
      // If not found in cache, we'll try to fetch it.

      // Attempting to find a support user by username
      // This is a bit of a hack since we don't have a specific ID yet

      // Let's try to query the support user specifically
      // In a real app, this ID would be a constant or fetched from a config

      // For demonstration, let's assume we can try to find a user named 'support'
      // If we can't find one, we'll show an error or use a placeholder for development

      // Let's search for 'support' username
      final supportUser = await _findSupportUser();

      if (supportUser == null) {
        setState(() {
          _errorMessage =
              'Support team is currently unavailable. Please try again later.';
          _isInitializing = false;
        });
        return;
      }

      // 2. Start/Get Conversation
      final conversation = await chatProvider.startConversation(supportUser.id);

      if (conversation == null) {
        setState(() {
          _errorMessage = 'Failed to start a support chat session.';
          _isInitializing = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _supportConversation = conversation;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<User?> _findSupportUser() async {
    final userProvider = context.read<UserProvider>();

    // 1. Try local list first
    try {
      return userProvider.users.firstWhere(
        (u) => u.username.toLowerCase().contains('support'),
      );
    } catch (_) {}

    // 2. Query Supabase for 'support' account
    try {
      final supabase = SupabaseService().client;
      final response = await supabase
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .ilike('username', '%support%')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return User.fromSupabase(
          response,
          wallet: response[SupabaseConfig.walletsTable],
        );
      }

      // 3. Fallback: try 'admin'
      final adminResponse = await supabase
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .ilike('username', '%admin%')
          .limit(1)
          .maybeSingle();

      if (adminResponse != null) {
        return User.fromSupabase(
          adminResponse,
          wallet: adminResponse[SupabaseConfig.walletsTable],
        );
      }

      // 4. For development: If no support/admin exists, pick ANY other user to simulate support
      // This is helpful if the developer hasn't created a support account yet.
      final anyResponse = await supabase
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .neq('user_id', supabase.auth.currentUser?.id ?? '')
          .limit(1)
          .maybeSingle();

      if (anyResponse != null) {
        return User.fromSupabase(
          anyResponse,
          wallet: anyResponse[SupabaseConfig.walletsTable],
        );
      }
    } catch (e) {
      debugPrint('Error finding support user: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Support...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _errorMessage = null;
                    });
                    _initializeSupportChat();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_supportConversation != null) {
      return ConversationThreadPage(conversation: _supportConversation!);
    }

    return const Scaffold(body: Center(child: Text('Something went wrong.')));
  }
}
