import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Best-effort app activity logging.
/// Logging failures are swallowed so user-facing actions keep working.
class ActivityLogService {
  ActivityLogService();

  final _client = SupabaseService().client;

  Future<void> log({
    String? userId,
    required String activityType,
    String? targetType,
    String? targetId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final effectiveUserId = userId ?? _client.auth.currentUser?.id;
    if (effectiveUserId == null || effectiveUserId.isEmpty) return;

    try {
      await _client.from(SupabaseConfig.userActivitiesTable).insert({
        'user_id': effectiveUserId,
        'activity_type': activityType,
        if (targetType != null) 'target_type': targetType,
        if (targetId != null) 'target_id': targetId,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'metadata': metadata ?? <String, dynamic>{},
      });
    } catch (e) {
      debugPrint(
        'ActivityLogService: Failed to log activity '
        'type=$activityType user=$effectiveUserId target=$targetType/$targetId - $e',
      );
    }
  }
}
