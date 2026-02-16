import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet.dart';
import '../services/rooken_service.dart';
import '../services/secure_storage_service.dart';
import '../core/extensions/exception_extensions.dart';

/// Repository for managing wallet data and Rooken integration
class WalletRepository {
  final SupabaseClient _supabase;
  final RookenService _rookenService;
  final SecureStorageService _secureStorage;

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

      // 4. Award welcome bonus (100 ROOK)
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

      return Wallet.fromSupabase(response);
    } catch (e) {
      debugPrint('Error creating wallet: $e');
      rethrow;
    }
  }

  /// Get or create wallet for a user
  Future<Wallet> getOrCreateWallet(String userId) async {
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
          return await _repairWallet(userId);
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
      return await _repairWallet(userId);
    }

    if (wallet != null) return wallet;
    return await createWallet(userId);
  }

  bool _isValidAddress(String address) {
    final evmAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return evmAddressRegex.hasMatch(address);
  }

  bool _isPlaceholderAddress(String address) {
    return address.startsWith('PENDING_ACTIVATION_');
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

      // 4. Award welcome bonus (force it, since this is a repair/reset)
      try {
        await checkAndAwardWelcomeBonus(userId, address: address, force: true);
      } catch (e) {
        debugPrint('Failed to award welcome bonus during repair: $e');
        // Continue event if bonus fails
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
      // Catch "Insufficient balance" specifically
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
            await _repairWallet(userId);

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
    final newBalance = double.parse(result['remainingBalance'] as String);
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
      final rewardAmount = double.parse((rawAmount ?? 0).toString());

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
              'balance_rc': wallet.balanceRc + rewardAmount,
              'lifetime_earned_rc': wallet.lifetimeEarnedRc + rewardAmount,
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

      final rewardAmount = double.parse(result['amount'].toString());

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

      if (wallet.balanceRc < amount) {
        throw Exception('Insufficient balance');
      }

      if (wallet.remainingDailyLimit < amount) {
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

      // 4. Record outgoing transaction for sender
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
          'direction': 'outgoing',
          ...?metadata,
        },
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 5. Update sender's wallet balance and daily limit.
      // CRITICAL: Deduct the sent amount from sender's balance
      debugPrint(
        'WalletRepository: SENDER BEFORE - Balance: ${wallet.balanceRc} ROO',
      );

      // 5. Update sender's wallet balance and daily limit atomically
      // Prefers remainingBalance from API if available; otherwise fall back to chain balance.
      double? newBalance;
      if (result['remainingBalance'] != null) {
        newBalance = double.parse(result['remainingBalance'] as String);
      }

      if (newBalance != null) {
        // If we have an absolute new balance from API, we use it directly
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': newBalance,
              'daily_sent_today_rc': wallet.dailySentTodayRc + amount,
              'lifetime_spent_rc': wallet.lifetimeSpentRc + amount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } else {
        // Fallback to atomic delta update
        debugPrint(
          'WalletRepository: sender balance update using atomic delta',
        );
        await _supabase.rpc(
          'update_wallet_balance_atomic',
          params: {
            'p_user_id': userId,
            'p_delta': -amount,
            'p_spent_delta': amount,
          },
        );

        // Also update daily limit record
        await _supabase
            .from('wallets')
            .update({'daily_sent_today_rc': wallet.dailySentTodayRc + amount})
            .eq('user_id', userId);
      }

      // 6. If recipient is a platform user, update their balance and record incoming transaction
      if (recipientUserId != null) {
        try {
          // Record incoming transaction for recipient
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
              'fromAddress': wallet.walletAddress,
              'direction': 'incoming',
              ...?metadata,
            },
            'completed_at': DateTime.now().toIso8601String(),
          });

          // 6b. Update recipient's wallet balance atomically
          try {
            await _supabase.rpc(
              'update_wallet_balance_atomic',
              params: {
                'p_user_id': recipientUserId,
                'p_delta': amount,
                'p_earned_delta': amount,
              },
            );
            debugPrint(
              'WalletRepository: Recipient balance updated atomically',
            );
          } catch (e) {
            debugPrint(
              'WalletRepository: Atomic recipient update failed, using fallback: $e',
            );
            // Recipient fallback
            final recipientWallet = await _supabase
                .from('wallets')
                .select('balance_rc, lifetime_earned_rc')
                .eq('user_id', recipientUserId)
                .single();

            await _supabase
                .from('wallets')
                .update({
                  'balance_rc':
                      (recipientWallet['balance_rc'] as num).toDouble() +
                      amount,
                  'lifetime_earned_rc':
                      (recipientWallet['lifetime_earned_rc'] as num)
                          .toDouble() +
                      amount,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', recipientUserId);
          }

          // Send notification to recipient
          try {
            // Get sender's username for notification
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
              'body': '$senderName sent you ${amount.toStringAsFixed(2)} ROOK',
              'actor_id': userId,
              'metadata': {
                'amount': amount,
                'from_user_id': userId,
                'tx_hash': txHash,
              },
            });
          } catch (e) {
            debugPrint('Error sending transfer notification: $e');
          }

          debugPrint(
            'In-app transfer: Updated recipient $recipientUserId balance (+$amount ROOK)',
          );
        } catch (e) {
          debugPrint('Error updating recipient wallet: $e');
          // Don't fail the transfer if recipient update fails - blockchain transfer succeeded
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error transferring ROOK: $e');
      rethrow;
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

      return (response as List)
          .map((json) => RookenTransaction.fromSupabase(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }

  /// Sync wallet balance from blockchain
  Future<Wallet> syncBalance(String userId) async {
    try {
      final wallet = await getWallet(userId);
      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      // Validate address before calling blockchain
      if (!_isValidAddress(wallet.walletAddress)) {
        debugPrint(
          'WalletRepository: Skipping balance sync: Invalid address ${wallet.walletAddress}',
        );
        return wallet;
      }

      debugPrint(
        'WalletRepository: Fetching blockchain balance for ${wallet.walletAddress}...',
      );

      // Get balance from blockchain
      final balanceData = await _rookenService.getBalance(wallet.walletAddress);

      debugPrint('WalletRepository: Raw balance response: $balanceData');

      final blockchainBalance = double.parse(balanceData['balance'] as String);

      debugPrint(
        'WalletRepository: Blockchain balance: $blockchainBalance, DB balance: ${wallet.balanceRc}',
      );

      // Update database
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': blockchainBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      debugPrint(
        'WalletRepository: Updated DB with blockchain balance: $blockchainBalance',
      );

      return wallet.copyWith(balanceRc: blockchainBalance);
    } catch (e) {
      debugPrint('WalletRepository: Error syncing balance: $e');
      rethrow;
    }
  }

  /// Check if Rooken API is healthy
  Future<bool> checkApiHealth() async {
    try {
      final health = await _rookenService.checkHealth();
      return health['status'] == 'ok';
    } catch (e) {
      debugPrint('Rooken API health check failed: $e');
      return false;
    }
  }

  /// Backup key to DB for recovery
  Future<void> _backupKey(
    String userId,
    String address,
    String privateKey,
  ) async {
    try {
      await _supabase.from('user_wallet_keys').upsert({
        'user_id': userId,
        'wallet_address': address,
        'encrypted_private_key': privateKey,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('WalletRepository: Failed to backup key to DB: $e');
    }
  }

  /// Restore key from DB
  Future<bool> _restoreKey(String userId) async {
    try {
      final response = await _supabase
          .from('user_wallet_keys')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final privateKey = response['encrypted_private_key'] as String;
        await _secureStorage.write('wallet_private_key_$userId', privateKey);
        debugPrint('WalletRepository: Key restored from DB backup');
        return true;
      }
    } catch (e) {
      debugPrint('WalletRepository: Failed to restore key from DB: $e');
    }
    return false;
  }
}
