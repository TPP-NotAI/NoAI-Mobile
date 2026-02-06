import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'contact_support_screen.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Help Center', style: TextStyle(color: scheme.onSurface)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline),
              ),
              child: TextField(
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search for help...',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Popular Topics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),

            _buildFAQCategory(
              context,
              'Getting Started',
              Icons.rocket_launch,
              const Color(0xFF3B82F6),
              [
                _FAQItem(
                  question: 'How do I create an account?',
                  answer:
                      'Tap "Sign Up" on the login screen, enter your email and username, accept the ROOVERSE Content Policy, and complete email verification. You\'ll then need to complete human verification to access all features.',
                ),
                _FAQItem(
                  question: 'What is human verification?',
                  answer:
                      'Human verification is our process to confirm you\'re a real person, not a bot or AI. This may include biometric authentication, identity document verification, or blockchain-based proof of personhood.',
                ),
                _FAQItem(
                  question: 'Can I use AI tools to help create content?',
                  answer:
                      'No. ROOVERSE strictly prohibits AI-generated content. All posts, comments, and media must be created entirely by humans.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildFAQCategory(
              context,
              'RooCoin & Rewards',
              Icons.toll,
              const Color(0xFF10B981),
              [
                _FAQItem(
                  question: 'What is RooCoin (ROO)?',
                  answer:
                      'RooCoin is ROOVERSE\'s native cryptocurrency token. You earn ROO by posting quality content, engaging authentically, and contributing to the community.',
                ),
                _FAQItem(
                  question: 'How do I earn RooCoin?',
                  answer:
                      'You earn ROO by posting original content, receiving tips, accurate moderation, and participation.',
                ),
                _FAQItem(
                  question: 'Can I convert RooCoin to real money?',
                  answer:
                      'RooCoin can be traded on supported cryptocurrency exchanges, subject to local regulations.',
                ),
                _FAQItem(
                  question: 'What is staking?',
                  answer:
                      'Staking locks ROO tokens to earn rewards and governance power.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildFAQCategory(
              context,
              'Content & Moderation',
              Icons.shield,
              const Color(0xFFF59E0B),
              [
                _FAQItem(
                  question: 'Why was my post flagged as AI-generated?',
                  answer:
                      'Our detection systems analyze content for AI patterns. Appeals are available.',
                ),
                _FAQItem(
                  question: 'How do I appeal a moderation decision?',
                  answer:
                      'Go to Status & Appeals in your profile and submit evidence.',
                ),
                _FAQItem(
                  question: 'What happens if my appeal is denied?',
                  answer:
                      'The content remains removed and repeated violations may result in penalties.',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Still need help
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Still need help?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is here 24/7',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactSupportScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildFAQCategory(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<_FAQItem> items,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => _buildFAQItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, _FAQItem item) {
    final scheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          item.question,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: scheme.onSurface.withOpacity(0.5),
        children: [
          Text(
            item.answer,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withOpacity(0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({required this.question, required this.answer});
}
