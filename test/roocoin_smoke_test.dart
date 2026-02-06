import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rooverse/models/wallet.dart';
import 'package:rooverse/providers/wallet_provider.dart';
import 'package:rooverse/repositories/wallet_repository.dart';

class FakeWalletRepository extends WalletRepository {
  FakeWalletRepository()
    : super(supabase: SupabaseClient('http://localhost', 'anon'));

  bool transferCalled = false;
  bool syncCalled = false;
  bool transactionsCalled = false;
  Map<String, dynamic>? lastTransferMetadata;

  Wallet _wallet = Wallet(
    userId: 'u1',
    walletAddress: '0x0000000000000000000000000000000000000001',
    balanceRc: 10.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final List<RoocoinTransaction> _transactions = [
    RoocoinTransaction(
      id: 't1',
      txType: 'transfer',
      status: 'completed',
      fromUserId: 'u1',
      toUserId: 'u2',
      amountRc: 1.0,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<bool> checkApiHealth() async => true;

  @override
  Future<Wallet> getOrCreateWallet(String userId) async => _wallet;

  @override
  Future<Wallet?> getWallet(String userId) async => _wallet;

  @override
  Future<Map<String, dynamic>> transferToExternal({
    required String userId,
    required String toAddress,
    required double amount,
    String? memo,
    String? referencePostId,
    String? referenceCommentId,
    Map<String, dynamic>? metadata,
  }) async {
    transferCalled = true;
    lastTransferMetadata = metadata;
    return {'transactionHash': '0x1'};
  }

  @override
  Future<Wallet> syncBalance(String userId) async {
    syncCalled = true;
    _wallet = _wallet.copyWith(balanceRc: 42.0, updatedAt: DateTime.now());
    return _wallet;
  }

  @override
  Future<List<RoocoinTransaction>> getTransactions({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    transactionsCalled = true;
    return _transactions;
  }
}

void main() {
  test('transfer triggers balance sync and transaction refresh', () async {
    final repo = FakeWalletRepository();
    final provider = WalletProvider(walletRepository: repo);

    await provider.initWallet('u1');

    final ok = await provider.transferToExternal(
      userId: 'u1',
      toAddress: '0x0000000000000000000000000000000000000002',
      amount: 1.0,
      metadata: {'activityType': 'tip'},
    );

    expect(ok, isTrue);
    expect(repo.transferCalled, isTrue);
    expect(repo.syncCalled, isTrue);
    expect(repo.transactionsCalled, isTrue);
    expect(provider.wallet?.balanceRc, 42.0);
  });

  test('refreshWallet syncs balance when online', () async {
    final repo = FakeWalletRepository();
    final provider = WalletProvider(walletRepository: repo);

    await provider.initWallet('u1');
    repo.syncCalled = false;

    await provider.refreshWallet('u1');

    expect(repo.syncCalled, isTrue);
  });

  test('transfer preserves tip metadata', () async {
    final repo = FakeWalletRepository();
    final provider = WalletProvider(walletRepository: repo);

    await provider.initWallet('u1');

    await provider.transferToExternal(
      userId: 'u1',
      toAddress: '0x0000000000000000000000000000000000000002',
      amount: 2.0,
      metadata: {'activityType': 'tip'},
    );

    expect(repo.lastTransferMetadata?['activityType'], 'tip');
  });
}
