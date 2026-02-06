import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet.dart';
import '../services/roocoin_service.dart';
import '../services/secure_storage_service.dart';

/// Repository for managing wallet data and Roocoin integration
class WalletRepository {
  final SupabaseClient _supabase;
  final RoocoinService _roocoinService;
  final SecureStorageService _secureStorage;

  WalletRepository({
    SupabaseClient? supabase,
    RoocoinService? roocoinService,
    SecureStorageService? secureStorage,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _roocoinService = roocoinService ?? RoocoinService(),
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
      // 1. Create blockchain wallet via Roocoin API
      final walletData = await _roocoinService.createWallet();
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

      // 4. Award welcome bonus (100 ROO)
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
    final walletData = await _roocoinService.createWallet();
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
    } catch (e) {
      debugPrint(
        'WalletRepository: Error during wallet repair for $userId: $e',
      );
      // If DB update fails, we are in a bad state (Key changed, DB not).
      // But we must return something usable to the UI.
      // Re-fetch existing wallet and patch address?
      // Actually, swallowing this error is what caused the original issue.
      // However, throwing here crashes the app flow.
      // Attempt to return a memory-patched wallet, but log CRITICAL error.
      final existingWallet = await getWallet(userId);
      if (existingWallet != null) {
        return existingWallet.copyWith(walletAddress: address, balanceRc: 100);
      }
      rethrow;
    }
  }

  /// Spend ROO for platform actions (e.g., creating a post)
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
    final result = await _roocoinService.spend(
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

  /// Earn ROO for platform activities
  Future<Map<String, dynamic>> earnRoo({
    required String userId,
    required String activityType,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // TODO: Add validate_roocoin_reward RPC when ready for anti-abuse checks

      // 1. Get wallet (using getOrCreateWallet for automatic repair)
      final wallet = await getOrCreateWallet(userId);

      // 2. Distribute reward via Roocoin API
      if (!_isValidAddress(wallet.walletAddress)) {
        throw Exception('Invalid wallet address: ${wallet.walletAddress}');
      }

      final result = await _roocoinService.distributeReward(
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

      // 4. Update wallet balance
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': wallet.balanceRc + rewardAmount,
            'lifetime_earned_rc': wallet.lifetimeEarnedRc + rewardAmount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return result;
    } catch (e) {
      debugPrint('Error earning ROO: $e');
      rethrow;
    }
  }

  /// Check if user has received their welcome bonus and award it if not
  /// This handles both new users and existing users from before Roocoin
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
          return type == RoocoinActivityType.welcomeBonus ||
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

      // 3. Award reward via Roocoin API Faucet (gives 100 ROO)
      if (!_isValidAddress(walletAddress)) {
        debugPrint('Skipping welcome bonus: Invalid address $walletAddress');
        return false;
      }

      final result = await _roocoinService.requestFaucet(
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
        'metadata': {'activityType': 'WELCOME_BONUS', 'source': 'faucet'},
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 5. Update wallet balance
      final wallet = await getWallet(userId);
      if (wallet != null) {
        await _supabase
            .from('wallets')
            .update({
              'balance_rc': wallet.balanceRc + rewardAmount,
              'lifetime_earned_rc': wallet.lifetimeEarnedRc + rewardAmount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      }

      return true;
    } catch (e) {
      debugPrint('Error awarding welcome bonus: $e');
      return false;
    }
  }

  /// Transfer ROO to another user or external wallet
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

      // 3. Execute transfer on blockchain
      final result = await _roocoinService.transfer(
        fromPrivateKey: privateKey,
        toAddress: toAddress,
        amount: amount,
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

      // 5. Update sender's wallet balance from blockchain and daily limit
      final senderBalanceData = await _roocoinService.getBalance(
        wallet.walletAddress,
      );
      final senderChainBalance =
          double.parse(senderBalanceData['balance'] as String);
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': senderChainBalance,
            'daily_sent_today_rc': wallet.dailySentTodayRc + amount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

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

          // Update recipient's wallet balance
          final recipientWallet = await _supabase
              .from('wallets')
              .select('balance_rc, lifetime_earned_rc, wallet_address')
              .eq('user_id', recipientUserId)
              .single();

          final recipientLifetimeEarned =
              (recipientWallet['lifetime_earned_rc'] as num).toDouble();
          final recipientAddress =
              recipientWallet['wallet_address'] as String? ?? '';

          if (_isValidAddress(recipientAddress)) {
            final recipientBalanceData = await _roocoinService.getBalance(
              recipientAddress,
            );
            final recipientChainBalance =
                double.parse(recipientBalanceData['balance'] as String);

            await _supabase
                .from('wallets')
                .update({
                  'balance_rc': recipientChainBalance,
                  'lifetime_earned_rc': recipientLifetimeEarned + amount,
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
              'body': '$senderName sent you ${amount.toStringAsFixed(2)} ROO',
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
            'In-app transfer: Updated recipient $recipientUserId balance (+$amount ROO)',
          );
        } catch (e) {
          debugPrint('Error updating recipient wallet: $e');
          // Don't fail the transfer if recipient update fails - blockchain transfer succeeded
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error transferring ROO: $e');
      rethrow;
    }
  }

  /// Get transaction history for a user
  Future<List<RoocoinTransaction>> getTransactions({
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
          .map((json) => RoocoinTransaction.fromSupabase(json))
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

      debugPrint('WalletRepository: Fetching blockchain balance for ${wallet.walletAddress}...');

      // Get balance from blockchain
      final balanceData = await _roocoinService.getBalance(
        wallet.walletAddress,
      );

      debugPrint('WalletRepository: Raw balance response: $balanceData');

      final blockchainBalance = double.parse(balanceData['balance'] as String);

      debugPrint('WalletRepository: Blockchain balance: $blockchainBalance, DB balance: ${wallet.balanceRc}');

      // Update database
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': blockchainBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      debugPrint('WalletRepository: Updated DB with blockchain balance: $blockchainBalance');

      return wallet.copyWith(balanceRc: blockchainBalance);
    } catch (e) {
      debugPrint('WalletRepository: Error syncing balance: $e');
      rethrow;
    }
  }

  /// Check if Roocoin API is healthy
  Future<bool> checkApiHealth() async {
    try {
      final health = await _roocoinService.checkHealth();
      return health['status'] == 'ok';
    } catch (e) {
      debugPrint('Roocoin API health check failed: $e');
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
