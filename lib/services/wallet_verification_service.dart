import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';

/// Comprehensive wallet verification utility
/// Use this to test wallet operations before deployment
class WalletVerificationService {
  final WalletRepository _walletRepo = WalletRepository();

  /// Run all verification checks
  Future<Map<String, dynamic>> runAllChecks(String userId) async {
    final results = <String, dynamic>{};

    try {
      // 1. Check API Health
      results['api_health'] = await _checkApiHealth();

      // 2. Check Wallet Exists
      results['wallet_check'] = await _checkWalletExists(userId);

      // 3. Check Balance Sync
      results['balance_sync'] = await _checkBalanceSync(userId);

      // 4. Check for Duplicate Rewards
      results['duplicate_rewards'] = await _checkDuplicateRewards(userId);

      // 5. Verify Transaction History
      results['transaction_history'] = await _verifyTransactionHistory(userId);

      // 6. Check Welcome Bonus
      results['welcome_bonus'] = await _checkWelcomeBonus(userId);

      results['overall_status'] = 'PASSED';
    } catch (e) {
      results['overall_status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Check if Roocoin API is healthy
  Future<Map<String, dynamic>> _checkApiHealth() async {
    try {
      final isHealthy = await _walletRepo.checkApiHealth();
      return {
        'status': isHealthy ? 'HEALTHY' : 'UNHEALTHY',
        'passed': isHealthy,
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Check if wallet exists and is valid
  Future<Map<String, dynamic>> _checkWalletExists(String userId) async {
    try {
      final wallet = await _walletRepo.getWallet(userId);
      if (wallet == null) {
        return {
          'status': 'NO_WALLET',
          'passed': false,
          'message': 'Wallet does not exist',
        };
      }

      final isValidAddress = RegExp(
        r'^0x[a-fA-F0-9]{40}$',
      ).hasMatch(wallet.walletAddress);

      return {
        'status': 'EXISTS',
        'passed': true,
        'wallet_address': wallet.walletAddress,
        'balance': wallet.balanceRc,
        'is_valid_address': isValidAddress,
        'is_frozen': wallet.isFrozen,
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Check if balance is synced with blockchain
  Future<Map<String, dynamic>> _checkBalanceSync(String userId) async {
    try {
      final walletBefore = await _walletRepo.getWallet(userId);
      if (walletBefore == null) {
        return {'status': 'NO_WALLET', 'passed': false};
      }

      final dbBalance = walletBefore.balanceRc;

      // Sync with blockchain
      final walletAfter = await _walletRepo.syncBalance(userId);
      final chainBalance = walletAfter.balanceRc;

      final difference = (dbBalance - chainBalance).abs();
      final isSynced = difference < 0.01; // Allow small rounding differences

      return {
        'status': isSynced ? 'SYNCED' : 'OUT_OF_SYNC',
        'passed': isSynced,
        'db_balance': dbBalance,
        'chain_balance': chainBalance,
        'difference': difference,
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Check for duplicate rewards in transaction history
  Future<Map<String, dynamic>> _checkDuplicateRewards(String userId) async {
    try {
      final transactions = await _walletRepo.getTransactions(
        userId: userId,
        limit: 1000,
      );

      final rewardTransactions = transactions
          .where((tx) => tx.txType == 'engagement_reward')
          .toList();

      // Group by activity type and reference
      final Map<String, List<dynamic>> grouped = {};
      final duplicates = <Map<String, dynamic>>[];

      for (final tx in rewardTransactions) {
        final metadata = tx.metadata ?? {};
        final activityType = metadata['activityType'] ?? 'UNKNOWN';
        final postId = tx.referencePostId ?? '';
        final commentId = tx.referenceCommentId ?? '';

        // Create unique key
        final key = '$activityType|$postId|$commentId';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add({
          'id': tx.id,
          'amount': tx.amountRc,
          'created_at': tx.createdAt,
        });

        // Check for duplicates
        if (grouped[key]!.length > 1) {
          duplicates.add({
            'activity_type': activityType,
            'post_id': postId,
            'comment_id': commentId,
            'count': grouped[key]!.length,
            'transactions': grouped[key],
          });
        }
      }

      return {
        'status': duplicates.isEmpty ? 'NO_DUPLICATES' : 'DUPLICATES_FOUND',
        'passed': duplicates.isEmpty,
        'total_rewards': rewardTransactions.length,
        'duplicate_count': duplicates.length,
        'duplicates': duplicates,
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Verify transaction history matches wallet balances
  Future<Map<String, dynamic>> _verifyTransactionHistory(String userId) async {
    try {
      final wallet = await _walletRepo.getWallet(userId);
      if (wallet == null) {
        return {'status': 'NO_WALLET', 'passed': false};
      }

      final transactions = await _walletRepo.getTransactions(
        userId: userId,
        limit: 1000,
      );

      // Calculate totals from transactions
      double totalEarned = 0;
      double totalSpent = 0;

      for (final tx in transactions) {
        if (tx.toUserId == userId) {
          // Incoming
          totalEarned += tx.amountRc;
        } else if (tx.fromUserId == userId) {
          // Outgoing
          totalSpent += tx.amountRc;
        }
      }

      final calculatedBalance = totalEarned - totalSpent;
      final actualBalance = wallet.balanceRc;
      final difference = (calculatedBalance - actualBalance).abs();
      final isAccurate = difference < 0.01;

      return {
        'status': isAccurate ? 'ACCURATE' : 'MISMATCH',
        'passed': isAccurate,
        'calculated_balance': calculatedBalance,
        'actual_balance': actualBalance,
        'difference': difference,
        'total_earned': totalEarned,
        'total_spent': totalSpent,
        'lifetime_earned': wallet.lifetimeEarnedRc,
        'lifetime_spent': wallet.lifetimeSpentRc,
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Check if welcome bonus was awarded correctly
  Future<Map<String, dynamic>> _checkWelcomeBonus(String userId) async {
    try {
      final transactions = await _walletRepo.getTransactions(
        userId: userId,
        limit: 1000,
      );

      final welcomeBonuses = transactions.where((tx) {
        final metadata = tx.metadata ?? {};
        final activityType = metadata['activityType'] ?? '';
        return activityType == 'WELCOME_BONUS' ||
            activityType == RookenActivityType.welcomeBonus;
      }).toList();

      return {
        'status': welcomeBonuses.length == 1
            ? 'CORRECT'
            : welcomeBonuses.isEmpty
            ? 'NOT_AWARDED'
            : 'MULTIPLE_BONUSES',
        'passed': welcomeBonuses.length == 1,
        'count': welcomeBonuses.length,
        'bonuses': welcomeBonuses
            .map((tx) => {'amount': tx.amountRc, 'created_at': tx.createdAt})
            .toList(),
      };
    } catch (e) {
      return {'status': 'ERROR', 'passed': false, 'error': e.toString()};
    }
  }

  /// Generate a detailed report
  String generateReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('        WALLET VERIFICATION REPORT');
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Overall Status: ${results['overall_status']}');
    buffer.writeln('');

    // API Health
    final apiHealth = results['api_health'] as Map<String, dynamic>?;
    if (apiHealth != null) {
      buffer.writeln('1. API Health Check');
      buffer.writeln('   Status: ${apiHealth['status']}');
      buffer.writeln('   Passed: ${apiHealth['passed'] ? '✓' : '✗'}');
      buffer.writeln('');
    }

    // Wallet Check
    final walletCheck = results['wallet_check'] as Map<String, dynamic>?;
    if (walletCheck != null) {
      buffer.writeln('2. Wallet Existence Check');
      buffer.writeln('   Status: ${walletCheck['status']}');
      buffer.writeln('   Passed: ${walletCheck['passed'] ? '✓' : '✗'}');
      if (walletCheck['wallet_address'] != null) {
        buffer.writeln('   Address: ${walletCheck['wallet_address']}');
        buffer.writeln('   Balance: ${walletCheck['balance']} ROO');
        buffer.writeln('   Valid Address: ${walletCheck['is_valid_address']}');
      }
      buffer.writeln('');
    }

    // Balance Sync
    final balanceSync = results['balance_sync'] as Map<String, dynamic>?;
    if (balanceSync != null) {
      buffer.writeln('3. Balance Sync Check');
      buffer.writeln('   Status: ${balanceSync['status']}');
      buffer.writeln('   Passed: ${balanceSync['passed'] ? '✓' : '✗'}');
      if (balanceSync['db_balance'] != null) {
        buffer.writeln('   DB Balance: ${balanceSync['db_balance']} ROO');
        buffer.writeln('   Chain Balance: ${balanceSync['chain_balance']} ROO');
        buffer.writeln('   Difference: ${balanceSync['difference']} ROO');
      }
      buffer.writeln('');
    }

    // Duplicate Rewards
    final duplicates = results['duplicate_rewards'] as Map<String, dynamic>?;
    if (duplicates != null) {
      buffer.writeln('4. Duplicate Rewards Check');
      buffer.writeln('   Status: ${duplicates['status']}');
      buffer.writeln('   Passed: ${duplicates['passed'] ? '✓' : '✗'}');
      buffer.writeln('   Total Rewards: ${duplicates['total_rewards']}');
      buffer.writeln('   Duplicates Found: ${duplicates['duplicate_count']}');
      if (duplicates['duplicate_count'] > 0) {
        buffer.writeln('   ⚠️ WARNING: Duplicate rewards detected!');
        final dupList = duplicates['duplicates'] as List;
        for (final dup in dupList) {
          buffer.writeln(
            '      - ${dup['activity_type']}: ${dup['count']} times',
          );
        }
      }
      buffer.writeln('');
    }

    // Transaction History
    final txHistory = results['transaction_history'] as Map<String, dynamic>?;
    if (txHistory != null) {
      buffer.writeln('5. Transaction History Verification');
      buffer.writeln('   Status: ${txHistory['status']}');
      buffer.writeln('   Passed: ${txHistory['passed'] ? '✓' : '✗'}');
      if (txHistory['calculated_balance'] != null) {
        buffer.writeln(
          '   Calculated Balance: ${txHistory['calculated_balance']} ROO',
        );
        buffer.writeln('   Actual Balance: ${txHistory['actual_balance']} ROO');
        buffer.writeln('   Difference: ${txHistory['difference']} ROO');
      }
      buffer.writeln('');
    }

    // Welcome Bonus
    final welcomeBonus = results['welcome_bonus'] as Map<String, dynamic>?;
    if (welcomeBonus != null) {
      buffer.writeln('6. Welcome Bonus Check');
      buffer.writeln('   Status: ${welcomeBonus['status']}');
      buffer.writeln('   Passed: ${welcomeBonus['passed'] ? '✓' : '✗'}');
      buffer.writeln('   Count: ${welcomeBonus['count']}');
      buffer.writeln('');
    }

    buffer.writeln('═══════════════════════════════════════════════════');

    return buffer.toString();
  }
}
