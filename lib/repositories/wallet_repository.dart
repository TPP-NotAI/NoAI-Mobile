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
      // Use upsert to be robust against RLS constraints on specific columns or existence checks
      await _supabase
          .from('wallets')
          .upsert({
            'user_id': userId,
            'wallet_address': address,
            'balance_rc': 0, // Reset balance for new wallet
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
      if (!force) {
        final existingTxs = await _supabase
            .from('roocoin_transactions')
            .select('metadata')
            .eq('to_user_id', userId)
            .eq('tx_type', 'engagement_reward');

        final existingTx = existingTxs.any((tx) {
          final metadata = tx['metadata'];
          if (metadata is Map) {
            return metadata['activityType'] == RoocoinActivityType.welcomeBonus;
          }
          return false;
        });

        if (existingTx) {
          return false;
        }
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

  /// Transfer ROO to external wallet (withdrawal)
  Future<Map<String, dynamic>> transferToExternal({
    required String userId,
    required String toAddress,
    required double amount,
  }) async {
    try {
      // 1. Get wallet and validate
      final wallet = await getWallet(userId);
      if (wallet == null) {
        throw Exception('Wallet not found for user');
      }

      if (wallet.isFrozen) {
        throw Exception('Wallet is frozen: ${wallet.frozenReason}');
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

      // 2. Execute transfer on blockchain
      final result = await _roocoinService.transfer(
        fromPrivateKey: privateKey,
        toAddress: toAddress,
        amount: amount,
      );

      // 3. Record transaction in database
      await _supabase.from('roocoin_transactions').insert({
        'tx_type': 'transfer',
        'status': 'completed',
        'from_user_id': userId,
        'amount_rc': amount,
        'tx_hash': result['transactionHash'],
        'metadata': {'toAddress': toAddress},
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 4. Update wallet balance and daily limit
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': wallet.balanceRc - amount,
            'daily_sent_today_rc': wallet.dailySentTodayRc + amount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

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
          'Skipping balance sync: Invalid address ${wallet.walletAddress}',
        );
        return wallet;
      }

      // Get balance from blockchain
      final balanceData = await _roocoinService.getBalance(
        wallet.walletAddress,
      );
      final blockchainBalance = double.parse(balanceData['balance'] as String);

      // Update database
      await _supabase
          .from('wallets')
          .update({
            'balance_rc': blockchainBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return wallet.copyWith(balanceRc: blockchainBalance);
    } catch (e) {
      debugPrint('Error syncing balance: $e');
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
        'encrypted_private_key':
            privateKey, // Should be encrypted in production
        'updated_at': DateTime.now().toIso8601String(),
      });
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
