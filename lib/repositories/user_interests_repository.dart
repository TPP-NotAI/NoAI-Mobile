import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

/// Repository for managing user interests/topics.
class UserInterestsRepository {
  final _client = SupabaseService().client;
  final _storage = StorageService();
  static const String _storageKey = 'user_interests';

  /// Save user interests to Supabase and local storage.
  Future<bool> saveUserInterests(List<String> interests) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        // If not logged in, just save locally
        await _storage.setStringList(_storageKey, interests);
        return true;
      }

      // Save to Supabase profiles table (as JSON array)
      await _client.from(SupabaseConfig.profilesTable).update({
        'interests': interests,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Also save locally as backup
      await _storage.setStringList(_storageKey, interests);

      debugPrint(
        'UserInterestsRepository: Saved ${interests.length} interests for user $userId',
      );
      return true;
    } catch (e) {
      debugPrint('UserInterestsRepository: Error saving interests - $e');
      // Try to save locally as fallback
      try {
        await _storage.setStringList(_storageKey, interests);
        return true;
      } catch (storageError) {
        debugPrint(
          'UserInterestsRepository: Error saving to local storage - $storageError',
        );
        return false;
      }
    }
  }

  /// Get user interests from Supabase or local storage.
  Future<List<String>?> getUserInterests() async {
    try {
      final userId = SupabaseService().currentUser?.id;

      // Try Supabase first if logged in
      if (userId != null) {
        final response = await _client
            .from(SupabaseConfig.profilesTable)
            .select('interests')
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null && response['interests'] != null) {
          final interests = (response['interests'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (interests.isNotEmpty) {
            // Update local storage
            await _storage.setStringList(_storageKey, interests);
            return interests;
          }
        }
      }

      // Fallback to local storage
      final localInterests = _storage.getStringList(_storageKey);
      if (localInterests != null && localInterests.isNotEmpty) {
        return localInterests;
      }

      return null;
    } catch (e) {
      debugPrint('UserInterestsRepository: Error getting interests - $e');
      // Fallback to local storage
      try {
        return _storage.getStringList(_storageKey);
      } catch (storageError) {
        debugPrint(
          'UserInterestsRepository: Error reading from local storage - $storageError',
        );
        return null;
      }
    }
  }

  /// Clear user interests.
  Future<bool> clearUserInterests() async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId != null) {
        await _client.from(SupabaseConfig.profilesTable).update({
          'interests': <String>[],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
      }
      await _storage.remove(_storageKey);
      return true;
    } catch (e) {
      debugPrint('UserInterestsRepository: Error clearing interests - $e');
      return false;
    }
  }
}

