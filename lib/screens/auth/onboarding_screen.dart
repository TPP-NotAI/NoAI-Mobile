import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/platform_config_provider.dart';
import '../../widgets/app_logo.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  List<OnboardingSlide> _buildSlides(String platformName) => [
    OnboardingSlide(
      stepName: 'The Mission',
      title: 'Humans Only.',
      highlight: 'Zero Bots.',
      description:
          'Tired of AI spam? $platformName is a verified-human sanctuary where every voice is real and every connection is authentic.',
      image:
          'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=2071&auto=format&fit=crop',
      icon: Icons.people_outline_rounded,
    ),
    OnboardingSlide(
      stepName: 'Why $platformName',
      title: 'Humanity',
      highlight: 'Verified.',
      description:
          'We use proof-of-humanity technology to ensure your feed is free from generative garbage. You only interact with real people.',
      image:
          'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=2070&auto=format&fit=crop',
      icon: Icons.verified_user_outlined,
    ),
    OnboardingSlide(
      stepName: 'Rewards',
      title: 'Earn Real',
      highlight: 'Value.',
      description:
          'Your attention is valuable. Get rewarded in $platformName for authentic engagement and high-quality human content.',
      image:
          'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?q=80&w=2070&auto=format&fit=crop',
      icon: Icons.account_balance_wallet_outlined,
    ),
    OnboardingSlide(
      stepName: 'Next Steps',
      title: 'Ready for',
      highlight: 'Real Talk?',
      description:
          'Join the revolution. Create your human profile, verify your identity, and reclaim social media.',
      image:
          'https://images.unsplash.com/photo-1460925895917-afdab827c52f?q=80&w=2070&auto=format&fit=crop',
      icon: Icons.rocket_launch_outlined,
    ),
  ];

  void _nextPage(int slideCount) {
    if (_currentPage < slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final platformName = context.watch<PlatformConfigProvider>().config.platformName;
    final slides = _buildSlides(platformName);

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AppLogo(
                          size: 32,
                          fallbackIcon: Icons.fingerprint,
                          fallbackIconColor: Colors.white,
                          containerDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(platformName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: scheme.onBackground,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: widget.onComplete,
                      child: Text('Skip'.tr(context),
                        style: TextStyle(
                          color: scheme.onBackground.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    return _buildSlide(context, slides[index]);
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: Column(
                  children: [
                    // Indicators
                    // Progress Text
                    Text('STEP ${_currentPage + 1} OF ${slides.length}: ${slides[_currentPage].stepName.toUpperCase()}'.tr(context),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onBackground.withOpacity(0.5),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: _currentPage == index ? 24 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primary
                                : scheme.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Next button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _nextPage(slides.length),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == slides.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(BuildContext context, OnboardingSlide slide) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        // All sizing derived from available space
        final imageSize = (h * 0.38).clamp(120.0, 260.0);
        final iconSize = (imageSize * 0.28).clamp(24.0, 52.0);
        final iconPadding = (imageSize * 0.08).clamp(8.0, 18.0);
        final imageRadius = (imageSize * 0.16).clamp(16.0, 40.0);
        final titleFontSize = (h * 0.055).clamp(20.0, 36.0);
        final descFontSize = (h * 0.028).clamp(12.0, 16.0);
        final gapAfterImage = h * 0.04;
        final gapBetweenTitleDesc = h * 0.02;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(imageRadius),
                color: scheme.surface,
                border: Border.all(color: scheme.outline),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(imageRadius),
                      child: Opacity(
                        opacity: 0.4,
                        child: Image.network(
                          slide.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: scheme.surface),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(iconPadding),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(iconPadding),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: iconSize,
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(height: imageSize * 0.06),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: w * 0.03,
                            vertical: h * 0.005,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'VERIFIED SYSTEM'.tr(context),
                            style: TextStyle(
                              fontSize: (h * 0.014).clamp(8.0, 11.0),
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: gapAfterImage),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.04),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(text: '${slide.title}\n'),
                        TextSpan(
                          text: slide.highlight,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gapBetweenTitleDesc),
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: descFontSize,
                      color: scheme.onBackground.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class OnboardingSlide {
  final String stepName;
  final String title;
  final String highlight;
  final String description;
  final String image;
  final IconData icon;

  OnboardingSlide({
    required this.stepName,
    required this.title,
    required this.highlight,
    required this.description,
    required this.image,
    required this.icon,
  });
}
