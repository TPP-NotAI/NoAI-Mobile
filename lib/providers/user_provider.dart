import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rooverse/models/user.dart'
    as app_models; // Alias your custom User model
import '../core/extensions/exception_extensions.dart';
import '../models/user_activity.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/follow_repository.dart';
import '../repositories/block_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/mute_repository.dart';
import '../repositories/wallet_repository.dart';
import '../repositories/notification_repository.dart';

class UserProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  late final FollowRepository _followRepository;
  late final BlockRepository _blockRepository;
  late final MuteRepository _muteRepository;
  final ReportRepository _reportRepository = ReportRepository();
  final WalletRepository _walletRepository = WalletRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();

  List<app_models.User> _users = [];
  app_models.User? _currentUser;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
  List<UserActivity> _userActivities = [];
  final Map<String, bool> _followStatusCache =
      {}; // Cache follow status by user ID
  final Map<String, bool> _blockStatusCache =
      {}; // Cache block status by user ID (users current user has blocked)
  final Map<String, bool> _muteStatusCache =
      {}; // Cache mute status by user ID (users current user has muted)
  final Set<String> _blockedByUserIds =
      {}; // Users who have blocked the current user

  // Callback for when block list changes (for FeedProvider sync)
  void Function(Set<String> blocked, Set<String> blockedBy)? onBlockListChanged;

  /// Callback for when the mute list changes.
  Function(Set<String> muted)? onMuteListChanged;

  UserProvider() {
    _followRepository = FollowRepository(_supabase.client);
    _blockRepository = BlockRepository(_supabase.client);
    _muteRepository = MuteRepository(_supabase.client);
  }

  List<app_models.User> get users => _users;

  /// Get users filtered by blocked relationships.
  /// Hides users you've blocked and users who've blocked you.
  List<app_models.User> get filteredUsers {
    if (_blockStatusCache.isEmpty && _blockedByUserIds.isEmpty) {
      return _users; // No filtering needed if no blocks
    }
    return _users.where((user) {
      // Hide users you've blocked or who've blocked you
      return !isBlocked(user.id) && !isBlockedByUser(user.id);
    }).toList();
  }

  app_models.User? get currentUser => _currentUser;

  /// Check if the current user's profile is complete (display name and bio).
  bool get isProfileComplete {
    final user = _currentUser;
    if (user == null) return false;
    return user.displayName.isNotEmpty &&
        user.bio != null &&
        user.bio!.isNotEmpty &&
        user.interests.isNotEmpty;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get transactions => _transactions;
  List<UserActivity> get userActivities => _userActivities;

  /// Get set of user IDs who have blocked the current user.
  Set<String> get blockedByUserIds => _blockedByUserIds;

  /// Get set of user IDs that the current user has blocked.
  Set<String> get blockedUserIds =>
      _blockStatusCache.entries.where((e) => e.value).map((e) => e.key).toSet();

  /// Get set of user IDs that the current user has muted.
  Set<String> get mutedUserIds =>
      _muteStatusCache.entries.where((e) => e.value).map((e) => e.key).toSet();

  /// Check if the current user is following a specific user (from cache).
  bool isFollowing(String userId) => _followStatusCache[userId] ?? false;

  /// Check if the current user has blocked a specific user (from cache).
  bool isBlocked(String userId) => _blockStatusCache[userId] ?? false;

  /// Check if the current user has muted a specific user (from cache).
  bool isMuted(String userId) => _muteStatusCache[userId] ?? false;

  /// Check if a specific user has blocked the current user.
  bool isBlockedByUser(String userId) => _blockedByUserIds.contains(userId);

  // Get user by ID or username from cached users or return current user if null
  app_models.User? getUser(String? userIdOrUsername) {
    if (userIdOrUsername == null) {
      return _currentUser;
    }

    // Search by ID first
    try {
      return _users.firstWhere((user) => user.id == userIdOrUsername);
    } catch (e) {
      // If not found, check current user
      if (_currentUser?.id == userIdOrUsername) {
        return _currentUser!;
      }
    }

    // Search by username
    try {
      return _users.firstWhere((user) => user.username == userIdOrUsername);
    } catch (e) {
      // If not found, check current user
      if (_currentUser?.username == userIdOrUsername) {
        return _currentUser!;
      }
    }

    return null;
  }

  /// Resolve a user ID from either a UUID-like user id or a username.
  Future<String?> resolveUserId(String userIdOrUsername) async {
    final raw = userIdOrUsername.trim();
    if (raw.isEmpty) return null;

    final normalized = raw.startsWith('@') ? raw.substring(1) : raw;

    // Fast path: already cached as id/username.
    final cached = getUser(normalized);
    if (cached != null) return cached.id;

    try {
      final byId = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('user_id')
          .eq('user_id', normalized)
          .maybeSingle();
      if (byId != null) {
        return byId['user_id'] as String?;
      }

      final byUsername = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('user_id')
          .ilike('username', normalized)
          .maybeSingle();
      return byUsername?['user_id'] as String?;
    } catch (e) {
      debugPrint('UserProvider: Error resolving user id for $raw - $e');
      return null;
    }
  }

  // Fetch all users
  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)');

      _users = (response as List)
          .map(
            (json) => app_models.User.fromSupabase(
              json,
              wallet: json[SupabaseConfig.walletsTable],
            ),
          )
          .toList();
      _error = null;
    } catch (e) {
      _error = e.userMessage;
      _users = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch user by ID or username with full statistics
  Future<void> fetchUser(String userIdOrUsername) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resolvedUserId = await resolveUserId(userIdOrUsername);
      if (resolvedUserId == null) {
        throw Exception('User not found');
      }

      // 1. Fetch profile and wallet
      final profileResponse = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .eq('user_id', resolvedUserId)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('User not found');
      }

      // 2. Fetch counts
      final postsCountRes = await _supabase.client
          .from(SupabaseConfig.postsTable)
          .select('id')
          .eq('author_id', resolvedUserId)
          .eq('status', 'published')
          .count(CountOption.exact);

      final followersCountRes = await _supabase.client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('following_id', resolvedUserId)
          .count(CountOption.exact);

      final followingCountRes = await _supabase.client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('follower_id', resolvedUserId)
          .count(CountOption.exact);

      final humanVerifiedCountRes = await _supabase.client
          .from(SupabaseConfig.postsTable)
          .select('id')
          .eq('author_id', resolvedUserId)
          .eq('status', 'published')
          .eq('ai_score_status', 'pass')
          .count(CountOption.exact);

      // 3. Fetch user achievements with achievement details
      List<app_models.UserAchievement> achievements = [];
      try {
        final achievementsRes = await _supabase.client
            .from('user_achievements')
            .select('*, achievements(*)')
            .eq('user_id', resolvedUserId);
        achievements = (achievementsRes as List)
            .map((json) => app_models.UserAchievement.fromSupabase(json))
            .toList();
      } catch (e) {
        debugPrint('UserProvider: Error fetching achievements - $e');
      }

      final wallet = profileResponse[SupabaseConfig.walletsTable];
      app_models.User user = app_models.User.fromSupabase(
        profileResponse,
        wallet: wallet,
        achievements: achievements,
      );

      // Calculate trust score: verified content / total content * 100
      final totalPosts = postsCountRes.count;
      final verifiedPosts = humanVerifiedCountRes.count;
      final calculatedTrustScore = totalPosts > 0
          ? (verifiedPosts / totalPosts) * 100
          : 0.0;

      // Update user with real counts and calculated trust score
      user = user.copyWith(
        postsCount: postsCountRes.count,
        humanVerifiedPostsCount: humanVerifiedCountRes.count,
        followersCount: followersCountRes.count,
        followingCount: followingCountRes.count,
        trustScore: calculatedTrustScore,
      );

      // If it's the current user, update it
      if (_currentUser?.id == resolvedUserId) {
        _currentUser = user;
      }

      // Update in the users list
      final index = _users.indexWhere((u) => u.id == resolvedUserId);
      if (index != -1) {
        // Ensure the existing user in _users list is updated with the new counts
        // and potentially other profile data fetched by profileResponse.
        // The fromSupabase method should handle merging if necessary,
        // or you might need to explicitly copy fields.
        _users[index] = user;
      } else {
        _users.add(user);
      }

      _error = null;
    } catch (e) {
      debugPrint('UserProvider: Error fetching user - $e');
      _error = e.userMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch details for a list of user IDs.
  Future<List<app_models.User>> fetchUsersByIds(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }
    _isLoading = true;
    notifyListeners(); // Notify to show loading state if needed

    try {
      final response = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .inFilter('user_id', userIds.toList());

      final fetched = (response as List)
          .map(
            (json) => app_models.User.fromSupabase(
              json,
              wallet: json[SupabaseConfig.walletsTable],
            ),
          )
          .toList();

      // Merge into local cache so `getUser` can resolve sender/receiver labels.
      for (final user in fetched) {
        final existingIndex = _users.indexWhere((u) => u.id == user.id);
        if (existingIndex == -1) {
          _users.add(user);
        } else {
          _users[existingIndex] = user;
        }
      }

      return fetched;
    } catch (e) {
      debugPrint('UserProvider: Error fetching users by IDs - $e');
      return [];
    } finally {
      _isLoading = false; // Reset loading state
      notifyListeners(); // Notify that loading is complete
    }
  }

  // Set current user
  void setCurrentUser(app_models.User user) {
    _currentUser = user;
    // Load block relationships when user is set
    loadBlockRelationships();
    loadMuteRelationships();
    notifyListeners();
  }

  // Set users list
  void setUsers(List<app_models.User> users) {
    _users = users;
    notifyListeners();
  }

  // Clear current user
  void clearCurrentUser() {
    _currentUser = null;
    _blockedByUserIds.clear();
    _blockStatusCache.clear();
    _muteStatusCache.clear();
    notifyListeners();
  }

  /// Load all block relationships for the current user.
  /// This loads both users the current user has blocked and users who have blocked them.
  Future<void> loadBlockRelationships() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final relationships = await _blockRepository.getAllBlockRelationships(
        currentUserId,
      );

      // Update blocked users cache
      _blockStatusCache.clear();
      for (final userId in relationships['blocked'] ?? []) {
        _blockStatusCache[userId] = true;
      }

      // Update blocked-by users set
      _blockedByUserIds.clear();
      _blockedByUserIds.addAll(relationships['blockedBy'] ?? []);

      debugPrint(
        'UserProvider: Loaded block relationships - blocked: ${_blockStatusCache.length}, blockedBy: ${_blockedByUserIds.length}',
      );
      notifyListeners();
      // Notify FeedProvider of block list change
      _notifyBlockListChanged();
    } catch (e) {
      debugPrint('UserProvider: Error loading block relationships - $e');
    }
  }

  // Fetch roocoin transactions
  Future<void> fetchTransactions(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.client
          .from(SupabaseConfig.roocoinTransactionsTable)
          .select('*')
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .order('created_at', ascending: false);

      final rawTxs = List<Map<String, dynamic>>.from(response);

      // Enrich with sender/receiver profile data for transaction details UI.
      final userIds = <String>{};
      for (final tx in rawTxs) {
        final fromId = tx['from_user_id'] as String?;
        final toId = tx['to_user_id'] as String?;
        if (fromId != null && fromId.isNotEmpty) userIds.add(fromId);
        if (toId != null && toId.isNotEmpty) userIds.add(toId);
      }

      final profileById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        final profiles = await _supabase.client
            .from(SupabaseConfig.profilesTable)
            .select('user_id, username, display_name, avatar_url')
            .inFilter('user_id', userIds.toList());

        for (final row in (profiles as List)) {
          final profile = Map<String, dynamic>.from(row as Map);
          final id = profile['user_id'] as String?;
          if (id != null && id.isNotEmpty) {
            profileById[id] = profile;
          }
        }
      }

      _transactions = rawTxs.map((tx) {
        final enriched = Map<String, dynamic>.from(tx);
        final fromId = tx['from_user_id'] as String?;
        final toId = tx['to_user_id'] as String?;
        enriched['from_profile'] =
            fromId != null ? profileById[fromId] : null;
        enriched['to_profile'] = toId != null ? profileById[toId] : null;
        return enriched;
      }).toList();
    } catch (e) {
      debugPrint('UserProvider: Error fetching transactions - $e');
      _error = e.userMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch user's own app activities (posts created, likes given, comments made, etc.)
  Future<void> fetchUserActivities(String userIdOrUsername, {int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = await resolveUserId(userIdOrUsername);
      if (userId == null) {
        throw Exception('User not found');
      }

      final List<UserActivity> activities = [];

      // Fetch posts created by user
      final postsResponse = await _supabase.client
          .from(SupabaseConfig.postsTable)
          .select('id, body, created_at, post_media(storage_path)')
          .eq('author_id', userId)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(limit);

      for (final post in postsResponse) {
        final mediaList = post['post_media'] as List?;

        String? mediaUrl;
        if (mediaList != null && mediaList.isNotEmpty) {
          final path = mediaList.first['storage_path'] as String?;
          if (path != null) {
            if (path.startsWith('http')) {
              mediaUrl = path;
            } else {
              mediaUrl =
                  '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$path';
            }
          }
        }

        activities.add(
          UserActivity(
            id: 'post_${post['id']}',
            type: UserActivityType.postCreated,
            timestamp: DateTime.parse(post['created_at']),
            postId: post['id'],
            postContent: post['body'],
            postMediaUrl: mediaUrl,
          ),
        );
      }

      // Fetch likes given by user
      final likesResponse = await _supabase.client
          .from(SupabaseConfig.reactionsTable)
          .select('id, created_at, post_id, posts(body)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final like in likesResponse) {
        final post = like['posts'];
        activities.add(
          UserActivity(
            id: 'like_${like['id']}',
            type: UserActivityType.postLiked,
            timestamp: DateTime.parse(like['created_at']),
            postId: like['post_id'],
            postContent: post?['body'],
          ),
        );
      }

      // Fetch comments made by user
      final commentsResponse = await _supabase.client
          .from(SupabaseConfig.commentsTable)
          .select('id, body, created_at, post_id, posts(body)')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final comment in commentsResponse) {
        final post = comment['posts'];
        activities.add(
          UserActivity(
            id: 'comment_${comment['id']}',
            type: UserActivityType.postCommented,
            timestamp: DateTime.parse(comment['created_at']),
            postId: comment['post_id'],
            postContent: post?['body'],
            commentContent: comment['body'],
          ),
        );
      }

      // Fetch follows made by user
      final followsResponse = await _supabase.client
          .from(SupabaseConfig.followsTable)
          .select(
            'created_at, follower_id, following_id, profiles!follows_following_id_fkey(user_id, username, display_name, avatar_url)',
          )
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final follow in followsResponse) {
        final profile = follow['profiles'];
        activities.add(
          UserActivity(
            id: 'follow_${follow['follower_id']}_${follow['following_id']}',
            type: UserActivityType.userFollowed,
            timestamp: DateTime.parse(follow['created_at']),
            targetUserId: follow['following_id'],
            targetUsername: profile?['username'],
            targetDisplayName: profile?['display_name'],
            targetAvatarUrl: profile?['avatar_url'],
          ),
        );
      }

      // Fetch reposts made by user
      final repostsResponse = await _supabase.client
          .from(SupabaseConfig.repostsTable)
          .select('id, created_at, post_id, posts(body)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final repost in repostsResponse) {
        final post = repost['posts'];
        activities.add(
          UserActivity(
            id: 'repost_${repost['id']}',
            type: UserActivityType.postReposted,
            timestamp: DateTime.parse(repost['created_at']),
            postId: repost['post_id'],
            postContent: post?['body'],
          ),
        );
      }

      // Fetch Rooken transactions
      final txResponse = await _supabase.client
          .from(SupabaseConfig.roocoinTransactionsTable)
          .select(
            'id, created_at, amount_rc, tx_type, from_user_id, to_user_id, tx_hash, metadata',
          )
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> rawTxs = List<Map<String, dynamic>>.from(
        txResponse,
      );
      final Set<String> seenHashes = {};
      final txParticipantIds = <String>{};
      for (final tx in rawTxs) {
        final fromId = tx['from_user_id'] as String?;
        final toId = tx['to_user_id'] as String?;
        if (fromId != null && fromId.isNotEmpty) txParticipantIds.add(fromId);
        if (toId != null && toId.isNotEmpty) txParticipantIds.add(toId);
      }

      final profilesById = <String, Map<String, dynamic>>{};
      if (txParticipantIds.isNotEmpty) {
        final profileRows = await _supabase.client
            .from(SupabaseConfig.profilesTable)
            .select('user_id, username, display_name, avatar_url')
            .inFilter('user_id', txParticipantIds.toList());
        for (final row in (profileRows as List)) {
          final profile = Map<String, dynamic>.from(row as Map);
          final id = profile['user_id'] as String?;
          if (id != null && id.isNotEmpty) {
            profilesById[id] = profile;
          }
        }
      }

      for (final tx in rawTxs) {
        final hash = tx['tx_hash'] as String?;
        if (hash != null && hash.isNotEmpty) {
          if (seenHashes.contains(hash)) continue;
          seenHashes.add(hash);
        }

        final amount = (tx['amount_rc'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue; // skip zero/null amount transactions
        final isReceived = tx['to_user_id'] == userId;
        final txType = tx['tx_type'] as String?;
        final isTransfer = txType == 'transfer' || txType == 'tip';
        final metadataRaw = tx['metadata'];
        final metadata = metadataRaw is Map
            ? Map<String, dynamic>.from(metadataRaw)
            : <String, dynamic>{};
        final toUserId = tx['to_user_id'] as String?;
        final fromUserId = tx['from_user_id'] as String?;
        final toProfile = toUserId != null ? profilesById[toUserId] : null;
        final fromProfile = fromUserId != null ? profilesById[fromUserId] : null;

        UserActivityType activityType;
        if (isTransfer && !isReceived) {
          activityType = UserActivityType.rookenTransferred;
        } else if (isReceived) {
          activityType = UserActivityType.rookenEarned;
        } else {
          activityType = UserActivityType.rookenSpent;
        }

        activities.add(
          UserActivity(
            id: 'tx_${tx['id']}',
            type: activityType,
            timestamp: DateTime.parse(tx['created_at']),
            amount: amount,
            transactionType: txType,
            targetUserId: isReceived ? fromUserId : toUserId,
            targetUsername: isReceived
                ? (fromProfile?['username'] as String?)
                : (toProfile?['username'] as String?) ??
                      (metadata['recipientUsername'] as String?),
            targetDisplayName: isReceived
                ? (fromProfile?['display_name'] as String?)
                : (toProfile?['display_name'] as String?) ??
                      (metadata['recipientDisplayName'] as String?),
            targetAvatarUrl: isReceived
                ? (fromProfile?['avatar_url'] as String?)
                : (toProfile?['avatar_url'] as String?),
          ),
        );
      }

      // Sort all activities by timestamp (newest first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Only show received ROO (not spent or transferred)
      final filtered = activities.where((a) =>
        a.type != UserActivityType.rookenSpent &&
        a.type != UserActivityType.rookenTransferred,
      ).toList();

      // Limit to the most recent activities
      _userActivities = filtered.take(limit).toList();
      _error = null;
    } catch (e) {
      debugPrint('UserProvider: Error fetching user activities - $e');
      _error = e.userMessage;
      _userActivities = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Transfer ROO to another user
  Future<bool> transferRoo({
    required String fromUserId,
    required String toUsername,
    required double amount,
    String? memo,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'UserProvider: Transferring $amount ROO from $fromUserId to @$toUsername...',
      );

      final resolved = await resolveUsernameToAddress(toUsername);
      final recipientAddress = resolved['address']!;
      final recipientUserId = resolved['userId']!;

      await _walletRepository.transferToExternal(
        userId: fromUserId,
        toAddress: recipientAddress,
        amount: amount,
        memo: memo,
        referencePostId: referencePostId,
        referenceCommentId: referenceCommentId,
        metadata: metadata,
      );

      // Notify recipient in-app (fire-and-forget, never blocks transfer)
      final isTip = metadata?['activityType'] == 'tip';
      final senderUsername = _currentUser?.username ?? '';
      _notificationRepository.createNotification(
        userId: recipientUserId,
        type: isTip ? 'mention' : 'mention',
        title: isTip ? 'You received a tip!' : 'You received ROO!',
        body: isTip
            ? '@$senderUsername tipped you ${amount.toStringAsFixed(0)} ROO'
            : '@$senderUsername sent you ${amount.toStringAsFixed(2)} ROO',
        actorId: fromUserId,
        postId: referencePostId,
      ).catchError((e) {
        debugPrint('UserProvider: wallet notification failed (non-critical) - $e');
        return false;
      });

      // Refresh local user data in background to show updated balance
      // We don't await this to keep the UI snappy
      Future.wait([
        fetchUser(fromUserId),
        fetchTransactions(fromUserId),
      ]).catchError((e) {
        debugPrint(
          'UserProvider: Error refreshing profile after transfer - $e',
        );
        return [];
      });

      return true;
    } catch (e) {
      _error = e.userMessage;
      debugPrint('UserProvider: Error transferring ROO - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>> resolveUsernameToAddress(String username) async {
    final cleanUsername = username.startsWith('@')
        ? username.substring(1)
        : username;
    if (cleanUsername.trim().isEmpty) {
      throw Exception('Username is required');
    }

    final recipientProfile = await _supabase.client
        .from(SupabaseConfig.profilesTable)
        .select('user_id')
        .ilike('username', cleanUsername)
        .maybeSingle();

    if (recipientProfile == null) {
      throw Exception('User @$cleanUsername not found');
    }

    final recipientUserId = recipientProfile['user_id'] as String;

    final recipientWallet = await _supabase.client
        .from(SupabaseConfig.walletsTable)
        .select('wallet_address')
        .eq('user_id', recipientUserId)
        .maybeSingle();

    final recipientAddress =
        recipientWallet?['wallet_address'] as String? ?? '';

    if (recipientAddress.startsWith('PENDING_ACTIVATION_')) {
      throw Exception(
        'User @$cleanUsername has not activated their wallet yet',
      );
    }

    final evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (!evmRegex.hasMatch(recipientAddress)) {
      throw Exception(
        'User @$cleanUsername has not activated their wallet yet',
      );
    }

    return {'userId': recipientUserId, 'address': recipientAddress};
  }

  // Update user profile
  Future<bool> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .update(updates)
          .eq('user_id', userId);

      // Refresh local user data
      await fetchUser(userId);
      return true;
    } catch (e) {
      _error = e.userMessage;
      debugPrint('UserProvider: Error updating profile - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user privacy settings.
  Future<bool> updatePrivacySettings({
    required String userId,
    required String postsVisibility,
    required String commentsVisibility,
    required String messagesVisibility,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .update({
            'posts_visibility': postsVisibility,
            'comments_visibility': commentsVisibility,
            'messages_visibility': messagesVisibility,
          })
          .eq('user_id', userId);

      // Refresh local user data to reflect changes
      await fetchUser(userId);
      return true;
    } catch (e) {
      _error = e.userMessage;
      debugPrint('UserProvider: Error updating privacy settings - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggle follow status
  /// Load follow status for a specific user from Supabase.
  Future<void> loadFollowStatus(String targetUserId) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return;

    final isFollowing = await _followRepository.isFollowing(
      currentUserId,
      targetUserId,
    );
    _followStatusCache[targetUserId] = isFollowing;
    notifyListeners();
  }

  /// Toggle follow/unfollow for a user.
  Future<bool> toggleFollow(String targetUserId) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return false;

    // Prevent self-following
    if (currentUserId == targetUserId) {
      _error = 'You cannot follow yourself';
      return false;
    }

    // Get current follow status
    final currentlyFollowing = _followStatusCache[targetUserId] ?? false;

    // Optimistic update
    _followStatusCache[targetUserId] = !currentlyFollowing;
    notifyListeners();

    bool success;
    if (currentlyFollowing) {
      // Unfollow
      success = await _followRepository.unfollowUser(
        currentUserId,
        targetUserId,
      );
    } else {
      // Follow
      success = await _followRepository.followUser(currentUserId, targetUserId);
    }

    if (!success) {
      // Revert on failure
      _followStatusCache[targetUserId] = currentlyFollowing;
      notifyListeners();
      _error = 'Failed to ${currentlyFollowing ? 'unfollow' : 'follow'} user';
    } else {
      // Update the user's follower count if they're in the cache
      final userIndex = _users.indexWhere((u) => u.id == targetUserId);
      if (userIndex != -1) {
        final user = _users[userIndex];
        final newFollowerCount = currentlyFollowing
            ? user.followersCount - 1
            : user.followersCount + 1;
        _users[userIndex] = user.copyWith(followersCount: newFollowerCount);
      }

      // Update current user's following count
      if (_currentUser != null) {
        final newFollowingCount = currentlyFollowing
            ? _currentUser!.followingCount - 1
            : _currentUser!.followingCount + 1;
        _currentUser = _currentUser!.copyWith(
          followingCount: newFollowingCount,
        );
      }
    }

    return success;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLOCK / UNBLOCK
  // ─────────────────────────────────────────────────────────────────────────

  /// Load block status for a specific user from Supabase.
  Future<void> loadBlockStatus(String targetUserId) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return;

    final isBlocked = await _blockRepository.isBlocked(
      currentUserId,
      targetUserId,
    );
    _blockStatusCache[targetUserId] = isBlocked;
    notifyListeners();
  }

  /// Toggle block/unblock for a user.
  Future<bool> toggleBlock(String targetUserId) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return false;

    // Prevent self-blocking
    if (currentUserId == targetUserId) {
      _error = 'You cannot block yourself';
      return false;
    }

    // Get current block status
    final currentlyBlocked = _blockStatusCache[targetUserId] ?? false;

    // Optimistic update
    _blockStatusCache[targetUserId] = !currentlyBlocked;
    notifyListeners();
    // Notify FeedProvider of block list change
    _notifyBlockListChanged();

    bool success;
    if (currentlyBlocked) {
      // Unblock
      success = await _blockRepository.unblockUser(currentUserId, targetUserId);
    } else {
      // Block
      success = await _blockRepository.blockUser(currentUserId, targetUserId);

      // Also unfollow if currently following
      if (success && (_followStatusCache[targetUserId] ?? false)) {
        await _followRepository.unfollowUser(currentUserId, targetUserId);
        _followStatusCache[targetUserId] = false;
      }
    }

    if (!success) {
      // Revert on failure
      _blockStatusCache[targetUserId] = currentlyBlocked;
      notifyListeners();
      // Notify FeedProvider of block list revert
      _notifyBlockListChanged();
      _error = 'Failed to ${currentlyBlocked ? 'unblock' : 'block'} user';
    }

    return success;
  }

  /// Notify listeners when block list changes.
  void _notifyBlockListChanged() {
    onBlockListChanged?.call(blockedUserIds, blockedByUserIds);
  }

  /// Notify listeners when mute list changes.
  void _notifyMuteListChanged() {
    onMuteListChanged?.call(mutedUserIds);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REPORT USER
  // ─────────────────────────────────────────────────────────────────────────

  /// Report a user.
  Future<bool> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      _error = 'You must be logged in to report';
      return false;
    }

    // Prevent self-reporting
    if (currentUserId == reportedUserId) {
      _error = 'You cannot report yourself';
      return false;
    }

    // Check if already reported
    final alreadyReported = await _reportRepository.hasReportedUser(
      reporterId: currentUserId,
      reportedUserId: reportedUserId,
    );

    if (alreadyReported) {
      _error = 'You have already reported this user';
      return false;
    }

    final success = await _reportRepository.reportUser(
      reporterId: currentUserId,
      reportedUserId: reportedUserId,
      reason: reason,
      details: details,
    );

    if (!success) {
      _error = 'Failed to submit report';
    }

    return success;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTE / UNMUTE
  // ─────────────────────────────────────────────────────────────────────────

  /// Load all muted users for the current user.
  Future<void> loadMuteRelationships() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final mutedIds = await _muteRepository.getMutedUserIds(currentUserId);
      _muteStatusCache.clear();
      for (final id in mutedIds) {
        _muteStatusCache[id] = true;
      }
      notifyListeners();
      _notifyMuteListChanged();
    } catch (e) {
      debugPrint('UserProvider: Error loading mute relationships - $e');
    }
  }

  /// Toggle mute/unmute for a user.
  Future<bool> toggleMute(String targetUserId) async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) return false;

    if (currentUserId == targetUserId) {
      _error = 'You cannot mute yourself';
      return false;
    }

    final currentlyMuted = _muteStatusCache[targetUserId] ?? false;

    // Optimistic update
    _muteStatusCache[targetUserId] = !currentlyMuted;
    notifyListeners();
    _notifyMuteListChanged();

    debugPrint(
      'UserProvider: Toggling mute for $targetUserId. Currently muted: $currentlyMuted',
    );

    bool success;
    if (currentlyMuted) {
      success = await _muteRepository.unmuteUser(currentUserId, targetUserId);
    } else {
      success = await _muteRepository.muteUser(currentUserId, targetUserId);
    }

    if (!success) {
      _muteStatusCache[targetUserId] = currentlyMuted;
      notifyListeners();
      _notifyMuteListChanged();
      _error = 'Failed to ${currentlyMuted ? 'unmute' : 'mute'} user';
      debugPrint(
        'UserProvider: Failed to toggle mute for $targetUserId. Error: $_error',
      );
    } else {
      debugPrint('UserProvider: Successfully toggled mute for $targetUserId');
    }

    return success;
  }
  // ─────────────────────────────────────────────────────────────────────────
  // USER SEARCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Search users by username or display name.
  Future<List<app_models.User>> searchUsers(String query) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return [];

    // Support both "@username" and plain name search.
    final normalizedQuery = rawQuery.startsWith('@')
        ? rawQuery.substring(1).trim()
        : rawQuery;
    if (normalizedQuery.isEmpty) return [];

    _isLoading =
        true; // Optional: might not want to set global loading for local search
    notifyListeners();

    try {
      final response = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .or(
            'username.ilike.%$normalizedQuery%,display_name.ilike.%$normalizedQuery%',
          )
          .limit(20);

      final users = (response as List)
          .map(
            (json) => app_models.User.fromSupabase(
              json,
              wallet: json[SupabaseConfig.walletsTable],
            ),
          )
          .toList();

      return users;
    } catch (e) {
      debugPrint('UserProvider: Error searching users - $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTE / UNMUTE (Existing code follows...)
}
