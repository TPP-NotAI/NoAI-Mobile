import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet.dart';
import '../services/rooken_service.dart';
import '../services/secure_storage_service.dart';
import '../services/activity_log_service.dart';
import '../core/extensions/exception_extensions.dart';

/// Repository for managing wallet data and Rooken integration
class WalletRepository {
  final SupabaseClient _supabase;
  final RookenService _rookenService;
  final SecureStorageService _secureStorage;
  final ActivityLogService _activityLogService = ActivityLogService();
  static const String _walletKeysTable = 'user_wallet_keys';
  static const String _legacyWalletBackupsTable = 'wallet_backups';
  static final Map<String, Future<Wallet>> _getOrCreateInFlight = {};
  static final Map<String, Future<Wallet>> _repairInFlight = {};

  /// Set to false to disable the 100 ROO welcome bonus (new activation flow:
  /// users must purchase ROO via Stripe to activate their account).
  static const bool _enableWelcomeBonus = false;

  WalletRepository({
    SupabaseClient? supabase,
    RookenService? rookenService,
    SecureStorageService? secureStorage,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _rookenService = rookenService ?? RookenService(),
       _secureStorage = secureStorage ?? SecureStorageService();

  /// Get wallet for a user
  Future<Wallet?> getWallet(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return Wallet.fromSupabase(response);
    } catch (e) {
      debugPrint('Error getting wallet: $e');
      rethrow;
    }
  }

  /// Create a new wallet for a user
  /// This creates both the blockchain wallet and the database entry
  Future<Wallet> createWallet(String userId) async {
    try {
      // 1. Create blockchain wallet via Rooken API
      final walletData = await _rookenService.createWallet();
      final address = walletData['address'] as String;
      final privateKey = walletData['privateKey'] as String;

      // 2. Store encrypted private key securely
      await _secureStorage.write('wallet_private_key_$userId', privateKey);

      // 3. Backup key to DB for cross-device recovery
      await _backupKey(userId, address, privateKey);

      // 4. Create wallet entry in Supabase
      // Use upsert to handle race conditions (e.g. double tap) or existing hidden records.
      // This ensures the DB wallet matches the newly generated private key strictly.
      final response = await _supabase
          .from('wallets')
          .upsert({
            'user_id': userId,
            'wallet_address': address,
            'balance_rc': 0,
            'pending_balance_rc': 0,
            'lifetime_earned_rc': 0,
            'lifetime_spent_rc': 0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // 4. Award welcome bonus (100 ROOK) — disabled under new activation flow
      if (_enableWelcomeBonus) {
        try {
          await checkAndAwardWelcomeBonus(userId, address: address);

          // Refresh response after welcome bonus
          final refreshedResponse = await _supabase
              .from('wallets')
              .select()
              .eq('user_id', userId)
              .single();
          return Wallet.fromSupabase(refreshedResponse);
        } catch (e) {
          debugPrint('Failed to award welcome bonus during creation: $e');
          // Continue even if bonus fails, user can get it later via checkAndAwardWelcomeBonus
        }
      }

      return Wallet.fromSupabase(response);
    } catch (e) {
      debugPrint('Error creating wallet: $e');
      rethrow;
    }
  }

  /// Get or create wallet for a user
  Future<Wallet> getOrCreateWallet(String userId) {
    final existing = _getOrCreateInFlight[userId];
    if (existing != null) return existing;

    final task = _getOrCreateWalletInternal(userId);
    _getOrCreateInFlight[userId] = task;
    return task.whenComplete(() {
      _getOrCreateInFlight.remove(userId);
    });
  }

  Future<Wallet> _getOrCreateWalletInternal(String userId) async {
    // 1. Ensure we have the private key locally
    final localKey = await _secureStorage.read('wallet_private_key_$userId');

    if (localKey == null) {
      // Key missing locally (new install/device). Try to restore from DB.
      final restored = await _restoreKey(userId);
      if (!restored) {
        // If we can't restore, and a wallet exists in DB, we have a "Lost Key" scenario.
        // We must repair/reset the wallet so the user can use the app.
        // Warning: This loses access to the OLD wallet address on-chain (funds lost).
        final existingWallet = await getWallet(userId);
        if (existingWallet != null) {
          debugPrint(
            'WalletRepository: Wallet exists but Key lost/not-backed-up. Triggering Reset/Repair.',
          );
          return await _repairWalletLocked(userId);
        }
        // If no wallet exists, we will create one below.
      }
    }

    final wallet = await getWallet(userId);

    // If wallet exists but address is invalid, we need to "repair" it
    if (wallet != null && !_isValidAddress(wallet.walletAddress)) {
      debugPrint(
        'Repairing wallet for user $userId: Invalid address ${wallet.walletAddress}',
      );
      return await _repairWalletLocked(userId);
    }

    if (wallet != null) {
      // Self-heal: ensure key backup row exists in primary key table.
      await _ensurePrimaryKeyBackup(
        userId,
        walletAddress: wallet.walletAddress,
      );
      return wallet;
    }
    return await createWallet(userId);
  }

  Future<Wallet> _repairWalletLocked(String userId) {
    final existing = _repairInFlight[userId];
    if (existing != null) return existing;

    final task = _repairWallet(userId);
    _repairInFlight[userId] = task;
    return task.whenComplete(() {
      _repairInFlight.remove(userId);
    });
  }

  /// Check if Roocoin API is healthy
  Future<bool> checkApiHealth() async {
    try {
      final health = await _rookenService.checkHealth();
      return health['status'] == 'healthy' || health['status'] == 'ok';
    } catch (e) {
      debugPrint('WalletRepository: API Health check failed: $e');
      return false;
    }
  }

  /// Sync balance with blockchain
  Future<Wallet> syncBalance(String userId) async {
    try {
      final wallet = await getWallet(userId);
      if (wallet == null) throw Exception('Wallet not found');

      if (!_isValidAddress(wallet.walletAddress) ||
          _isPlaceholderAddress(wallet.walletAddress)) {
        return wallet;
      }

      // 1. Get balance from blockchain
      final balanceData = await _rookenService.getBalance(wallet.walletAddress);

      // Handle both 'balance' and 'balanceRc' fields for robustness
      final rawBalance =
          balanceData['balanceRc'] ?? balanceData['balance'] ?? 0;
      final double blockchainBalance = _parseDouble(rawBalance);

      // 2. Update local DB if different
      if ((wallet.balanceRc - blockchainBalance).abs() > 0.001) {
        debugPrint(
          'WalletRepository: Syncing balance for $userId: ${wallet.balanceRc} -> $blockchainBalance',
        );
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': blockchainBalance,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);

        // Return fresh wallet
        final updatedWallet = await getWallet(userId);
        return updatedWallet ?? wallet.copyWith(balanceRc: blockchainBalance);
      }

      return wallet;
    } catch (e) {
      debugPrint('WalletRepository: Error syncing wallet balance: $e');
      // On error, return existing wallet data rather than crashing
      final wallet = await getWallet(userId);
      return wallet ?? (throw e);
    }
  }

  bool _isValidAddress(String address) {
    final evmAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return evmAddressRegex.hasMatch(address);
  }

  bool _isPlaceholderAddress(String address) {
    return address.startsWith('PENDING_ACTIVATION_');
  }

  /// Safely parse dynamic numeric values from API/Supabase responses.
  double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Try common balance keys returned by wallet and reward endpoints.
  double? _extractBalanceFromResponse(Map<String, dynamic> response) {
    const candidateKeys = [
      'balanceRc',
      'balance',
      'newBalance',
      'remainingBalance',
      'walletBalance',
    ];

    for (final key in candidateKeys) {
      if (response[key] != null) {
        return _parseDouble(response[key]);
      }
    }
    return null;
  }

  Future<Wallet> _repairWallet(String userId) async {
    // 1. Create new blockchain wallet
    final walletData = await _rookenService.createWallet();
    final address = walletData['address'] as String;
    final privateKey = walletData['privateKey'] as String;

    // 2. Store new private key
    await _secureStorage.write('wallet_private_key_$userId', privateKey);

    // 3. Backup key
    await _backupKey(userId, address, privateKey);

    // 3. Try to update wallet entry in Supabase
    try {
      // Fetch existing wallet to preserve balance and log the old address for recovery
      final existingWallet = await getWallet(userId);
      final double currentBalance = existingWallet?.balanceRc ?? 0;
      final double currentLifetimeEarned =
          existingWallet?.lifetimeEarnedRc ?? 0;
      final double currentLifetimeSpent = existingWallet?.lifetimeSpentRc ?? 0;
      final String? oldAddress = existingWallet?.walletAddress;

      if (oldAddress != null) {
        debugPrint(
          'WalletRepository: PERMANENTLY MOVING from old address $oldAddress to new address $address. Balance $currentBalance will be tracked in DB but old on-chain funds may be lost if key not backed up.',
        );
      }

      // Use upsert to be robust against RLS constraints
      await _supabase
          .from('wallets')
          .upsert({
            'user_id': userId,
            'wallet_address': address,
            'balance_rc':
                currentBalance, // PRESERVE BALANCE instead of resetting to 0
            'lifetime_earned_rc': currentLifetimeEarned,
            'lifetime_spent_rc': currentLifetimeSpent,
            'pending_balance_rc': 0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // 4. Award welcome bonus (force it, since this is a repair/reset) — disabled under new activation flow
      if (_enableWelcomeBonus) {
        try {
          await checkAndAwardWelcomeBonus(userId, address: address, force: true);
        } catch (e) {
          debugPrint('Failed to award welcome bonus during repair: $e');
          // Continue even if bonus fails
        }
      }

      // Fetch fresh to get updated balance
      final freshWallet = await getWallet(userId);
      return freshWallet!;
    } catch (e, stack) {
      debugPrint(
        'WalletRepository: Error during wallet repair for $userId: $e',
      );
      // If DB update fails, we are in a bad state (Key changed, DB not).
      // But we must return something usable to the UI.
      // Re-fetch existing wallet and patch address?
      final existingWallet = await getWallet(userId);
      if (existingWallet != null) {
        return existingWallet.copyWith(walletAddress: address, balanceRc: 100);
      }
      throw e.toAppException(stack);
    }
  }

  /// Spend ROOK for platform actions (e.g., creating a post)
  Future<Map<String, dynamic>> spendRoo({
    required String userId,
    required double amount,
    required String activityType,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await _spendRooInternal(
        userId: userId,
        amount: amount,
        activityType: activityType,
        referencePostId: referencePostId,
        referenceCommentId: referenceCommentId,
        metadata: metadata,
      );
    } catch (e) {
      // Catch \"Insufficient balance\" specifically
      if (e.toString().contains('Insufficient balance') ||
          e.toString().contains('400')) {
        // Check if we suspect a syncing issue (Local balance says YES, Server says NO)
        final wallet = await getWallet(userId);
        if (wallet != null && wallet.balanceRc >= amount) {
          debugPrint(
            'WalletRepository: Balance mismatch detected (Local: ${wallet.balanceRc}, Remote: 0). Attempting repair...',
          );

          try {
            // Force repair
            await _repairWalletLocked(userId);

            // Retry spend once
            debugPrint('WalletRepository: Repair complete. Retrying spend...');
            return await _spendRooInternal(
              userId: userId,
              amount: amount,
              activityType: activityType,
              referencePostId: referencePostId,
              referenceCommentId: referenceCommentId,
              metadata: metadata,
            );
          } catch (retryError) {
            debugPrint(
              'WalletRepository: Retry after repair failed: $retryError',
            );
            throw retryError; // Throw the new error
          }
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _spendRooInternal({
    required String userId,
    required double amount,
    required String activityType,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Get wallet and private key (using getOrCreateWallet for automatic repair)
    final wallet = await getOrCreateWallet(userId);

    if (wallet.isFrozen) {
      throw Exception('Wallet is frozen: ${wallet.frozenReason}');
    }

    if (wallet.balanceRc < amount) {
      throw Exception('Insufficient balance');
    }

    final privateKey = await _secureStorage.read('wallet_private_key_$userId');
    if (privateKey == null) {
      throw Exception('Private key not found');
    }

    // 2. Execute spend transaction on blockchain
    final result = await _rookenService.spend(
      userPrivateKey: privateKey,
      amount: amount,
      activityType: activityType,
      metadata: metadata,
    );

    // 3. Record transaction in database
    await _supabase.from('roocoin_transactions').insert({
      'tx_type': 'fee',
      'status': 'completed',
      'from_user_id': userId,
      'amount_rc': amount,
      'reference_post_id': referencePostId,
      'reference_comment_id': referenceCommentId,
      'tx_hash': result['transactionHash'],
      'metadata': {'activityType': activityType, ...?metadata},
      'completed_at': DateTime.now().toIso8601String(),
    });

    // 4. Update wallet balance
    final newBalance = _parseDouble(result['remainingBalance']);
    await _supabase
        .from('wallets')
        .update({
          'balance_rc': newBalance,
          'lifetime_spent_rc': wallet.lifetimeSpentRc + amount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);

    return result;
  }

  /// Check if a reward has already been awarded for a specific activity
  /// Returns true if reward already exists, false otherwise
  Future<bool> _hasRewardBeenAwarded({
    required String userId,
    required String activityType,
    String? referencePostId,
    String? referenceCommentId,
  }) async {
    try {
      // 1. Skip check for repeating activities (e.g. Daily Login)
      // These are handled by their own services with date-range logic
      if (activityType == RookenActivityType.dailyLogin) {
        return false;
      }

      // 2. For content-based rewards, we MUST have a reference ID to check for duplicates
      // If no reference ID is provided for content rewards, we allow it (fail open)
      // but warn in debug mode.
      final isContentReward = [
        RookenActivityType.postCreate,
        RookenActivityType.postComment,
        RookenActivityType.postLike,
        RookenActivityType.postShare,
        RookenActivityType.contentViral,
      ].contains(activityType);

      if (isContentReward &&
          referencePostId == null &&
          referenceCommentId == null) {
        debugPrint(
          'WalletRepository: Content reward requested without reference ID. Skipping duplication check.',
        );
        return false;
      }

      // 3. Build query to check for existing reward
      var query = _supabase
          .from('roocoin_transactions')
          .select('id, metadata')
          .eq('to_user_id', userId)
          .eq('tx_type', 'engagement_reward');

      // Add reference filters if provided
      if (referencePostId != null) {
        query = query.eq('reference_post_id', referencePostId);
      }
      if (referenceCommentId != null) {
        query = query.eq('reference_comment_id', referenceCommentId);
      }

      final results = await query;

      // Check if any result has matching activityType in metadata
      for (final row in (results as List)) {
        final metadata = row['metadata'];
        if (metadata is Map && metadata['activityType'] == activityType) {
          // If we have a reference ID, it's a definite duplicate
          if (referencePostId != null || referenceCommentId != null) {
            return true;
          }

          // For strictly one-time rewards without reference IDs
          if (activityType == RookenActivityType.profileComplete ||
              activityType == RookenActivityType.welcomeBonus) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for existing reward: $e');
      // On error, assume not awarded to avoid blocking legitimate rewards
      return false;
    }
  }

  /// Earn ROOK for platform activities
  /// Includes deduplication check to prevent awarding the same reward twice
  Future<Map<String, dynamic>> earnRoo({
    required String userId,
    required String activityType,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 0. Check for duplicate rewards (critical for POST_CREATE and POST_COMMENT)
      final alreadyAwarded = await _hasRewardBeenAwarded(
        userId: userId,
        activityType: activityType,
        referencePostId: referencePostId,
        referenceCommentId: referenceCommentId,
      );

      if (alreadyAwarded) {
        debugPrint(
          'WalletRepository: Skipping duplicate reward - userId=$userId, activityType=$activityType',
        );
        // Return a success response without awarding
        return {
          'success': true,
          'duplicate': true,
          'message': 'Reward already awarded',
        };
      }

      // 1. Get wallet (using getOrCreateWallet for automatic repair)
      final wallet = await getOrCreateWallet(userId);

      // 2. Distribute reward via Rooken API
      if (!_isValidAddress(wallet.walletAddress)) {
        throw Exception('Invalid wallet address: ${wallet.walletAddress}');
      }

      final result = await _rookenService.distributeReward(
        userAddress: wallet.walletAddress,
        activityType: activityType,
        metadata: metadata,
      );

      // Handle response format change: API returns 'amount', previously 'reward'
      final rawAmount = result['amount'] ?? result['reward'];
      if (rawAmount == null) {
        // Fallback or just log if neither exists, though one should.
        debugPrint(
          'Warning: No amount/reward field in distributeReward response: $result',
        );
      }
      final rewardAmount = _parseDouble(rawAmount);

      // Prefer API-reported post-reward balance.
      // If the reward endpoint doesn't include balance, fetch it directly.
      double? authoritativeBalance = _extractBalanceFromResponse(result);
      if (authoritativeBalance == null) {
        try {
          final balanceData = await _rookenService.getBalance(
            wallet.walletAddress,
          );
          authoritativeBalance = _extractBalanceFromResponse(balanceData);
        } catch (e) {
          debugPrint(
            'WalletRepository: Could not fetch authoritative balance after reward: $e',
          );
        }
      }

      // 3. Record transaction in database
      await _supabase.from('roocoin_transactions').insert({
        'tx_type': 'engagement_reward',
        'status': 'completed',
        'to_user_id': userId,
        'amount_rc': rewardAmount,
        'reference_post_id': referencePostId,
        'reference_comment_id': referenceCommentId,
        'tx_hash': result['transactionHash'],
        'metadata': {'activityType': activityType, ...?metadata},
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 3b. Update daily reward summary
      try {
        await _supabase.rpc(
          'record_roocoin_daily_reward',
          params: {
            'p_user_id': userId,
            'p_activity_type': activityType,
            'p_amount': rewardAmount,
          },
        );
      } catch (e) {
        debugPrint('Error recording daily reward summary: $e');
      }

      // 4. Update wallet balance atomically (PREVENTS RACE CONDITIONS)
      try {
        await _supabase.rpc(
          'record_roocoin_reward_atomic',
          params: {
            'p_user_id': userId,
            'p_amount': rewardAmount,
            'p_activity_type': activityType,
          },
        );
      } catch (e) {
        debugPrint(
          'WalletRepository: Error in atomic balance update, falling back to legacy update: $e',
        );
        // FALLBACK to legacy update if RPC is not yet deployed
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': authoritativeBalance ?? (wallet.balanceRc + rewardAmount),
              'lifetime_earned_rc': wallet.lifetimeEarnedRc + rewardAmount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      }

      // Final reconciliation so DB balance matches API wallet balance.
      if (authoritativeBalance != null) {
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': authoritativeBalance,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      }

      debugPrint(
        'WalletRepository: Reward awarded successfully - userId=$userId, '
        'activityType=$activityType, amount=$rewardAmount ROO',
      );

      return result;
    } catch (e) {
      debugPrint('Error earning ROOK: $e');
      rethrow;
    }
  }

  /// Check if user has received their welcome bonus and award it if not
  /// This handles both new users and existing users from before Rooken
  Future<bool> checkAndAwardWelcomeBonus(
    String userId, {
    String? address,
    bool force = false,
  }) async {
    try {
      // 1. Check if already awarded in transactions
      // We fetch relevant transactions and check in Dart to avoid JSON filtering issues
      final existingTxs = await _supabase
          .from('roocoin_transactions')
          .select('metadata')
          .eq('to_user_id', userId)
          .eq('tx_type', 'engagement_reward');

      final hasBonus = existingTxs.any((tx) {
        final metadata = tx['metadata'];
        if (metadata is Map) {
          final type = metadata['activityType'] ?? metadata['source'];
          return type == RookenActivityType.welcomeBonus ||
              type == 'WELCOME_BONUS';
        }
        return false;
      });

      if (hasBonus && !force) {
        return false;
      }

      // If they already have a significant balance, they likely already got a bonus
      // even if transaction logs are missing (e.g. legacy users)
      if (hasBonus && force) {
        debugPrint(
          'WalletRepository: User already has Welcome Bonus in history. Skipping even if forced to avoid inflation.',
        );
        return false;
      }

      // 2. Get wallet address if not provided
      String? walletAddress = address;
      if (walletAddress == null) {
        final wallet = await getWallet(userId);
        if (wallet == null) return false; // No wallet to award to
        walletAddress = wallet.walletAddress;
      }

      // 3. Award reward via Rooken API Faucet (gives 100 ROOK)
      if (!_isValidAddress(walletAddress)) {
        debugPrint('Skipping welcome bonus: Invalid address $walletAddress');
        return false;
      }

      final result = await _rookenService.requestFaucet(
        address: walletAddress,
        amount: 100.0,
      );

      final rewardAmount = _parseDouble(result['amount']);

      // 4. Record transaction in database
      await _supabase.from('roocoin_transactions').insert({
        'tx_type': 'engagement_reward',
        'status': 'completed',
        'to_user_id': userId,
        'amount_rc': rewardAmount,
        'tx_hash': result['transactionHash'],
        'metadata': {
          'activityType': RookenActivityType.welcomeBonus,
          'source': 'faucet',
        },
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 5. Update wallet balance atomically
      try {
        await _supabase.rpc(
          'record_roocoin_reward_atomic',
          params: {
            'p_user_id': userId,
            'p_amount': rewardAmount,
            'p_activity_type': RookenActivityType.welcomeBonus,
          },
        );
      } catch (e) {
        debugPrint(
          'WalletRepository: Error in atomic welcome bonus update, falling back: $e',
        );
        final currentWallet = await getWallet(userId);
        if (currentWallet != null) {
          await _supabase
              .from('wallets')
              .update({
                'balance_rc': currentWallet.balanceRc + rewardAmount,
                'lifetime_earned_rc':
                    currentWallet.lifetimeEarnedRc + rewardAmount,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error awarding welcome bonus: $e');
      return false;
    }
  }

  /// Transfer ROOK to another user or external wallet
  Future<Map<String, dynamic>> transferToExternal({
    required String userId,
    required String toAddress,
    required double amount,
    double fee = 0.0,
    String? memo,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Get wallet and validate
      final wallet = await getOrCreateWallet(userId);

      if (wallet.isFrozen) {
        throw Exception('Wallet is frozen: ${wallet.frozenReason}');
      }

      if (_isPlaceholderAddress(toAddress)) {
        throw Exception('Recipient wallet not activated');
      }

      if (!_isValidAddress(toAddress)) {
        throw Exception('Invalid recipient wallet address');
      }

      final totalDeducted = amount + fee;
      if (wallet.balanceRc < totalDeducted) {
        throw Exception('Insufficient balance');
      }

      if (wallet.remainingDailyLimit < totalDeducted) {
        throw Exception('Daily transfer limit exceeded');
      }

      final privateKey = await _secureStorage.read(
        'wallet_private_key_$userId',
      );
      if (privateKey == null) {
        throw Exception('Private key not found');
      }

      // 2. Check if recipient is a platform user (for in-app transfers)
      String? recipientUserId;
      try {
        final recipientWallet = await _supabase
            .from('wallets')
            .select('user_id, balance_rc, lifetime_earned_rc')
            .eq('wallet_address', toAddress)
            .maybeSingle();

        if (recipientWallet != null) {
          recipientUserId = recipientWallet['user_id'] as String;
        }
      } catch (e) {
        debugPrint('Error checking recipient: $e');
      }

      // 3. Execute transfer on blockchain using the new peer-to-peer endpoint
      final result = await _rookenService.send(
        fromPrivateKey: privateKey,
        toAddress: toAddress,
        amount: amount,
        metadata: memo != null ? {'note': memo} : null,
      );

      final txHash = result['transactionHash'] as String?;

      // 4, 5, 6. Perform database updates and notifications in the background.
      // This allows the UI to show 'Success' immediately after the blockchain confirms.
      _performBackgroundPostTransferUpdates(
        userId: userId,
        recipientUserId: recipientUserId,
        toAddress: toAddress,
        amount: amount,
        fee: fee,
        txHash: txHash,
        memo: memo,
        referencePostId: referencePostId,
        referenceCommentId: referenceCommentId,
        metadata: metadata,
        result: result,
        wallet: wallet,
      );

      return result;
    } catch (e) {
      debugPrint('Error transferring ROOK: $e');
      rethrow;
    }
  }

  /// Performs post-transfer database updates and notifications in the background.
  void _performBackgroundPostTransferUpdates({
    required String userId,
    required String? recipientUserId,
    required String toAddress,
    required double amount,
    required double fee,
    required String? txHash,
    required String? memo,
    required String? referencePostId,
    required String? referenceCommentId,
    required Map<String, dynamic>? metadata,
    required Map<String, dynamic> result,
    required Wallet wallet,
  }) async {
    try {
      String? recipientDisplayName;
      String? recipientUsername;
      double? recipientBalanceBefore;
      double? recipientBalanceAfter;
      if (recipientUserId != null) {
        try {
          final recipientProfile = await _supabase
              .from('profiles')
              .select('display_name, username')
              .eq('user_id', recipientUserId)
              .maybeSingle();
          recipientDisplayName = recipientProfile?['display_name'] as String?;
          recipientUsername = recipientProfile?['username'] as String?;
        } catch (_) {
          // Non-critical; fallback labels still apply in UI.
        }
        try {
          final recipientWallet = await _supabase
              .from('wallets')
              .select('balance_rc')
              .eq('user_id', recipientUserId)
              .maybeSingle();
          recipientBalanceBefore =
              _parseDouble(recipientWallet?['balance_rc']) ?? 0.0;
          recipientBalanceAfter = recipientBalanceBefore + amount;
        } catch (_) {
          // Non-critical; receiver balance details can be omitted in UI.
        }
      }

      double? newBalance;
      if (result['remainingBalance'] != null) {
        newBalance = _parseDouble(result['remainingBalance']);
      }
      final senderBalanceBefore = wallet.balanceRc;
      final senderBalanceAfter =
          newBalance ??
          (senderBalanceBefore - amount).clamp(0.0, double.infinity).toDouble();

      // 1. Record the transfer transaction in the database
      await _supabase.from('roocoin_transactions').insert({
        'tx_type': 'transfer',
        'status': 'completed',
        'from_user_id': userId,
        'to_user_id': recipientUserId,
        'amount_rc': amount,
        'reference_post_id': referencePostId,
        'reference_comment_id': referenceCommentId,
        'memo': memo,
        'tx_hash': txHash,
        'metadata': {
          'toAddress': toAddress,
          'fromAddress': wallet.walletAddress,
          'direction': recipientUserId != null ? 'internal' : 'outgoing',
          'recipientDisplayName': recipientDisplayName,
          'recipientUsername': recipientUsername,
          'balanceBeforeRc': senderBalanceBefore,
          'balanceAfterRc': senderBalanceAfter,
          'receiverBalanceBeforeRc': recipientBalanceBefore,
          'receiverBalanceAfterRc': recipientBalanceAfter,
          ...?metadata,
        },
        'completed_at': DateTime.now().toIso8601String(),
      });

      await _activityLogService.log(
        userId: userId,
        activityType: 'transaction',
        targetType: 'wallet',
        targetId: recipientUserId,
        description: 'Sent ROO',
        metadata: {
          'direction': recipientUserId != null ? 'internal' : 'external',
          'to_user_id': recipientUserId,
          'to_address': toAddress,
          'amount_rc': amount,
          'fee_rc': fee,
          'tx_hash': txHash,
          'memo': memo,
          'reference_post_id': referencePostId,
          'reference_comment_id': referenceCommentId,
        },
      );

      // 1b. Record the withdrawal fee as a separate fee transaction
      if (fee > 0) {
        await _supabase.from('roocoin_transactions').insert({
          'tx_type': 'fee',
          'status': 'completed',
          'from_user_id': userId,
          'amount_rc': fee,
          'memo': 'Withdrawal fee (1%)',
          'tx_hash': txHash,
          'metadata': {
            'feeType': 'withdrawal',
            'feeRate': '1%',
            'transferAmount': amount,
            'fromAddress': wallet.walletAddress,
            'activityType': 'WITHDRAWAL_FEE',
          },
          'completed_at': DateTime.now().toIso8601String(),
        });
      }

      // 2. Update sender's wallet balance (deduct amount + fee)
      final totalDeducted = amount + fee;
      if (newBalance != null) {
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': newBalance - fee,
              'daily_sent_today_rc': wallet.dailySentTodayRc + totalDeducted,
              'lifetime_spent_rc': wallet.lifetimeSpentRc + totalDeducted,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } else {
        await _supabase.rpc(
          'update_wallet_balance_atomic',
          params: {
            'p_user_id': userId,
            'p_delta': -totalDeducted,
            'p_spent_delta': totalDeducted,
          },
        );

        await _supabase
            .from('wallets')
            .update({'daily_sent_today_rc': wallet.dailySentTodayRc + totalDeducted})
            .eq('user_id', userId);
      }

      // 3. Update recipient balance and notify
      if (recipientUserId != null) {
        try {
          await _supabase.rpc(
            'update_wallet_balance_atomic',
            params: {
              'p_user_id': recipientUserId,
              'p_delta': amount,
              'p_earned_delta': amount,
            },
          );

          final senderProfile = await _supabase
              .from('profiles')
              .select('username, display_name')
              .eq('user_id', userId)
              .maybeSingle();

          final senderName =
              senderProfile?['display_name'] ??
              senderProfile?['username'] ??
              'Someone';

          await _supabase.from('notifications').insert({
            'user_id': recipientUserId,
            'type': 'roocoin_received',
            'title': 'ROO Received!',
            'body': '$senderName sent you ${amount.toStringAsFixed(2)} ROO',
            'actor_id': userId,
            'metadata': {
              'amount': amount,
              'from_user_id': userId,
              'tx_hash': txHash,
            },
          });
        } catch (e) {
          debugPrint('Error in recipient background update: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in background transfer updates: $e');
    }
  }

  /// Get transaction history for a user
  Future<List<RookenTransaction>> getTransactions({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('roocoin_transactions')
          .select()
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<RookenTransaction> txs = (response as List)
          .map((json) => RookenTransaction.fromSupabase(json))
          .toList();

      // Deduplicate by txHash if present (prevents double-showing of legacy logic records)
      final Set<String> seenHashes = {};
      final List<RookenTransaction> uniqueTxs = [];

      for (final tx in txs) {
        if (tx.txHash != null && tx.txHash!.isNotEmpty) {
          if (!seenHashes.contains(tx.txHash)) {
            seenHashes.add(tx.txHash!);
            uniqueTxs.add(tx);
          }
        } else {
          uniqueTxs.add(tx);
        }
      }

      return uniqueTxs;
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }

  /// Backup key to DB (encrypted by server-side key or just stored for recovery)
  /// In this custodial model, we store it so the user can log in on another device.
  Future<void> _backupKey(
    String userId,
    String address,
    String privateKey,
  ) async {
    final now = DateTime.now().toIso8601String();

    // Primary schema (current): user_wallet_keys.encrypted_private_key
    try {
      await _supabase.from(_walletKeysTable).upsert({
        'user_id': userId,
        'wallet_address': address,
        'encrypted_private_key':
            privateKey, // Ideally, you'd encrypt this client-side too
        'updated_at': now,
      });
    } catch (e) {
      debugPrint('Error backing up key to $_walletKeysTable: $e');
    }

    // Legacy compatibility: wallet_backups.encrypted_key
    try {
      await _supabase.from(_legacyWalletBackupsTable).upsert({
        'user_id': userId,
        'wallet_address': address,
        'encrypted_key': privateKey,
        'updated_at': now,
      });
    } catch (e) {
      debugPrint(
        'Error backing up key to $_legacyWalletBackupsTable (non-critical): $e',
      );
    }
  }

  /// Ensure user_wallet_keys has a row for this user when we already have
  /// a local secure-storage key.
  Future<void> _ensurePrimaryKeyBackup(
    String userId, {
    String? walletAddress,
  }) async {
    try {
      final localKey = await _secureStorage.read('wallet_private_key_$userId');
      if (localKey == null || localKey.isEmpty) return;

      String? address = walletAddress;
      if (address == null || address.isEmpty) {
        final wallet = await getWallet(userId);
        address = wallet?.walletAddress;
      }
      if (address == null || address.isEmpty) return;

      await _supabase.from(_walletKeysTable).upsert({
        'user_id': userId,
        'wallet_address': address,
        'encrypted_private_key': localKey,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('WalletRepository: ensure key backup failed for $userId: $e');
    }
  }

  /// Restore key from DB
  Future<bool> _restoreKey(String userId) async {
    try {
      // 1) Try current schema first
      try {
        final response = await _supabase
            .from(_walletKeysTable)
            .select('encrypted_private_key, wallet_address')
            .eq('user_id', userId)
            .maybeSingle();

        final key = response?['encrypted_private_key'] as String?;
        if (key != null && key.isNotEmpty) {
          await _secureStorage.write('wallet_private_key_$userId', key);
          return true;
        }
      } catch (e) {
        debugPrint('Error restoring key from $_walletKeysTable: $e');
      }

      // 2) Fallback to legacy schema
      try {
        final response = await _supabase
            .from(_legacyWalletBackupsTable)
            .select('encrypted_key, wallet_address')
            .eq('user_id', userId)
            .maybeSingle();

        final key = response?['encrypted_key'] as String?;
        if (key != null && key.isNotEmpty) {
          await _secureStorage.write('wallet_private_key_$userId', key);

          // Promote legacy backup row to primary schema.
          final legacyAddress = response?['wallet_address'] as String?;
          String? address = legacyAddress;
          if (address == null || address.isEmpty) {
            final wallet = await getWallet(userId);
            address = wallet?.walletAddress;
          }
          if (address != null && address.isNotEmpty) {
            await _supabase.from(_walletKeysTable).upsert({
              'user_id': userId,
              'wallet_address': address,
              'encrypted_private_key': key,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
          return true;
        }
      } catch (e) {
        debugPrint(
          'Error restoring key from $_legacyWalletBackupsTable (fallback): $e',
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error restoring key: $e');
      return false;
    }
  }
}
