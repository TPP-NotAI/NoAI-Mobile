import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of creating a Didit verification session.
class DiditSession {
  final String sessionId;
  final String sessionUrl;

  const DiditSession({required this.sessionId, required this.sessionUrl});
}

/// Possible verification decision statuses from Didit.
enum DiditDecisionStatus {
  approved,
  declined,
  inReview,
  abandoned,
  notStarted,
  inProgress,
  unknown,
}

/// Service to interact with the Didit KYC integration via Supabase Edge Functions.
///
/// Handles session creation by calling the 'didit' edge function.
class DiditService {
  static final DiditService _instance = DiditService._internal();
  factory DiditService() => _instance;
  DiditService._internal();

  final _supabase = Supabase.instance.client;

  /// Create a new Didit verification session via Edge Function.
  ///
  /// Returns a [DiditSession] with the session URL to redirect the user to.
  Future<DiditSession> createSession({
    required String userId,
    String? email,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'didit',
        body: {
          'action': 'create_session',
          'vendor_data': userId,
          if (email != null) 'email': email,
        },
      );

      final data = response.data;

      if (data == null || data['session_id'] == null || data['url'] == null) {
        throw Exception('Invalid response from Didit function: $data');
      }

      return DiditSession(
        sessionId: data['session_id'] as String,
        sessionUrl: data['url'] as String,
      );
    } catch (e) {
      debugPrint('DiditService: createSession error - $e');
      throw Exception('Failed to create Didit session: $e');
    }
  }
}
