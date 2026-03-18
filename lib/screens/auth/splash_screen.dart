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
    final config = context.watch<PlatformConfigProvider>().config;
    final tagline = (config.platformDescription != null && config.platformDescription!.isNotEmpty)
        ? config.platformDescription!
        : 'Verifiably Human.';

    Future.delayed(const Duration(milliseconds: 2500), onComplete);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content — full logo + tagline centered
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/splash_icon.png',
                  width: MediaQuery.of(context).size.width * 0.55,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  tagline,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w400,
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
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      backgroundColor: Color(0xFFEEEEEE),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.token, size: 13, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by Roochip'.tr(context),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAAAAA),
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
