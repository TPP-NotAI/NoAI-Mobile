import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
              'Your Privacy Matters',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: scheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),

            _buildParagraph(
              context,
              'At NOAI, we are committed to protecting your privacy and ensuring transparency in how we collect, use, and protect your personal information. This Privacy Policy explains our data practices.',
            ),

            const SizedBox(height: 32),

            _buildSectionTitle(context, '1. Information We Collect'),
            _buildSubsectionTitle(context, 'Personal Information'),
            _buildBulletPoint(context, 'Email address and username'),
            _buildBulletPoint(
              context,
              'Profile information (display name, bio, avatar)',
            ),
            _buildBulletPoint(
              context,
              'Verification data (biometric, identity documents)',
            ),
            _buildBulletPoint(
              context,
              'Wallet address for RooCoin transactions',
            ),

            const SizedBox(height: 12),

            _buildSubsectionTitle(context, 'Usage Data'),
            _buildBulletPoint(context, 'Posts, comments, and interactions'),
            _buildBulletPoint(context, 'Device information and IP address'),
            _buildBulletPoint(context, 'Analytics and engagement metrics'),
            _buildBulletPoint(context, 'AI detection scan results'),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '2. How We Use Your Information'),
            _buildParagraph(context, 'We use your information to:'),
            _buildBulletPoint(context, 'Verify you are a real human being'),
            _buildBulletPoint(
              context,
              'Detect and prevent AI-generated content',
            ),
            _buildBulletPoint(
              context,
              'Process RooCoin rewards and transactions',
            ),
            _buildBulletPoint(
              context,
              'Improve platform features and user experience',
            ),
            _buildBulletPoint(
              context,
              'Enforce our Terms of Service and No-AI Policy',
            ),
            _buildBulletPoint(
              context,
              'Communicate with you about your account',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '3. AI Detection & Content Scanning'),
            _buildParagraph(
              context,
              'To maintain our no-AI policy, we analyze all content using:',
            ),
            _buildBulletPoint(context, 'Machine learning detection algorithms'),
            _buildBulletPoint(context, 'Linguistic pattern analysis'),
            _buildBulletPoint(context, 'Image and video metadata examination'),
            _buildBulletPoint(
              context,
              'Community reporting and human moderation',
            ),

            const SizedBox(height: 12),

            _buildInfoBox(
              context,
              'Important',
              'Scan results are stored for moderation purposes. False positives can be appealed.',
              Icons.info_outline,
              AppColors.primary,
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '4. Blockchain & RooCoin'),
            _buildParagraph(
              context,
              'RooCoin transactions are recorded on the Ethereum blockchain. Please note:',
            ),
            _buildBulletPoint(
              context,
              'Blockchain transactions are public and permanent',
            ),
            _buildBulletPoint(
              context,
              'Your wallet address may be visible on-chain',
            ),
            _buildBulletPoint(
              context,
              'We cannot delete or modify blockchain records',
            ),
            _buildBulletPoint(
              context,
              'Off-chain balance adjustments remain private',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '5. Data Sharing & Third Parties'),
            _buildParagraph(
              context,
              'We do not sell your personal information. We may share data with:',
            ),
            _buildBulletPoint(
              context,
              'Verification service providers (identity checks)',
            ),
            _buildBulletPoint(
              context,
              'Cloud infrastructure providers (AWS, etc.)',
            ),
            _buildBulletPoint(
              context,
              'Analytics services (aggregated data only)',
            ),
            _buildBulletPoint(context, 'Law enforcement (if legally required)'),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '6. Your Privacy Rights'),
            _buildParagraph(context, 'You have the right to:'),
            _buildBulletPoint(context, 'Access your personal data'),
            _buildBulletPoint(context, 'Correct inaccurate information'),
            _buildBulletPoint(
              context,
              'Request data deletion (subject to limitations)',
            ),
            _buildBulletPoint(context, 'Export your content and data'),
            _buildBulletPoint(context, 'Opt out of certain data processing'),

            const SizedBox(height: 12),

            _buildInfoBox(
              context,
              'EU Users (GDPR)',
              'European users have additional rights under GDPR, including data portability and the right to be forgotten.',
              Icons.gavel,
              const Color(0xFF3B82F6),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '7. Data Security'),
            _buildParagraph(
              context,
              'We implement industry-standard security measures:',
            ),
            _buildBulletPoint(
              context,
              'End-to-end encryption for sensitive data',
            ),
            _buildBulletPoint(
              context,
              'Secure servers with regular security audits',
            ),
            _buildBulletPoint(context, 'Two-factor authentication options'),
            _buildBulletPoint(context, 'Employee access controls and training'),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '8. Data Retention'),
            _buildParagraph(context, 'We retain your data as follows:'),
            _buildBulletPoint(context, 'Account data: Until account deletion'),
            _buildBulletPoint(
              context,
              'Posts & comments: Indefinitely (unless deleted)',
            ),
            _buildBulletPoint(context, 'Moderation records: 2 years'),
            _buildBulletPoint(
              context,
              'Analytics data: 18 months (aggregated)',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '9. Cookies & Tracking'),
            _buildParagraph(
              context,
              'We use cookies and similar technologies for:',
            ),
            _buildBulletPoint(context, 'Session management and authentication'),
            _buildBulletPoint(context, 'Preferences and settings'),
            _buildBulletPoint(context, 'Analytics and performance monitoring'),
            _buildBulletPoint(context, 'Security and fraud prevention'),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '10. Children\'s Privacy'),
            _buildParagraph(
              context,
              'NOAI is not intended for children under 13. We do not knowingly collect data from children.',
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(context, '11. Changes to This Policy'),
            _buildParagraph(
              context,
              'We may update this Privacy Policy. Continued use indicates acceptance.',
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
                      Icon(Icons.security, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy Questions?',
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
                    'Email: privacy@noai.social',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Data Protection Officer: dpo@noai.social',
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

  Widget _buildSubsectionTitle(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
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

  Widget _buildInfoBox(
    BuildContext context,
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
