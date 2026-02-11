import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of creating a Veriff verification session.
class VeriffSession {
  final String sessionId;
  final String sessionUrl;

  const VeriffSession({required this.sessionId, required this.sessionUrl});
}

/// Possible verification decision statuses from Veriff.
enum VeriffDecisionStatus {
  approved,
  declined,
  resubmissionRequested,
  expired,
  abandoned,
  unknown,
}

/// Result of querying a Veriff session decision.
class VeriffDecision {
  final VeriffDecisionStatus status;
  final String? reasonCode;
  final String? reasonMessage;

  const VeriffDecision({
    required this.status,
    this.reasonCode,
    this.reasonMessage,
  });
}

/// Service to interact with the Veriff integration via Supabase Edge Functions.
///
/// Handles session creation by calling the 'veriff' function.
class VeriffService {
  static final VeriffService _instance = VeriffService._internal();
  factory VeriffService() => _instance;
  VeriffService._internal();

  final _supabase = Supabase.instance.client;

  /// Create a new Veriff verification session via Edge Function.
  ///
  /// Returns a [VeriffSession] with the session URL to redirect the user to.
  Future<VeriffSession> createSession({
    required String userId,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'Veriff',
        body: {
          'action': 'create_session',
          'firstName': firstName,
          'lastName': lastName,
        },
      );

      final data = response.data;

      if (data == null || data['verification'] == null) {
        throw Exception('Invalid response from Veriff function: $data');
      }

      final verification = data['verification'];

      return VeriffSession(
        sessionId: verification['id'] as String,
        sessionUrl: verification['url'] as String,
      );
    } catch (e) {
      debugPrint('VeriffService: createSession error - $e');
      throw Exception('Failed to create Veriff session: $e');
    }
  }

  /// Poll the decision endpoint.
  ///
  /// Note: With Webhooks, the DB updates automatically.
  /// This method is now legacy or can be used if we still want to poll via function
  /// (if we added a 'get_decision' action to the function).
  ///
  /// For now, we'll return UNKNOWN to force the UI to rely on DB updates or manual check.
  Future<VeriffDecision> getDecision(String sessionId) async {
    // In the new architecture, the specific decision details come via webhook to DB.
    // The UI should listen to the user profile changes.
    // Keeping this method signature to avoid breaking existing calls immediately,
    // but returning unknown.
    return const VeriffDecision(status: VeriffDecisionStatus.unknown);
  }

  /// Legacy polling method - allows UI to maintain same structure but effectively no-ops
  Future<VeriffDecision> pollDecision(
    String sessionId, {
    int maxRetries = 10,
    Duration delayBetweenRetries = const Duration(seconds: 3),
  }) async {
    return const VeriffDecision(status: VeriffDecisionStatus.unknown);
  }
}
