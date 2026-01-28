import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class MuteRepository {
  final SupabaseClient _client;

  MuteRepository(this._client);

  /// Check if a user is muted by the current user.
  Future<bool> isMuted(String muterId, String mutedUserId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.mutesTable)
          .select()
          .eq('muter_id', muterId)
          .eq('muted_id', mutedUserId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Mute a user.
  Future<bool> muteUser(String muterId, String mutedUserId) async {
    try {
      debugPrint('MuteRepository: Attempting to mute $mutedUserId by $muterId');
      // Using insert without created_at as Supabase handles it, and it's safer
      await _client.from(SupabaseConfig.mutesTable).insert({
        'muter_id': muterId,
        'muted_id': mutedUserId,
      });
      debugPrint('MuteRepository: Mute successful');
      return true;
    } catch (e) {
      debugPrint('MuteRepository: CRITICAL ERROR muting user - $e');
      return false;
    }
  }

  /// Unmute a user.
  Future<bool> unmuteUser(String muterId, String mutedUserId) async {
    try {
      debugPrint(
        'MuteRepository: Attempting to unmute $mutedUserId by $muterId',
      );
      await _client
          .from(SupabaseConfig.mutesTable)
          .delete()
          .eq('muter_id', muterId)
          .eq('muted_id', mutedUserId);
      debugPrint('MuteRepository: Unmute successful');
      return true;
    } catch (e) {
      debugPrint('MuteRepository: CRITICAL ERROR unmuting user - $e');
      return false;
    }
  }

  /// Get all user IDs muted by the current user.
  Future<List<String>> getMutedUserIds(String muterId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.mutesTable)
          .select('muted_id')
          .eq('muter_id', muterId);

      return (response as List)
          .map((row) => row['muted_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('MuteRepository: Error getting muted user IDs - $e');
      return [];
    }
  }
}
