import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'supabase_service.dart';

/// Service for interacting with the Rooken API
class RookenService {
  static const String baseUrl = 'https://roocoin-production.up.railway.app';

  // Read API key from environment
  static String getApiKey() {
    final key = dotenv.env['ROOCOIN_API_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception('ROOCOIN_API_KEY is missing. Set it in .env.');
    }
    // Don't log full key for security
    debugPrint(
      'RookenService: Using API key: ${key.substring(0, math.min(10, key.length))}...',
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

    final maskedHeaders = Map<String, String>.from(headers);
    if (maskedHeaders.containsKey('x-api-key')) {
      maskedHeaders['x-api-key'] =
          '***${key.substring(math.min(key.length, 5))}';
    }
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }

    debugPrint('RookenService: Computed headers: $maskedHeaders');
    return headers;
  }

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
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) {
          throw Exception('Failed to get balance: ${data['error']}');
        }
        if (data['success'] == false) {
          throw Exception('Failed to get balance: Operation unsuccessful');
        }
        return data;
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
          'RookenService: $operationName failed (replacement underpriced). Retrying in ${delay.inSeconds}s (Attempt $attempts/$maxRetries)',
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Give test tokens to a wallet (testnet only)
  /// Default: 100 ROOK
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
              final data = json.decode(response.body) as Map<String, dynamic>;
              if (data['error'] != null) {
                throw Exception('Faucet request failed: ${data['error']}');
              }
              if (data['success'] == false) {
                throw Exception(
                  'Faucet request failed: Operation unsuccessful',
                );
              }
              return data;
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

  /// Deduct ROOK for platform actions
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
              final data = json.decode(response.body) as Map<String, dynamic>;
              if (data['error'] != null) {
                throw Exception('Spend operation failed: ${data['error']}');
              }
              if (data['success'] == false) {
                throw Exception(
                  'Spend operation failed: Operation unsuccessful',
                );
              }
              return data;
            } else {
              throw Exception(
                'Failed to spend ROOK: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error spending ROOK: $e');
            rethrow;
          }
        }, operationName: 'spend')
        as Map<String, dynamic>;
  }

  /// Peer-to-peer transfer - User sends ROOK to another user on the platform
  /// This endpoint is preferred for user-to-user transfers as it handles gas more efficiently.
  Future<Map<String, dynamic>> send({
    required String fromPrivateKey,
    required String toAddress,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    return await _retryRequest(() async {
          try {
            // Format amount as string, removing trailing .0 if present
            final amountStr = amount % 1 == 0
                ? amount.toInt().toString()
                : amount.toString();

            final body = {
              'fromPrivateKey': fromPrivateKey,
              'toAddress': toAddress,
              'amount': amountStr,
              if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
            };

            debugPrint('RookenService: Sending ROOK via /api/wallet/send');
            debugPrint(
              'RookenService: Request Body: ${json.encode({...body, 'fromPrivateKey': '0x***${fromPrivateKey.substring(math.min(fromPrivateKey.length, 5))}'})}',
            );

            final response = await http.post(
              Uri.parse('$baseUrl/api/wallet/send'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body),
            ).timeout(const Duration(seconds: 25));

            if (response.statusCode == 200) {
              final data = json.decode(response.body) as Map<String, dynamic>;
              if (data['error'] != null) {
                throw Exception('Send operation failed: ${data['error']}');
              }
              if (data['success'] == false) {
                throw Exception(
                  'Send operation failed: Operation unsuccessful',
                );
              }
              return data;
            } else {
              throw Exception(
                'Failed to send ROOK: ${response.statusCode} - ${response.body}',
              );
            }
          } catch (e) {
            debugPrint('Error sending ROOK: $e');
            rethrow;
          }
        }, operationName: 'send')
        as Map<String, dynamic>;
  }

  /// Transfer ROOK to external wallet (e.g., MetaMask)

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
              'RookenService: Requesting reward with headers: $headers',
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
              'RookenService: Response status: ${response.statusCode}',
            );
            debugPrint('RookenService: Response body: ${response.body}');

            if (response.statusCode == 200) {
              final data = json.decode(response.body) as Map<String, dynamic>;
              if (data['error'] != null) {
                throw Exception('Reward distribution failed: ${data['error']}');
              }
              if (data['success'] == false) {
                throw Exception(
                  'Reward distribution failed: Operation unsuccessful',
                );
              }
              return data;
            } else if (response.statusCode == 403) {
              debugPrint(
                'RookenService: API authentication failed. Please check ROOCOIN_API_KEY configuration.',
              );
              throw Exception(
                'Rooken API authentication failed (403 - Invalid Token). Key rejected by server.',
              );
            } else if (response.statusCode == 401) {
              debugPrint(
                'RookenService: API authentication failed (401). Header issue?',
              );
              throw Exception(
                'Rooken API authentication failed (401 - No token).',
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) {
          throw Exception('Batch distribution failed: ${data['error']}');
        }
        if (data['success'] == false) {
          throw Exception('Batch distribution failed: Operation unsuccessful');
        }
        return data;
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

/// Activity types for Rooken rewards
class RookenActivityType {
  static const String postCreate = 'POST_CREATE'; // 10 ROOK
  static const String postLike = 'POST_LIKE'; // 0.1 ROOK
  static const String postComment = 'POST_COMMENT'; // 2 ROOK
  static const String postShare = 'POST_SHARE'; // 5 ROOK
  static const String referral = 'REFERRAL'; // 50 ROOK
  static const String profileComplete = 'PROFILE_COMPLETE'; // 25 ROOK
  static const String dailyLogin =
      'DAILY_LOGIN'; // 1 ROOK (Note: Server currently returns 0.5)
  static const String contentViral = 'CONTENT_VIRAL'; // 100 ROOK
  static const String welcomeBonus = 'WELCOME_BONUS'; // 100 ROOK

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
