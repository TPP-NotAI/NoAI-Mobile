import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models; // Alias your custom User model
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/follow_repository.dart';
import '../repositories/block_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/mute_repository.dart';

class UserProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  late final FollowRepository _followRepository;
  late final BlockRepository _blockRepository;
  late final MuteRepository _muteRepository;
  final ReportRepository _reportRepository = ReportRepository();

  List<app_models.User> _users = [];
  app_models.User? _currentUser;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
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
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get transactions => _transactions;

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
      _error = e.toString();
      _users = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch user by ID with full statistics
  Future<void> fetchUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch profile and wallet
      final profileResponse = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select(
            '*, ${SupabaseConfig.walletsTable}(*)',
          ) // Visibility settings removed due to schema mismatch
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('User not found');
      }

      // 2. Fetch counts
      final postsCountRes = await _supabase.client
          .from(SupabaseConfig.postsTable)
          .select('id')
          .eq('author_id', userId)
          .count(CountOption.exact);

      final followersCountRes = await _supabase.client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('following_id', userId)
          .count(CountOption.exact);

      final followingCountRes = await _supabase.client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('follower_id', userId)
          .count(CountOption.exact);

      final wallet = profileResponse[SupabaseConfig.walletsTable];
      app_models.User user = app_models.User.fromSupabase(
        profileResponse,
        wallet: wallet,
      );

      // Update user with real counts
      user = user.copyWith(
        postsCount: postsCountRes.count,
        followersCount: followersCountRes.count,
        followingCount: followingCountRes.count,
      );

      // If it's the current user, update it
      if (_currentUser?.id == userId) {
        _currentUser = user;
      }

      // Update in the users list
      final index = _users.indexWhere((u) => u.id == userId);
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
      _error = e.toString();
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

      return (response as List)
          .map(
            (json) => app_models.User.fromSupabase(
              json,
              wallet: json[SupabaseConfig.walletsTable],
            ),
          )
          .toList();
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

      _transactions = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('UserProvider: Error fetching transactions - $e');
      _error = e.toString();
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
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Find receiver ID by username
      final receiverResponse = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('user_id')
          .eq('username', toUsername)
          .maybeSingle();

      if (receiverResponse == null) {
        throw Exception('User @$toUsername not found');
      }

      final String toUserId = receiverResponse['user_id'] as String;

      // 2. We should ideally use a transaction or RPC here.
      // Since we are client-side, we'll do sequential updates.
      // NOTE: In production, this MUST be an atomic RPC function on the server.

      // Get current balance to verify again (safety)
      final balanceResponse = await _supabase.client
          .from(SupabaseConfig.walletsTable)
          .select('balance_rc')
          .eq('user_id', fromUserId)
          .single();

      final currentBalance = (balanceResponse['balance_rc'] as num).toDouble();
      if (currentBalance < amount) {
        throw Exception('Insufficient balance');
      }

      // Debit sender
      await _supabase.client
          .from(SupabaseConfig.walletsTable)
          .update({'balance_rc': currentBalance - amount})
          .eq('user_id', fromUserId);

      // Credit receiver
      final receiverBalanceResponse = await _supabase.client
          .from(SupabaseConfig.walletsTable)
          .select('balance_rc')
          .eq('user_id', toUserId)
          .single();

      final receiverBalance = (receiverBalanceResponse['balance_rc'] as num)
          .toDouble();

      await _supabase.client
          .from(SupabaseConfig.walletsTable)
          .update({'balance_rc': receiverBalance + amount})
          .eq('user_id', toUserId);

      // Record transaction
      await _supabase.client
          .from(SupabaseConfig.roocoinTransactionsTable)
          .insert({
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'amount_rc': amount,
            'tx_type': 'peer_transfer',
            'memo': memo,
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          });

      // Refresh data
      await fetchUser(fromUserId);
      await fetchTransactions(fromUserId);

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('UserProvider: Error transferring ROO - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _error = e.toString();
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
      _error = e.toString();
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
}
