import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
        title: Text(
          'Terms of Service',
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: January 6, 2026',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Welcome to NOAI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: scheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),

            _buildParagraph(
              context,
              'By accessing and using NOAI (the "Platform"), you agree to be bound by these Terms of Service. NOAI is a human-first social platform that strictly prohibits AI-generated content and automated interactions.',
            ),

            const SizedBox(height: 32),

            _buildSectionTitle(context, '1. The No-AI Policy'),
            _buildParagraph(
              context,
              'All content posted on NOAI must be created by a verified human being. The use of AI tools to generate text, images, videos, or any other form of content is strictly prohibited and will result in immediate account termination.',
            ),
            _buildBulletPoint(
              context,
              'Text content must be written by humans',
            ),
            _buildBulletPoint(
              context,
              'Images and videos must be captured or created by humans',
            ),
            _buildBulletPoint(
              context,
              'No AI assistants, chatbots, or automated posting tools',
            ),
            _buildBulletPoint(
              context,
              'Editing tools are permitted; generation tools are not',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(
              context,
              '2. Account Registration & Verification',
            ),
            _buildParagraph(
              context,
              'To use NOAI, you must complete human verification. This may include biometric authentication, identity verification, and blockchain-based proof of personhood.',
            ),
            _buildBulletPoint(
              context,
              'You must be 13 years or older to create an account',
            ),
            _buildBulletPoint(context, 'One account per person'),
            _buildBulletPoint(
              context,
              'Accurate information required for verification',
            ),
            _buildBulletPoint(
              context,
              'You are responsible for account security',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '3. RooCoin & Virtual Currency'),
            _buildParagraph(
              context,
              'RooCoin (ROO) is the native token of the NOAI ecosystem. By using RooCoin, you acknowledge:',
            ),
            _buildBulletPoint(
              context,
              'ROO has no monetary value outside the platform',
            ),
            _buildBulletPoint(
              context,
              'Rewards are earned for authentic human engagement',
            ),
            _buildBulletPoint(
              context,
              'ROO can be used for platform features and tipping',
            ),
            _buildBulletPoint(
              context,
              'NOAI reserves the right to adjust ROO mechanics',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '4. Content Moderation'),
            _buildParagraph(
              context,
              'All content is subject to moderation. We use AI detection tools and human moderators to enforce our no-AI policy.',
            ),
            _buildBulletPoint(
              context,
              'Content flagged as AI-generated will be removed',
            ),
            _buildBulletPoint(context, 'You may appeal moderation decisions'),
            _buildBulletPoint(
              context,
              'Repeat violations result in permanent ban',
            ),
            _buildBulletPoint(
              context,
              'Community moderators earn ROO for accurate flags',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '5. Prohibited Conduct'),
            _buildParagraph(
              context,
              'In addition to AI-generated content, the following are prohibited:',
            ),
            _buildBulletPoint(context, 'Harassment, hate speech, or threats'),
            _buildBulletPoint(context, 'Spam or repetitive content'),
            _buildBulletPoint(context, 'Impersonation of others'),
            _buildBulletPoint(
              context,
              'Sharing private information without consent',
            ),
            _buildBulletPoint(context, 'Illegal activities or content'),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '6. Intellectual Property'),
            _buildParagraph(
              context,
              'You retain ownership of your content, but grant NOAI a license to display, distribute, and promote it on the platform.',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '7. Disclaimers & Limitations'),
            _buildParagraph(
              context,
              'NOAI is provided "as is" without warranties. We are not liable for user-generated content or interactions between users.',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '8. Changes to Terms'),
            _buildParagraph(
              context,
              'We may update these Terms at any time. Continued use of NOAI constitutes acceptance of modified terms.',
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contact_support,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Questions?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact us at legal@noai.social',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withOpacity(0.7),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: scheme.onBackground,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: scheme.onSurface.withOpacity(0.75),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
