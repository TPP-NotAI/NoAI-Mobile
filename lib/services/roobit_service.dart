import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class RoobitService {
  static const Duration _sendTimeout = Duration(seconds: 90);

  final SupabaseService _supabase = SupabaseService();

  Future<Map<String, dynamic>> _proxy(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final payload = <String, dynamic>{
      'path': path,
      'method': method.toUpperCase(),
    };

    if (body != null) {
      payload['body'] = body;
    }

    // Refresh the session if it's expired or close to expiry
    Session? session = _supabase.client.auth.currentSession;
    if (session != null) {
      final expiresAt = session.expiresAt;
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt != null && expiresAt - nowSecs < 60) {
        try {
          final refreshed = await _supabase.client.auth.refreshSession();
          session = refreshed.session;
        } catch (_) {}
      }
    }
    final accessToken = session?.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('User is not authenticated');
    }

    try {
      final response = await _supabase.client.functions.invoke(
        'roocoin-proxy',
        body: payload,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.data == null) {
        throw Exception('roocoin-proxy returned no data');
      }

      final Map<String, dynamic> data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : json.decode(response.data.toString()) as Map<String, dynamic>;

      if (response.status >= 400) {
        throw Exception(
          data['details']?.toString() ??
              data['error']?.toString() ??
              'Request failed with status ${response.status}',
        );
      }

      if (data['error'] != null) {
        throw Exception(
          data['details']?.toString() ?? data['error'].toString(),
        );
      }

      return data;
    } on FunctionException catch (e) {
      throw Exception(
        e.details?.toString().isNotEmpty == true
            ? e.details.toString()
            : 'Edge Function error: ${e.reasonPhrase ?? 'Unknown error'}',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _retryRequest(
    Future<dynamic> Function() requestFn, {
    int maxRetries = 3,
    String operationName = 'Request',
  }) async {
    int attempts = 0;

    while (true) {
      try {
        attempts++;
        return await requestFn();
      } catch (e) {
        final errorText = e.toString().toLowerCase();

        final isReplacementError =
            errorText.contains('replacement fee too low') ||
            errorText.contains('replacement transaction underpriced');

        if (attempts >= maxRetries || !isReplacementError) {
          rethrow;
        }

        final delay = Duration(milliseconds: 2000 * attempts);
        debugPrint(
          'RoobitService: $operationName failed (replacement underpriced). '
          'Retrying in ${delay.inSeconds}s ($attempts/$maxRetries)',
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<Map<String, dynamic>> createWallet() async {
    try {
      return await _proxy('/api/wallet/create', method: 'POST', body: {});
    } catch (e) {
      debugPrint('RoobitService createWallet error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBalance(String address) async {
    try {
      final trimmedAddress = address.trim();
      if (trimmedAddress.isEmpty) {
        throw Exception('Wallet address is required');
      }

      final data = await _proxy('/api/wallet/balance/$trimmedAddress');

      if (data['success'] == false) {
        throw Exception('Failed to get balance: Operation unsuccessful');
      }

      return data;
    } catch (e) {
      debugPrint('RoobitService getBalance error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestFaucet({
    required String address,
    double amount = 100.0,
  }) async {
    return await _retryRequest(() async {
          final trimmedAddress = address.trim();
          if (trimmedAddress.isEmpty) {
            throw Exception('Wallet address is required');
          }

          final data = await _proxy(
            '/api/wallet/faucet',
            method: 'POST',
            body: {'address': trimmedAddress, 'amount': amount.toString()},
          );

          if (data['success'] == false) {
            throw Exception('Faucet request failed: Operation unsuccessful');
          }

          return data;
        }, operationName: 'requestFaucet')
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> spend({
    required String userPrivateKey,
    required double amount,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          if (userPrivateKey.trim().isEmpty) {
            throw Exception('User private key is required');
          }
          if (activityType.trim().isEmpty) {
            throw Exception('Activity type is required');
          }
          if (amount <= 0) {
            throw Exception('Amount must be greater than zero');
          }

          final data = await _proxy(
            '/api/wallet/spend',
            method: 'POST',
            body: {
              'userPrivateKey': userPrivateKey,
              'amount': amount.toString(),
              'activityType': activityType,
              if (metadata != null) 'metadata': metadata,
            },
          );

          if (data['success'] == false) {
            throw Exception('Spend operation failed: Operation unsuccessful');
          }

          return data;
        }, operationName: 'spend')
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> send({
    required String fromPrivateKey,
    required String toAddress,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          if (fromPrivateKey.trim().isEmpty) {
            throw Exception('Sender private key is required');
          }

          final cleanedToAddress = toAddress.trim();
          if (cleanedToAddress.isEmpty) {
            throw Exception('Recipient address is required');
          }

          final ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
          if (!ethAddressRegex.hasMatch(cleanedToAddress)) {
            throw Exception('Recipient wallet address is invalid');
          }

          if (amount <= 0) {
            throw Exception('Amount must be greater than zero');
          }

          final amountStr = amount % 1 == 0
              ? amount.toInt().toString()
              : amount.toString();

          debugPrint(
            'RoobitService send payload: '
            'toAddress=$cleanedToAddress, amount=$amountStr',
          );

          final data = await _proxy(
            '/api/wallet/send',
            method: 'POST',
            body: {
              'fromPrivateKey': fromPrivateKey.trim(),
              'privateKey': fromPrivateKey.trim(),
              'toAddress': cleanedToAddress,
              'to': cleanedToAddress,
              'target': cleanedToAddress,
              'recipientAddress': cleanedToAddress,
              'recipient': cleanedToAddress,
              'destination': cleanedToAddress,
              'toWalletAddress': cleanedToAddress,
              'amount': amountStr,
              'value': amountStr,
              if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
            },
          ).timeout(_sendTimeout);

          if (data['success'] == false) {
            throw Exception('Send operation failed: Operation unsuccessful');
          }

          return data;
        }, operationName: 'send')
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> distributeReward({
    required String userAddress,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          if (userAddress.trim().isEmpty) {
            throw Exception('User address is required');
          }
          if (activityType.trim().isEmpty) {
            throw Exception('Activity type is required');
          }

          final data = await _proxy(
            '/api/rewards/distribute',
            method: 'POST',
            body: {
              'userAddress': userAddress.trim(),
              'activityType': activityType,
              if (metadata != null) 'metadata': metadata,
            },
          );

          if (data['success'] == false) {
            throw Exception(
              'Reward distribution failed: Operation unsuccessful',
            );
          }

          return data;
        }, operationName: 'distributeReward')
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchDistributeRewards({
    required List<Map<String, dynamic>> distributions,
  }) async {
    if (distributions.isEmpty) {
      throw Exception('Distributions list cannot be empty');
    }

    final data = await _proxy(
      '/api/rewards/batch-distribute',
      method: 'POST',
      body: {'distributions': distributions},
    );

    if (data['success'] == false) {
      throw Exception('Batch distribution failed: Operation unsuccessful');
    }

    return data;
  }

  Future<Map<String, dynamic>> checkHealth() async {
    try {
      return await _proxy('/health');
    } catch (e) {
      debugPrint('RoobitService checkHealth error: $e');
      rethrow;
    }
  }
}

class RoobitActivityType {
  static const String postCreate = 'POST_CREATE';
  static const String postLike = 'POST_LIKE';
  static const String postComment = 'POST_COMMENT';
  static const String postShare = 'POST_SHARE';
  static const String referral = 'REFERRAL';
  static const String profileComplete = 'PROFILE_COMPLETE';
  static const String contentViral = 'CONTENT_VIRAL';
  static const String dailyLogin = 'DAILY_LOGIN';
  static const String welcomeBonus = 'WELCOME_BONUS';
  static const String adFee = 'AD_FEE';

  static const Map<String, double> rewards = {
    postCreate: 0.01,
    postLike: 0.01,
    referral: 10.0,
    profileComplete: 5.0,
    contentViral: 1.0,
    dailyLogin: 1.0,
    welcomeBonus: 0.0,
  };
}
