import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      stepName: 'The Mission',
      title: 'Humans Only.',
      highlight: 'Zero Bots.',
      description:
          'Tired of AI spam? NOAI is a verified-human sanctuary where every voice is real and every connection is authentic.',
      image:
          'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=2071&auto=format&fit=crop',
      icon: Icons.people_outline_rounded,
    ),
    OnboardingSlide(
      stepName: 'Why NOAI',
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
          'Your attention is valuable. Get rewarded in RooCoin for authentic engagement and high-quality human content.',
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

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
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

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'NOAI',
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
                      child: Text(
                        'Skip',
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
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _buildSlide(context, _slides[index]);
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 48, top: 24),
                child: Column(
                  children: [
                    // Indicators
                    // Progress Text
                    Text(
                      'STEP ${_currentPage + 1} OF ${_slides.length}: ${_slides[_currentPage].stepName.toUpperCase()}',
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
                        _slides.length,
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
                        onPressed: _nextPage,
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
                              _currentPage == _slides.length - 1
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing
    final imageSize = (screenWidth * 0.6).clamp(200.0, 280.0);
    final titleFontSize = (screenWidth * 0.08).clamp(24.0, 36.0);
    final descriptionFontSize = (screenWidth * 0.04).clamp(14.0, 16.0);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: scheme.surface,
                border: Border.all(color: scheme.outline),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 48,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'VERIFIED SYSTEM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
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

            SizedBox(height: screenHeight * 0.04),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
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
                  const SizedBox(height: 16),
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: descriptionFontSize,
                      color: scheme.onBackground.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
