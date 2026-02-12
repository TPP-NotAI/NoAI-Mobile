import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

/// Represents a user's Rooken wallet
@JsonSerializable()
class Wallet {
  final String userId;
  final String walletAddress;
  final double balanceRc;
  final double pendingBalanceRc;
  final double lifetimeEarnedRc;
  final double lifetimeSpentRc;
  final bool isFrozen;
  final String? frozenReason;
  final DateTime? frozenAt;
  final double? dailySendLimitRc;
  final double dailySentTodayRc;
  final DateTime? limitResetAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Encrypted private key - NEVER expose to users
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? encryptedPrivateKey;

  Wallet({
    required this.userId,
    required this.walletAddress,
    this.balanceRc = 0.0,
    this.pendingBalanceRc = 0.0,
    this.lifetimeEarnedRc = 0.0,
    this.lifetimeSpentRc = 0.0,
    this.isFrozen = false,
    this.frozenReason,
    this.frozenAt,
    this.dailySendLimitRc,
    this.dailySentTodayRc = 0.0,
    this.limitResetAt,
    required this.createdAt,
    required this.updatedAt,
    this.encryptedPrivateKey,
  });

  /// Available balance (excluding pending)
  double get availableBalance => balanceRc;

  /// Total balance including pending
  double get totalBalance => balanceRc + pendingBalanceRc;

  /// Remaining daily send limit
  double get remainingDailyLimit =>
      (dailySendLimitRc ?? 10000) - dailySentTodayRc;

  /// Create from Supabase wallet row
  factory Wallet.fromSupabase(Map<String, dynamic> json) {
    return Wallet(
      userId: json['user_id'] as String,
      walletAddress: json['wallet_address'] as String,
      balanceRc: (json['balance_rc'] as num?)?.toDouble() ?? 0.0,
      pendingBalanceRc: (json['pending_balance_rc'] as num?)?.toDouble() ?? 0.0,
      lifetimeEarnedRc: (json['lifetime_earned_rc'] as num?)?.toDouble() ?? 0.0,
      lifetimeSpentRc: (json['lifetime_spent_rc'] as num?)?.toDouble() ?? 0.0,
      isFrozen: json['is_frozen'] as bool? ?? false,
      frozenReason: json['frozen_reason'] as String?,
      frozenAt: json['frozen_at'] != null
          ? DateTime.parse(json['frozen_at'] as String)
          : null,
      dailySendLimitRc: (json['daily_send_limit_rc'] as num?)?.toDouble(),
      dailySentTodayRc:
          (json['daily_sent_today_rc'] as num?)?.toDouble() ?? 0.0,
      limitResetAt: json['limit_reset_at'] != null
          ? DateTime.parse(json['limit_reset_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
  Map<String, dynamic> toJson() => _$WalletToJson(this);

  Wallet copyWith({
    String? userId,
    String? walletAddress,
    double? balanceRc,
    double? pendingBalanceRc,
    double? lifetimeEarnedRc,
    double? lifetimeSpentRc,
    bool? isFrozen,
    String? frozenReason,
    DateTime? frozenAt,
    double? dailySendLimitRc,
    double? dailySentTodayRc,
    DateTime? limitResetAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptedPrivateKey,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      walletAddress: walletAddress ?? this.walletAddress,
      balanceRc: balanceRc ?? this.balanceRc,
      pendingBalanceRc: pendingBalanceRc ?? this.pendingBalanceRc,
      lifetimeEarnedRc: lifetimeEarnedRc ?? this.lifetimeEarnedRc,
      lifetimeSpentRc: lifetimeSpentRc ?? this.lifetimeSpentRc,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenReason: frozenReason ?? this.frozenReason,
      frozenAt: frozenAt ?? this.frozenAt,
      dailySendLimitRc: dailySendLimitRc ?? this.dailySendLimitRc,
      dailySentTodayRc: dailySentTodayRc ?? this.dailySentTodayRc,
      limitResetAt: limitResetAt ?? this.limitResetAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
    );
  }
}

/// Represents a Rooken transaction
@JsonSerializable()
class RookenTransaction {
  final String id;
  final String txType;
  final String status;
  final String? fromUserId;
  final String? toUserId;
  final double amountRc;
  final double feeRc;
  final String? referencePostId;
  final String? referenceCommentId;
  final String? memo;
  final String? txHash;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final String? failureReason;

  RookenTransaction({
    required this.id,
    required this.txType,
    required this.status,
    this.fromUserId,
    this.toUserId,
    required this.amountRc,
    this.feeRc = 0.0,
    this.referencePostId,
    this.referenceCommentId,
    this.memo,
    this.txHash,
    this.metadata,
    required this.createdAt,
    this.completedAt,
    this.failedAt,
    this.failureReason,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory RookenTransaction.fromSupabase(Map<String, dynamic> json) {
    return RookenTransaction(
      id: json['id'] as String,
      txType: json['tx_type'] as String,
      status: json['status'] as String,
      fromUserId: json['from_user_id'] as String?,
      toUserId: json['to_user_id'] as String?,
      amountRc: (json['amount_rc'] as num).toDouble(),
      feeRc: (json['fee_rc'] as num?)?.toDouble() ?? 0.0,
      referencePostId: json['reference_post_id'] as String?,
      referenceCommentId: json['reference_comment_id'] as String?,
      memo: json['memo'] as String?,
      txHash: json['tx_hash'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      failedAt: json['failed_at'] != null
          ? DateTime.parse(json['failed_at'] as String)
          : null,
      failureReason: json['failure_reason'] as String?,
    );
  }

  factory RookenTransaction.fromJson(Map<String, dynamic> json) =>
      _$RookenTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$RookenTransactionToJson(this);
}
