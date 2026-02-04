import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';
import '../services/roocoin_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletRepository _walletRepository;

  Wallet? _wallet;
  List<RoocoinTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isNetworkOnline = true;
  bool _wasWelcomeBonusAwarded = false;

  WalletProvider({WalletRepository? walletRepository})
    : _walletRepository = walletRepository ?? WalletRepository();

  Wallet? get wallet => _wallet;
  List<RoocoinTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isNetworkOnline => _isNetworkOnline;
  bool get wasWelcomeBonusAwarded => _wasWelcomeBonusAwarded;

  /// Check network status
  Future<void> checkNetworkStatus() async {
    _isNetworkOnline = await _walletRepository.checkApiHealth();
    notifyListeners();
  }

  /// Initialize wallet for a user
  Future<void> initWallet(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await checkNetworkStatus();

      // Get or create wallet
      _wallet = await _walletRepository.getOrCreateWallet(userId);

      // Check and award welcome bonus for existing/new users
      if (_wallet != null) {
        try {
          final awarded = await _walletRepository.checkAndAwardWelcomeBonus(
            userId,
          );
          if (awarded) {
            debugPrint('Welcome bonus awarded to user $userId');
            _wasWelcomeBonusAwarded = true;
            // Update local wallet after bonus
            _wallet = await _walletRepository.getWallet(userId);
          }
        } catch (e) {
          debugPrint('Error awarding welcome bonus: $e');
          // Continue even if bonus fails
        }
      }

      // Load transactions
      await fetchTransactions(userId);

      // Sync balance with blockchain in background
      if (_isNetworkOnline) {
        _syncBalance(userId);
      }
    } catch (e) {
      debugPrint('Error initializing wallet: $e');
      _error = 'Failed to load wallet data';
      // Don't rethrow - allow app to continue without wallet
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sync balance without setting loading state
  Future<void> _syncBalance(String userId) async {
    try {
      if (_wallet == null) return;

      final updatedWallet = await _walletRepository.syncBalance(userId);
      _wallet = updatedWallet;
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing balance: $e');
    }
  }

  /// Refresh wallet data
  Future<void> refreshWallet(String userId) async {
    await checkNetworkStatus();
    if (_wallet != null) {
      await _syncBalance(userId);
    } else {
      _wallet = await _walletRepository.getOrCreateWallet(userId);
    }
    await fetchTransactions(userId);
  }

  /// Fetch transaction history
  Future<void> fetchTransactions(String userId) async {
    try {
      _transactions = await _walletRepository.getTransactions(userId: userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      // Don't set global error here to avoid blocking UI
    }
  }

  /// Spend ROO (e.g. for creating a post)
  Future<bool> spendRoo({
    required String userId,
    required double amount,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    if (_wallet == null) return false;

    // Optimistic check
    if (_wallet!.balanceRc < amount) {
      _error = 'Insufficient funds';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _walletRepository.spendRoo(
        userId: userId,
        amount: amount,
        activityType: activityType,
        metadata: metadata,
      );

      // Refresh wallet to get updated balance and transaction
      await refreshWallet(userId);
      return true;
    } catch (e) {
      debugPrint('Error spending ROO: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Transfer to external wallet
  Future<bool> transferToExternal({
    required String userId,
    required String toAddress,
    required double amount,
  }) async {
    if (_wallet == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _walletRepository.transferToExternal(
        userId: userId,
        toAddress: toAddress,
        amount: amount,
      );

      await refreshWallet(userId);
      return true;
    } catch (e) {
      debugPrint('Error transferring: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Earn ROO (e.g. from content creation)
  Future<bool> earnRoo({
    required String userId,
    required double amount,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Note: The backend determines the actual reward amount based on activityType.
      // The 'amount' parameter is passed for local tracking but actual reward comes from backend.

      await _walletRepository.earnRoo(
        userId: userId,
        activityType: activityType,
        metadata: metadata,
      );

      // Refresh wallet to get updated balance and transaction
      await refreshWallet(userId);
      return true;
    } catch (e) {
      debugPrint('Error earning ROO: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Earn reward manually (development/testing only)
  Future<void> debugEarnReward(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _walletRepository.earnRoo(
        userId: userId,
        activityType: RoocoinActivityType.dailyLogin,
      );
      await refreshWallet(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark welcome bonus message as shown
  void consumeWelcomeBonus() {
    _wasWelcomeBonusAwarded = false;
    notifyListeners();
  }
}
