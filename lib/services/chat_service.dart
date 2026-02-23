import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'supabase_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/ai_detection_result.dart';
import '../config/supabase_config.dart';
import 'ai_detection_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _supabase = SupabaseService().client;
  final _aiService = AiDetectionService();
  static const Set<String> _imageMediaTypes = {'image'};
  static const Set<String> _videoMediaTypes = {'video'};
  static const Set<String> _aiScannableMediaTypes = {'image', 'video'};
  static const double _aiReviewThreshold = 50;
  static const double _aiFlagThreshold = 75;
  static const Duration _signedUrlTtl = Duration(hours: 6);
  static const Duration _sharedUploadSignedUrlTtl = Duration(days: 7);
  final Map<String, _SignedUrlCacheEntry> _signedUrlCache = {};

  /// Fetch all conversations for the current user.
  Future<List<Conversation>> getConversations({
    bool showArchived = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get thread IDs where the user is a participant
    List<dynamic> participantsResponse = [];
    try {
      var query = _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', userId);

      if (showArchived) {
        query = query.eq('is_archived', true);
      } else {
        query = query.or('is_archived.eq.false,is_archived.is.null');
      }

      participantsResponse = await query;
    } catch (e) {
      debugPrint('Archived filter failed, falling back: $e');
      final fallbackQuery = await _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', userId);
      participantsResponse = fallbackQuery as List;
      if (showArchived) return [];
    }

    final threadIds = participantsResponse
        .map((p) => p['thread_id'] as String)
        .toList();

    if (threadIds.isEmpty) return [];

    // Get thread details and other participants, filtering by left_at if needed
    // We only show conversations where the last_message_at is after the participant's left_at (or left_at is null)
    final threadsResponse = await _supabase
        .from('dm_threads')
        .select('''
          *,
          dm_participants!inner(
            user_id,
            left_at,
            profiles:user_id(*)
          )
        ''')
        .inFilter('id', threadIds)
        .order('last_message_at', ascending: false);

    final List<Conversation> conversations = [];

    for (var data in threadsResponse as List) {
      final threadId = data['id'];

      // Fetch last message (not flagged, and only show under_review if user sent it)
      final lastMessagesResponse = await _supabase
          .from('dm_messages')
          .select()
          .eq('thread_id', threadId)
          .neq('ai_score_status', 'flagged')
          .order('created_at', ascending: false)
          .limit(5);

      final lastMessages = (lastMessagesResponse as List)
          .map((m) => Message.fromSupabase(m))
          .toList();

      final lastMessage = lastMessages.isEmpty
          ? null
          : lastMessages.cast<Message?>().firstWhere(
              (m) =>
                  m != null &&
                  (m.aiScoreStatus != 'review' || m.senderId == userId),
              orElse: () => null,
            );

      if (lastMessage == null) {
        // Skip empty conversations as requested
        continue;
      }

      // Get unread count from dm_participants
      final participantData = await _supabase
          .from('dm_participants')
          .select('unread_count')
          .eq('thread_id', threadId)
          .eq('user_id', userId)
          .maybeSingle();

      final unreadCount = participantData?['unread_count'] as int? ?? 0;

      final participantsData = data['dm_participants'] as List;
      final myParticipant = participantsData.firstWhere(
        (p) => p['user_id'] == userId,
      );
      final leftAtStr = myParticipant['left_at'] as String?;

      if (leftAtStr != null) {
        final leftAt = DateTime.parse(leftAtStr);
        if (lastMessage.createdAt.isBefore(leftAt)) {
          // Hide thread if last message is older than when user "deleted" it
          continue;
        }
      }

      final participants = participantsData.map((p) {
        return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
      }).toList();

      conversations.add(
        Conversation.fromSupabase(
          data,
          participants: participants,
          lastMessage: lastMessage,
          unreadCount: unreadCount,
        ),
      );
    }

    return conversations;
  }

  /// Archive a conversation for the current user.
  Future<void> archiveConversation(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('dm_participants')
          .update({'is_archived': true})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Archive failed: $e');
    }
  }

  /// Unarchive a conversation for the current user.
  Future<void> unarchiveConversation(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('dm_participants')
          .update({'is_archived': false})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Unarchive failed: $e');
    }
  }

  /// Delete a conversation for the current user (sets left_at timestamp).
  Future<void> deleteConversationForUser(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('dm_participants')
        .update({'left_at': DateTime.now().toIso8601String()})
        .eq('thread_id', threadId)
        .eq('user_id', userId);
  }

  /// Get or create a conversation with another user.
  /// Respects privacy settings: checks if the target user allows messages from the current user.
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // 1. Check if a 1:1 thread already exists.
    // Existing chats remain accessible even if follow/visibility changes later.
    final myThreads = await _supabase
        .from('dm_participants')
        .select('thread_id')
        .eq('user_id', currentUserId);

    final myThreadIds = (myThreads as List).map((c) => c['thread_id']).toList();

    if (myThreadIds.isNotEmpty) {
      final commonThreads = await _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', otherUserId)
          .inFilter('thread_id', myThreadIds);

      if ((commonThreads as List).isNotEmpty) {
        final threadId = commonThreads.first['thread_id'];

        final threadData = await _supabase
            .from('dm_threads')
            .select('''
              *,
              dm_participants!inner(
                user_id,
                profiles:user_id(*)
              )
            ''')
            .eq('id', threadId)
            .single();

        final participants = (threadData['dm_participants'] as List).map((p) {
          return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
        }).toList();

        return Conversation.fromSupabase(
          threadData,
          participants: participants,
        );
      }
    }

    // 2. Creating a new chat is allowed only if current user follows target user.
    final followResponse = await _supabase
        .from('follows')
        .select('follower_id')
        .eq('follower_id', currentUserId)
        .eq('following_id', otherUserId)
        .maybeSingle();

    if (followResponse == null) {
      throw Exception('You can only start chats with users you follow.');
    }

    // 3. Check privacy settings for new conversation creation.
    final otherUserResponse = await _supabase
        .from('profiles')
        .select()
        .eq('user_id', otherUserId)
        .single();

    final otherUser = User.fromSupabase(otherUserResponse);
    final visibility = otherUser.messagesVisibility ?? 'everyone';

    if (visibility == 'private') {
      throw Exception('This user does not accept messages.');
    }

    // 4. Create new thread
    final newThread = await _supabase
        .from('dm_threads')
        .insert({'created_by': currentUserId})
        .select()
        .single();

    final threadId = newThread['id'];

    // Add participants
    await _supabase.from('dm_participants').insert([
      {'thread_id': threadId, 'user_id': currentUserId},
      {'thread_id': threadId, 'user_id': otherUserId},
    ]);

    final currentUserResponse = await _supabase
        .from('profiles')
        .select()
        .eq('user_id', currentUserId)
        .single();
    final currentUser = User.fromSupabase(currentUserResponse);

    return Conversation.fromSupabase(
      newThread,
      participants: [currentUser, otherUser],
    );
  }

  /// Fetch messages for a conversation.
  Future<List<Message>> getMessages(String threadId, {int limit = 50}) async {
    final response = await _supabase
        .from('dm_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(limit);

    final messages = (response as List).map((m) => Message.fromSupabase(m));
    return Future.wait(messages.map(_hydrateMessageMediaUrl));
  }

  /// Send a message.
  Future<Message> sendMessage(
    String threadId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? localMediaPath,
    String? replyToId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final precheck = await _runAiDetectionPreSend(
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      localMediaPath: localMediaPath,
    );

    if (precheck == null) {
      throw Exception(
        'Message blocked: AI verification did not complete. Please try again.',
      );
    }

    if (precheck != null && precheck.aiScoreStatus == 'flagged') {
      throw Exception(
        'Message blocked: content detected as likely AI-generated.',
      );
    }

    final insertData = <String, dynamic>{
      'thread_id': threadId,
      'sender_id': userId,
      'body': content,
    };

    if (mediaUrl != null) insertData['media_url'] = mediaUrl;
    if (mediaType != null) insertData['media_type'] = mediaType;
    if (replyToId != null) insertData['reply_to_id'] = replyToId;
    insertData['ai_score'] = precheck.aiScore;
    insertData['ai_score_status'] = precheck.aiScoreStatus;
    insertData['ai_metadata'] = precheck.aiMetadata;
    insertData['verification_session_id'] = precheck.analysisId;

    final response = await _supabase
        .from('dm_messages')
        .insert(insertData)
        .select()
        .single();

    final previewContent = Message.stripStoryReferenceFromContent(content);

    // Update thread's last_message_at and preview
    await _supabase
        .from('dm_threads')
        .update({
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_preview': previewContent.length > 100
              ? '${previewContent.substring(0, 100)}...'
              : previewContent,
        })
        .eq('id', threadId);

    final message = Message.fromSupabase(response);

    await _createModerationCaseIfNeeded(
      messageId: message.id,
      senderId: message.senderId,
      aiScore: precheck.aiScore,
      aiMetadata: precheck.aiMetadata,
      rationale: precheck.rationale,
      combinedEvidence: precheck.combinedEvidence,
    );

    return message;
  }

  /// Run AI detection on a message.
  Future<void> runAiDetection(Message message) async {
    try {
      final textContent = message.displayContent;
      final hasText = textContent.isNotEmpty && textContent != '[Media]';
      final mediaType = message.mediaType?.toLowerCase();
      final hasMedia = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;
      final canScanMedia =
          hasMedia && _aiScannableMediaTypes.contains(mediaType);

      if (!hasText && !hasMedia) return;

      AiDetectionResult? result;
      File? mediaFile;
      try {
        if (canScanMedia) {
          mediaFile = await _downloadMedia(
            message.mediaUrl!,
            mediaType: mediaType,
          );
          if (mediaFile == null && !hasText) return;
        }
        final detectionModels = canScanMedia ? 'gpt-4.1' : 'gpt-5.2,o3';
        result = await _aiService.detectFull(
          content: hasText ? textContent : null,
          file: mediaFile,
          models: detectionModels,
        );
      } finally {
        if (mediaFile != null) {
          _cleanupFile(mediaFile);
        }
      }

      if (result == null) return;

      final normalizedResult = result.result.trim().toUpperCase();
      final isAiResult =
          normalizedResult == 'AI-GENERATED' ||
          normalizedResult == 'LIKELY AI-GENERATED';
      final labelConfidence = result.confidence.clamp(0, 100);
      final aiProbability = isAiResult
          ? labelConfidence
          : 100 - labelConfidence;
      final status = _resolveAiScoreStatus(aiProbability.toDouble());
      final aiMetadata = _buildAiMetadata(result);

      // Update message in DB
      try {
        await _supabase
            .from('dm_messages')
            .update({
              'ai_score': aiProbability,
              'ai_score_status': status,
              'ai_metadata': aiMetadata,
              'verification_session_id': result.analysisId,
            })
            .eq('id', message.id);
      } catch (e) {
        debugPrint('ChatService: Failed to update AI fields in DB - $e');
      }

      await _createModerationCaseIfNeeded(
        messageId: message.id,
        senderId: message.senderId,
        aiScore: aiProbability.toDouble(),
        aiMetadata: aiMetadata,
        rationale: result.rationale,
        combinedEvidence: result.combinedEvidence,
      );
    } catch (e) {
      debugPrint('ChatService: Error in runAiDetection - $e');
    }
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('dm_messages').delete().eq('id', messageId);
  }

  /// Delete an entire conversation.
  Future<void> deleteConversation(String threadId) async {
    await _supabase.from('dm_threads').delete().eq('id', threadId);
  }

  /// Upload media to Supabase Storage.
  Future<String?> uploadMedia(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final rawExtension = fileName.contains('.')
          ? fileName.split('.').last
          : filePath.split('.').last;
      final extension = rawExtension.toLowerCase();
      final mediaCategory = _resolveMediaCategory(extension);
      final mimeType = _resolveContentType(extension, mediaCategory);
      final path =
          '$userId/$mediaCategory/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from(SupabaseConfig.chatMediaBucket)
          .upload(path, file, fileOptions: FileOptions(contentType: mimeType));

      // Prefer storing a signed URL so recipients can render the attachment
      // even when storage policies prevent them from generating signed URLs.
      try {
        return await _supabase.storage
            .from(SupabaseConfig.chatMediaBucket)
            .createSignedUrl(path, _sharedUploadSignedUrlTtl.inSeconds);
      } catch (e) {
        debugPrint('ChatService: createSignedUrl after upload failed - $e');
        return _supabase.storage
            .from(SupabaseConfig.chatMediaBucket)
            .getPublicUrl(path);
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  // Cache left_at per thread so we don't query DB on every realtime event
  final Map<String, DateTime?> _leftAtCache = {};

  Stream<List<Message>> subscribeToMessages(String threadId) {
    final currentUserId = _supabase.auth.currentUser?.id;

    // Eagerly fetch left_at once, then use the cache for subsequent events
    Future<void> _primeLeftAt() async {
      if (_leftAtCache.containsKey(threadId)) return;
      try {
        final participant = await _supabase
            .from('dm_participants')
            .select('left_at')
            .eq('thread_id', threadId)
            .eq('user_id', currentUserId ?? '')
            .maybeSingle();
        final leftAtStr = participant?['left_at'] as String?;
        _leftAtCache[threadId] = leftAtStr != null
            ? DateTime.parse(leftAtStr)
            : null;
      } catch (_) {
        _leftAtCache[threadId] = null;
      }
    }

    return _supabase
        .from('dm_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          await _primeLeftAt();
          final leftAt = _leftAtCache[threadId];
          final baseMessages = data
              .map((m) => Message.fromSupabase(m))
              .toList();
          final allMessages = await Future.wait(
            baseMessages.map(_hydrateMessageMediaUrl),
          );
          return allMessages.where((m) {
            if (leftAt != null && m.createdAt.isBefore(leftAt)) return false;
            if (m.aiScoreStatus == 'flagged') return false;
            final isMine = m.senderId == currentUserId;
            if (!isMine && m.aiScoreStatus == 'review') return false;
            return true;
          }).toList();
        });
  }

  Future<_AiPrecheckResult?> _runAiDetectionPreSend({
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? localMediaPath,
  }) async {
    try {
      final textContent = Message.stripStoryReferenceFromContent(content);
      final hasText = textContent.isNotEmpty && textContent != '[Media]';
      final normalizedMediaType = mediaType?.toLowerCase();
      final hasMedia =
          (mediaUrl != null && mediaUrl.isNotEmpty) ||
          (localMediaPath != null && localMediaPath.isNotEmpty);
      final canScanMedia =
          hasMedia && _aiScannableMediaTypes.contains(normalizedMediaType);

      if (!hasText && !hasMedia) return null;

      AiDetectionResult? result;
      _PrecheckMediaFile? mediaAsset;
      try {
        if (canScanMedia) {
          mediaAsset = await _resolvePrecheckMediaFile(
            localMediaPath: localMediaPath,
            mediaUrl: mediaUrl,
            mediaType: normalizedMediaType,
          );
          if (mediaAsset == null && !hasText) return null;
        }
        final detectionModels = canScanMedia ? 'gpt-4.1' : 'gpt-5.2,o3';
        result = await _aiService.detectFull(
          content: hasText ? textContent : null,
          file: mediaAsset?.file,
          models: detectionModels,
        );
      } finally {
        if (mediaAsset?.shouldCleanup == true) {
          _cleanupFile(mediaAsset!.file);
        }
      }

      if (result == null) return null;

      final normalizedResult = result.result.trim().toUpperCase();
      final isAiResult =
          normalizedResult == 'AI-GENERATED' ||
          normalizedResult == 'LIKELY AI-GENERATED';
      final labelConfidence = result.confidence.clamp(0, 100);
      final aiScore = isAiResult ? labelConfidence : 100 - labelConfidence;
      return _AiPrecheckResult(
        aiScore: aiScore.toDouble(),
        aiScoreStatus: _resolveAiScoreStatus(aiScore.toDouble()),
        aiMetadata: _buildAiMetadata(result),
        analysisId: result.analysisId,
        rationale: result.rationale,
        combinedEvidence: result.combinedEvidence,
      );
    } catch (e) {
      debugPrint('ChatService: Pre-send AI detection failed - $e');
      return null;
    }
  }

  Future<_PrecheckMediaFile?> _resolvePrecheckMediaFile({
    String? localMediaPath,
    String? mediaUrl,
    String? mediaType,
  }) async {
    if (localMediaPath != null && localMediaPath.isNotEmpty) {
      final localFile = File(localMediaPath);
      if (await localFile.exists()) {
        return _PrecheckMediaFile(file: localFile, shouldCleanup: false);
      }
    }
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      final downloaded = await _downloadMedia(mediaUrl, mediaType: mediaType);
      if (downloaded == null) return null;
      return _PrecheckMediaFile(file: downloaded, shouldCleanup: true);
    }
    return null;
  }

  String _resolveAiScoreStatus(double aiScore) {
    if (aiScore >= _aiFlagThreshold) return 'flagged';
    if (aiScore >= _aiReviewThreshold) return 'review';
    return 'pass';
  }

  Map<String, dynamic> _buildAiMetadata(AiDetectionResult result) {
    return {
      'analysis_id': result.analysisId,
      'rationale': result.rationale,
      'combined_evidence': result.combinedEvidence,
      'consensus_strength': result.consensusStrength,
      'moderation': result.moderation?.toJson(),
      'safety_score': result.safetyScore,
      if (result.advertisement != null)
        'advertisement': result.advertisement!.toJson(),
    };
  }

  Future<void> _createModerationCaseIfNeeded({
    required String messageId,
    required String senderId,
    required double aiScore,
    required Map<String, dynamic> aiMetadata,
    String? rationale,
    List<String>? combinedEvidence,
  }) async {
    if (aiScore < _aiReviewThreshold) return;
    try {
      final existing = await _supabase
          .from('moderation_cases')
          .select('id')
          .eq('message_id', messageId)
          .maybeSingle();

      if (existing != null) return;

      await _supabase.from('moderation_cases').insert({
        'message_id': messageId,
        'reported_user_id': senderId,
        'reason': 'ai_generated',
        'source': 'ai',
        'ai_confidence': aiScore,
        'status': 'pending',
        'priority': 'normal',
        'description':
            'Automated AI detection flagged this message with ${aiScore.toStringAsFixed(1)}% confidence.',
        'ai_metadata': {
          ...aiMetadata,
          'rationale': rationale,
          'combined_evidence': combinedEvidence,
        },
      });
      debugPrint('ChatService: Created moderation case for message $messageId');
    } catch (e) {
      debugPrint('ChatService: Failed to create moderation case - $e');
    }
  }

  Future<Message> _hydrateMessageMediaUrl(Message message) async {
    final rawUrl = message.mediaUrl;
    if (rawUrl == null || rawUrl.isEmpty) return message;
    final resolvedUrl = await _resolveMessageMediaUrl(rawUrl);
    if (resolvedUrl == null || resolvedUrl == rawUrl) return message;
    return message.copyWith(mediaUrl: resolvedUrl);
  }

  Future<String?> _resolveMessageMediaUrl(String rawMediaRef) async {
    final path = _extractStoragePath(rawMediaRef);
    if (path == null || path.isEmpty) return rawMediaRef;

    final now = DateTime.now();
    final cached = _signedUrlCache[path];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.url;
    }

    try {
      final signedUrl = await _supabase.storage
          .from(SupabaseConfig.chatMediaBucket)
          .createSignedUrl(path, _signedUrlTtl.inSeconds);

      final expiresAt = now
          .add(_signedUrlTtl)
          .subtract(const Duration(minutes: 5));
      _signedUrlCache[path] = _SignedUrlCacheEntry(
        url: signedUrl,
        expiresAt: expiresAt,
      );
      return signedUrl;
    } catch (e) {
      debugPrint('ChatService: Failed to create signed media URL - $e');
      return rawMediaRef;
    }
  }

  String? _extractStoragePath(String rawMediaRef) {
    final trimmed = rawMediaRef.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed.startsWith('/')
          ? trimmed.replaceFirst(RegExp(r'^/+'), '')
          : trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final bucket = SupabaseConfig.chatMediaBucket;
    final publicPrefix = ['storage', 'v1', 'object', 'public', bucket];
    final signPrefix = ['storage', 'v1', 'object', 'sign', bucket];

    int _matchPrefixIndex(List<String> prefix) {
      for (var i = 0; i <= segments.length - prefix.length; i++) {
        var matches = true;
        for (var j = 0; j < prefix.length; j++) {
          if (segments[i + j] != prefix[j]) {
            matches = false;
            break;
          }
        }
        if (matches) return i + prefix.length;
      }
      return -1;
    }

    var start = _matchPrefixIndex(publicPrefix);
    if (start == -1) {
      start = _matchPrefixIndex(signPrefix);
    }
    if (start == -1 || start >= segments.length) return null;
    return segments.sublist(start).join('/');
  }

  /// Call this when the user deletes a conversation so the cache reflects
  /// the new left_at on the next stream event.
  void invalidateLeftAtCache(String threadId) {
    _leftAtCache.remove(threadId);
  }

  /// Mark all messages in a conversation as read for the current user.
  Future<void> markMessagesAsRead(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Update the participant's unread count and last_read_at
    await _supabase
        .from('dm_participants')
        .update({
          'unread_count': 0,
          'last_read_at': DateTime.now().toIso8601String(),
        })
        .eq('thread_id', threadId)
        .eq('user_id', userId);
  }

  /// Helper to download media from URL to a temporary file.
  Future<File?> _downloadMedia(String url, {String? mediaType}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final extension = _inferExtensionFromUrl(url, mediaType: mediaType);
        final fileName =
            'msg_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('ChatService: Error downloading media - $e');
    }
    return null;
  }

  void _cleanupFile(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('ChatService: Error cleaning up file - $e');
    }
  }

  String _resolveMediaCategory(String extension) {
    if (_isVideoExtension(extension)) return 'video';
    if (_isAudioExtension(extension)) return 'audio';
    if (_isImageExtension(extension)) return 'image';
    if (_isDocumentExtension(extension)) return 'document';
    return 'file';
  }

  String _resolveContentType(String extension, String mediaCategory) {
    if (_isImageExtension(extension)) {
      if (extension == 'png') return 'image/png';
      if (extension == 'gif') return 'image/gif';
      if (extension == 'webp') return 'image/webp';
      if (extension == 'heic') return 'image/heic';
      return 'image/jpeg';
    }

    if (_isVideoExtension(extension)) {
      if (extension == 'mov') return 'video/quicktime';
      if (extension == 'webm') return 'video/webm';
      if (extension == 'avi') return 'video/x-msvideo';
      if (extension == 'mkv') return 'video/x-matroska';
      return 'video/mp4';
    }

    if (_isAudioExtension(extension)) {
      if (extension == 'm4a') return 'audio/mp4';
      if (extension == 'aac') return 'audio/aac';
      if (extension == 'wav') return 'audio/wav';
      if (extension == 'ogg') return 'audio/ogg';
      return 'audio/mpeg';
    }

    if (_isDocumentExtension(extension)) {
      if (extension == 'pdf') return 'application/pdf';
      if (extension == 'doc') return 'application/msword';
      if (extension == 'docx') {
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }
      if (extension == 'ppt') return 'application/vnd.ms-powerpoint';
      if (extension == 'pptx') {
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      }
      if (extension == 'xls') return 'application/vnd.ms-excel';
      if (extension == 'xlsx') {
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      if (extension == 'txt') return 'text/plain';
      if (extension == 'csv') return 'text/csv';
    }

    if (mediaCategory == 'document') return 'application/octet-stream';
    return 'application/octet-stream';
  }

  bool _isImageExtension(String extension) =>
      {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'}.contains(extension);

  bool _isVideoExtension(String extension) =>
      {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'}.contains(extension);

  bool _isAudioExtension(String extension) =>
      {'mp3', 'm4a', 'aac', 'wav', 'ogg'}.contains(extension);

  bool _isDocumentExtension(String extension) => {
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'txt',
    'csv',
  }.contains(extension);

  String _inferExtensionFromUrl(String url, {String? mediaType}) {
    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '';
      final parts = lastSegment.split('.');
      if (parts.length > 1) {
        final ext = parts.last.toLowerCase();
        if (ext.isNotEmpty) return ext;
      }
    } catch (_) {}

    if (_videoMediaTypes.contains(mediaType)) return 'mp4';
    if (_imageMediaTypes.contains(mediaType)) return 'jpg';
    return 'bin';
  }
}

class _SignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;

  const _SignedUrlCacheEntry({required this.url, required this.expiresAt});
}

class _AiPrecheckResult {
  final double aiScore;
  final String aiScoreStatus;
  final Map<String, dynamic> aiMetadata;
  final String analysisId;
  final String? rationale;
  final List<String>? combinedEvidence;

  const _AiPrecheckResult({
    required this.aiScore,
    required this.aiScoreStatus,
    required this.aiMetadata,
    required this.analysisId,
    this.rationale,
    this.combinedEvidence,
  });
}

class _PrecheckMediaFile {
  final File file;
  final bool shouldCleanup;

  const _PrecheckMediaFile({required this.file, required this.shouldCleanup});
}
