import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                // Animated logo container
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        scheme.surface,
                        scheme.surface.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: scheme.outline, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.hub,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: scheme.background,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.currency_bitcoin,
                            size: 16,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'ROOVERSE',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                    letterSpacing: -1,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Verifiably Human.',
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
                    Text(
                      'Powered by RooCoin',
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
