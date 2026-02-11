import 'package:flutter/foundation.dart';
import '../core/extensions/exception_extensions.dart';
import '../models/staking.dart';
import '../repositories/staking_repository.dart';

/// Provider for staking state management
class StakingProvider with ChangeNotifier {
  final StakingRepository _repository;

  List<StakePosition> _positions = [];
  StakingStats? _networkStats;
  UserStakingSummary _userSummary = UserStakingSummary.empty();
  bool _isLoading = false;
  String? _error;

  // Selected tier for staking form
  StakingTier _selectedTier = StakingTier.tiers.first;

  StakingProvider({StakingRepository? repository})
      : _repository = repository ?? StakingRepository();

  // Getters
  List<StakePosition> get positions => _positions;
  List<StakePosition> get activePositions =>
      _positions.where((p) => p.status == 'active').toList();
  StakingStats? get networkStats => _networkStats;
  UserStakingSummary get userSummary => _userSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  StakingTier get selectedTier => _selectedTier;
  List<StakingTier> get tiers => StakingTier.tiers;

  /// Initialize staking data for a user
  Future<void> init(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load positions and network stats in parallel
      final results = await Future.wait([
        _repository.getPositions(userId),
        _repository.getNetworkStats(),
      ]);

      _positions = results[0] as List<StakePosition>;
      _networkStats = results[1] as StakingStats;
      _userSummary = UserStakingSummary.fromPositions(_positions);
    } catch (e) {
      debugPrint('StakingProvider: Error initializing - $e');
      _error = 'Failed to load staking data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh staking data
  Future<void> refresh(String userId) async {
    try {
      _positions = await _repository.getPositions(userId);
      _networkStats = await _repository.getNetworkStats();
      _userSummary = UserStakingSummary.fromPositions(_positions);
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('StakingProvider: Error refreshing - $e');
      _error = 'Failed to refresh staking data';
      notifyListeners();
    }
  }

  /// Select a staking tier
  void selectTier(StakingTier tier) {
    _selectedTier = tier;
    notifyListeners();
  }

  /// Stake ROO tokens
  Future<bool> stake({
    required String userId,
    required double amount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final position = await _repository.stake(
        userId: userId,
        tierId: _selectedTier.id,
        amount: amount,
      );

      _positions.insert(0, position);
      _userSummary = UserStakingSummary.fromPositions(_positions);

      return true;
    } catch (e) {
      debugPrint('StakingProvider: Error staking - $e');
      _error = e.userMessage;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unstake a position
  Future<bool> unstake({
    required String userId,
    required String positionId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.unstake(userId: userId, positionId: positionId);

      // Update local state
      final index = _positions.indexWhere((p) => p.id == positionId);
      if (index != -1) {
        _positions.removeAt(index);
        _userSummary = UserStakingSummary.fromPositions(_positions);
      }

      return true;
    } catch (e) {
      debugPrint('StakingProvider: Error unstaking - $e');
      _error = e.userMessage;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Claim rewards from a position
  Future<double> claimRewards({
    required String userId,
    required String positionId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rewards = await _repository.claimRewards(
        userId: userId,
        positionId: positionId,
      );

      // Refresh to update balances
      await refresh(userId);

      return rewards;
    } catch (e) {
      debugPrint('StakingProvider: Error claiming rewards - $e');
      _error = e.userMessage;
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate projected earnings for current selection
  double calculateProjectedEarnings(double amount) {
    return _repository.calculateProjectedEarnings(
      amount: amount,
      tierId: _selectedTier.id,
    );
  }

  /// Get unlock date for current tier selection
  DateTime? getUnlockDate() {
    if (_selectedTier.lockDays == 0) return null;
    return DateTime.now().add(Duration(days: _selectedTier.lockDays));
  }
}
