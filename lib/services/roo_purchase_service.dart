import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles Stripe checkout session creation for buying ROO.
class RooPurchaseService {
  RooPurchaseService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const String _functionName = 'stripe-checkout';

  Future<Uri> createCheckoutUrl({
    required String userId,
    required int rooAmount,
    required double usdAmount,
  }) async {
    final response = await _supabase.functions.invoke(
      _functionName,
      body: {
        'action': 'create_checkout_session',
        'user_id': userId,
        'roo_amount': rooAmount,
        'usd_amount': usdAmount,
        'currency': 'usd',
      },
    );

    final data = response.data;
    final dynamic rawUrl =
        data is Map<String, dynamic>
            ? (data['checkout_url'] ?? data['checkoutUrl'] ?? data['url'])
            : null;

    if (rawUrl is! String || rawUrl.isEmpty) {
      throw Exception('Stripe checkout URL not returned by Edge Function.');
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      throw Exception('Invalid Stripe checkout URL.');
    }

    return uri;
  }

  Future<void> launchCheckout(Uri checkoutUri) async {
    final launched = await launchUrl(
      checkoutUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open Stripe checkout.');
    }
  }

  void logError(Object error) {
    debugPrint('RooPurchaseService: $error');
  }
}
