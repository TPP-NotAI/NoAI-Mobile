// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Wallet _$WalletFromJson(Map<String, dynamic> json) => Wallet(
  userId: json['userId'] as String,
  walletAddress: json['walletAddress'] as String,
  balanceRc: (json['balanceRc'] as num?)?.toDouble() ?? 0.0,
  pendingBalanceRc: (json['pendingBalanceRc'] as num?)?.toDouble() ?? 0.0,
  lifetimeEarnedRc: (json['lifetimeEarnedRc'] as num?)?.toDouble() ?? 0.0,
  lifetimeSpentRc: (json['lifetimeSpentRc'] as num?)?.toDouble() ?? 0.0,
  isFrozen: json['isFrozen'] as bool? ?? false,
  frozenReason: json['frozenReason'] as String?,
  frozenAt: json['frozenAt'] == null
      ? null
      : DateTime.parse(json['frozenAt'] as String),
  dailySendLimitRc: (json['dailySendLimitRc'] as num?)?.toDouble(),
  dailySentTodayRc: (json['dailySentTodayRc'] as num?)?.toDouble() ?? 0.0,
  limitResetAt: json['limitResetAt'] == null
      ? null
      : DateTime.parse(json['limitResetAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$WalletToJson(Wallet instance) => <String, dynamic>{
  'userId': instance.userId,
  'walletAddress': instance.walletAddress,
  'balanceRc': instance.balanceRc,
  'pendingBalanceRc': instance.pendingBalanceRc,
  'lifetimeEarnedRc': instance.lifetimeEarnedRc,
  'lifetimeSpentRc': instance.lifetimeSpentRc,
  'isFrozen': instance.isFrozen,
  'frozenReason': instance.frozenReason,
  'frozenAt': instance.frozenAt?.toIso8601String(),
  'dailySendLimitRc': instance.dailySendLimitRc,
  'dailySentTodayRc': instance.dailySentTodayRc,
  'limitResetAt': instance.limitResetAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

RookenTransaction _$RookenTransactionFromJson(Map<String, dynamic> json) =>
    RookenTransaction(
      id: json['id'] as String,
      txType: json['txType'] as String,
      status: json['status'] as String,
      fromUserId: json['fromUserId'] as String?,
      toUserId: json['toUserId'] as String?,
      amountRc: (json['amountRc'] as num).toDouble(),
      feeRc: (json['feeRc'] as num?)?.toDouble() ?? 0.0,
      referencePostId: json['referencePostId'] as String?,
      referenceCommentId: json['referenceCommentId'] as String?,
      memo: json['memo'] as String?,
      txHash: json['txHash'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      failedAt: json['failedAt'] == null
          ? null
          : DateTime.parse(json['failedAt'] as String),
      failureReason: json['failureReason'] as String?,
    );

Map<String, dynamic> _$RookenTransactionToJson(RookenTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'txType': instance.txType,
      'status': instance.status,
      'fromUserId': instance.fromUserId,
      'toUserId': instance.toUserId,
      'amountRc': instance.amountRc,
      'feeRc': instance.feeRc,
      'referencePostId': instance.referencePostId,
      'referenceCommentId': instance.referenceCommentId,
      'memo': instance.memo,
      'txHash': instance.txHash,
      'metadata': instance.metadata,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'failedAt': instance.failedAt?.toIso8601String(),
      'failureReason': instance.failureReason,
    };
