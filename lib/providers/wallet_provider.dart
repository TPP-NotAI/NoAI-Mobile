import 'package:flutter/foundation.dart';
import '../core/extensions/exception_extensions.dart';
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

  bool get isWalletActivated {
    final address = _wallet?.walletAddress ?? '';
    if (address.isEmpty) return false;
    if (address.startsWith('PENDING_ACTIVATION_')) return false;
    final evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return evmRegex.hasMatch(address);
  }

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

      // Get or create wallet only if online; otherwise load from DB
      // Note: getOrCreateWallet -> createWallet already handles welcome bonus
      // so we don't need to call checkAndAwardWelcomeBonus again here
      if (_isNetworkOnline) {
        _wallet = await _walletRepository.getOrCreateWallet(userId);
      } else {
        _wallet = await _walletRepository.getWallet(userId);
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

      debugPrint('WalletProvider: Syncing balance for user $userId...');
      debugPrint('WalletProvider: Current local balance: ${_wallet!.balanceRc}');

      final updatedWallet = await _walletRepository.syncBalance(userId);

      debugPrint('WalletProvider: Blockchain balance: ${updatedWallet.balanceRc}');

      if (_wallet!.balanceRc != updatedWallet.balanceRc) {
        debugPrint('WalletProvider: Balance changed from ${_wallet!.balanceRc} to ${updatedWallet.balanceRc}');
      }

      _wallet = updatedWallet;
      notifyListeners();
    } catch (e) {
      debugPrint('WalletProvider: Error syncing balance: $e');
    }
  }

  /// Refresh wallet data
  Future<void> refreshWallet(String userId) async {
    await checkNetworkStatus();
    if (_isNetworkOnline) {
      if (_wallet == null || !isWalletActivated) {
        _wallet = await _walletRepository.getOrCreateWallet(userId);
      }
      // Always sync balance from blockchain when refreshing
      debugPrint('WalletProvider: Refreshing wallet - forcing blockchain sync...');
      await _syncBalance(userId);
    } else {
      _wallet = await _walletRepository.getWallet(userId);
    }
    await fetchTransactions(userId);
  }

  Future<bool> activateWallet(String userId) async {
    await checkNetworkStatus();
    if (!_isNetworkOnline) {
      _error = 'You are offline. Connect to activate your wallet.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _wallet = await _walletRepository.getOrCreateWallet(userId);
      if (_wallet != null) {
        await _syncBalance(userId);
      }
      await fetchTransactions(userId);
      return true;
    } catch (e) {
      debugPrint('WalletProvider: Error activating wallet - $e');
      _error = e.userMessage;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load wallet from database only (no blockchain sync)
  Future<void> loadWallet(String userId) async {
    _wallet = await _walletRepository.getWallet(userId);
    await fetchTransactions(userId);
    notifyListeners();
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

      // Refresh wallet to get updated balance and transaction from DB
      await loadWallet(userId);
      return true;
    } catch (e) {
      debugPrint('Error spending ROO: $e');
      _error = e.userMessage;
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
    String? memo,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
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
        memo: memo,
        referencePostId: referencePostId,
        referenceCommentId: referenceCommentId,
        metadata: metadata,
      );

      _wallet = await _walletRepository.syncBalance(userId);
      await fetchTransactions(userId);
      return true;
    } catch (e) {
      debugPrint('Error transferring: $e');
      _error = e.userMessage;
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

      // Refresh wallet to get updated balance and transaction from DB
      await loadWallet(userId);
      return true;
    } catch (e) {
      debugPrint('Error earning ROO: $e');
      _error = e.userMessage;
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
      _error = e.userMessage;
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
