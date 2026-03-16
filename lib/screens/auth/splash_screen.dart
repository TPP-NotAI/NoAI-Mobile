import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/platform_config_provider.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class SplashScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = context.watch<PlatformConfigProvider>().config;
    final tagline = (config.platformDescription != null && config.platformDescription!.isNotEmpty)
        ? config.platformDescription!
        : 'Verifiably Human.';

    // Auto-navigate after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), onComplete);

    return Scaffold(
      backgroundColor: scheme.background,
      body: Stack(
        children: [
          // Background pattern with opacity
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://picsum.photos/400/800?random=1',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/auth_logo_dark.png'
                      : 'assets/auth_logo_light.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 8),

                Text(tagline,
                  style: TextStyle(
                    fontSize: 18,
                    color: scheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.token, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Powered by Roochip'.tr(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onBackground.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
