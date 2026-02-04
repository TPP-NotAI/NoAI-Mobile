import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'supabase_service.dart';

/// Service for interacting with the Roocoin API
class RoocoinService {
  static const String baseUrl = 'https://roocoin-production.up.railway.app';

  // Read API key from environment
  static String getApiKey() {
    final key = dotenv.env['ROOCOIN_API_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception('ROOCOIN_API_KEY is missing. Set it in .env.');
    }
    // Don't log full key for security
    debugPrint(
      'RoocoinService: Using API key: ${key.substring(0, min(10, key.length))}...',
    );
    return key;
  }

  // Headers helper
  static Map<String, String> getHeaders() {
    final key = getApiKey();
    final session = SupabaseService().currentSession;
    final token = session?.accessToken ?? '';

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': key,
    };

    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    debugPrint('RoocoinService: Computed headers: $headers');
    return headers;
  }

  static int min(int a, int b) => a < b ? a : b;

  /// Create a new custodial wallet for a user
  /// Returns address, privateKey, and mnemonic
  /// IMPORTANT: Store privateKey encrypted in your database
  Future<Map<String, dynamic>> createWallet() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallet/create'),
        headers: getHeaders(),
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to create wallet: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error creating wallet: $e');
      rethrow;
    }
  }

  /// Get wallet balance for an address
  Future<Map<String, dynamic>> getBalance(String address) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/wallet/balance/$address'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to get balance: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error getting balance: $e');
      rethrow;
    }
  }

  /// Generic retry helper for blockchain transactions
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
        // specific check for replacement underpriced error
        final isReplacementError =
            e.toString().contains('replacement fee too low') ||
            e.toString().contains('replacement transaction underpriced');

        if (attempts >= maxRetries || !isReplacementError) {
          rethrow;
        }

        final delay = Duration(milliseconds: 2000 * attempts); // 2s, 4s, 6s...
        debugPrint(
          'RoocoinService: $operationName failed (replacement underpriced). Retrying in ${delay.inSeconds}s (Attempt $attempts/$maxRetries)',
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Give test tokens to a wallet (testnet only)
  /// Default: 100 ROO
  Future<Map<String, dynamic>> requestFaucet({
    required String address,
    double amount = 100.0,
  }) async {
    return await _retryRequest(() async {
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/wallet/faucet'),
              headers: getHeaders(),
              body: json.encode({
                'address': address,
                'amount': amount.toString(),
              }),
            );

            if (response.statusCode == 200) {
              return json.decode(response.body) as Map<String, dynamic>;
            } else {
              throw Exception(
                'Failed to request faucet: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error requesting faucet: $e');
            rethrow;
          }
        }, operationName: 'requestFaucet')
        as Map<String, dynamic>;
  }

  /// Deduct ROO for platform actions
  /// Check balance first
  /// Returns remaining balance
  Future<Map<String, dynamic>> spend({
    required String userPrivateKey,
    required double amount,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/wallet/spend'),
              headers: getHeaders(),
              body: json.encode({
                'userPrivateKey': userPrivateKey,
                'amount': amount.toString(),
                'activityType': activityType,
                if (metadata != null) 'metadata': metadata,
              }),
            );

            if (response.statusCode == 200) {
              return json.decode(response.body) as Map<String, dynamic>;
            } else {
              throw Exception(
                'Failed to spend ROO: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error spending ROO: $e');
            rethrow;
          }
        }, operationName: 'spend')
        as Map<String, dynamic>;
  }

  /// Transfer ROO to external wallet (e.g., MetaMask)
  /// Users can move ROO to their own wallet
  Future<Map<String, dynamic>> transfer({
    required String fromPrivateKey,
    required String toAddress,
    required double amount,
  }) async {
    return await _retryRequest(() async {
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/wallet/transfer'),
              headers: getHeaders(),
              body: json.encode({
                'fromPrivateKey': fromPrivateKey,
                'toAddress': toAddress,
                'amount': amount.toString(),
              }),
            );

            if (response.statusCode == 200) {
              return json.decode(response.body) as Map<String, dynamic>;
            } else {
              throw Exception(
                'Failed to transfer ROO: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error transferring ROO: $e');
            rethrow;
          }
        }, operationName: 'transfer')
        as Map<String, dynamic>;
  }

  /// Distribute rewards to a user for activities
  Future<Map<String, dynamic>> distributeReward({
    required String userAddress,
    required String activityType,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          try {
            final headers = getHeaders();

            debugPrint(
              'RoocoinService: Requesting reward with headers: $headers',
            );

            final response = await http.post(
              Uri.parse('$baseUrl/api/rewards/distribute'),
              headers: headers,
              body: json.encode({
                'userAddress': userAddress,
                'activityType': activityType,
                if (metadata != null) 'metadata': metadata,
              }),
            );

            debugPrint(
              'RoocoinService: Response status: ${response.statusCode}',
            );
            debugPrint('RoocoinService: Response body: ${response.body}');

            if (response.statusCode == 200) {
              return json.decode(response.body) as Map<String, dynamic>;
            } else if (response.statusCode == 403) {
              debugPrint(
                'RoocoinService: API authentication failed. Please check ROOCOIN_API_KEY configuration.',
              );
              throw Exception(
                'Roocoin API authentication failed (403 - Invalid Token). Key rejected by server.',
              );
            } else if (response.statusCode == 401) {
              debugPrint(
                'RoocoinService: API authentication failed (401). Header issue?',
              );
              throw Exception(
                'Roocoin API authentication failed (401 - No token).',
              );
            } else {
              throw Exception(
                'Failed to distribute reward: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error distributing reward: $e');
            rethrow;
          }
        }, operationName: 'distributeReward')
        as Map<String, dynamic>;
  }

  /// Batch distribute rewards to multiple users (more gas-efficient)
  Future<Map<String, dynamic>> batchDistributeRewards({
    required List<Map<String, dynamic>> distributions,
  }) async {
    try {
      final headers = getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/api/rewards/batch-distribute'),
        headers: headers,
        body: json.encode({'distributions': distributions}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to batch distribute rewards: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error batch distributing rewards: $e');
      rethrow;
    }
  }

  /// Check API health status
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to check health: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error checking health: $e');
      rethrow;
    }
  }
}

/// Activity types for Roocoin rewards
class RoocoinActivityType {
  static const String postCreate = 'POST_CREATE'; // 10 ROO
  static const String postLike = 'POST_LIKE'; // 0.1 ROO
  static const String postComment = 'POST_COMMENT'; // 2 ROO
  static const String postShare = 'POST_SHARE'; // 5 ROO
  static const String referral = 'REFERRAL'; // 50 ROO
  static const String profileComplete = 'PROFILE_COMPLETE'; // 25 ROO
  static const String dailyLogin =
      'DAILY_LOGIN'; // 1 ROO (Note: Server currently returns 0.5)
  static const String contentViral = 'CONTENT_VIRAL'; // 100 ROO
  static const String welcomeBonus = 'WELCOME_BONUS'; // 100 ROO

  static const Map<String, double> rewards = {
    postCreate: 10.0,
    postLike: 0.1,
    postComment: 2.0,
    postShare: 5.0,
    referral: 50.0,
    profileComplete: 25.0,
    dailyLogin: 1.0,
    contentViral: 100.0,
    welcomeBonus: 100.0,
  };
}
