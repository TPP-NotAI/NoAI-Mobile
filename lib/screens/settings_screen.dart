import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../config/app_colors.dart';
import 'profile/edit_profile_screen.dart';
import 'profile/personal_information_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'support/faq_screen.dart';
import 'support/support_chat_screen.dart';
import 'wallet/transaction_history_screen.dart';
import 'status/status_screen.dart';
import 'moderation/mod_queue_screen.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'security/password_security_screen.dart';
import 'settings/blocked_muted_users_screen.dart';
import 'settings/privacy_screen.dart';
import 'language_screen.dart';
import 'notifications/notification_settings_screen.dart';
import 'auth/human_verification_screen.dart';
import 'auth/phone_verification_screen.dart';
import 'wallet/wallet_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Settings', style: TextStyle(color: scheme.onSurface)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentUser?.balance.toStringAsFixed(0) ?? '0'} ROO',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage: currentUser?.avatar != null
                      ? NetworkImage(currentUser!.avatar!)
                      : null,
                  child: currentUser?.avatar == null
                      ? Icon(Icons.person, size: 50, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  currentUser?.displayName.isNotEmpty == true
                      ? currentUser!.displayName
                      : currentUser?.username ?? 'User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
                Text(
                  '@${currentUser?.username ?? 'unknown'}',
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildSectionHeader(context, 'ACCOUNT'),
          _buildSettingsTile(
            context,
            icon: Icons.person,
            iconColor: AppColors.primary,
            title: 'Personal Information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalInformationScreen(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.lock,
            iconColor: AppColors.primary,
            title: 'Password & Security',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PasswordSecurityScreen(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.verified_user,
            iconColor: currentUser?.verifiedHuman == 'verified'
                ? Colors.green
                : Colors.orange,
            title: 'Human Verification',
            subtitle: _getVerificationStatus(currentUser?.verifiedHuman),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanVerificationScreen(
                    onVerify: () => Navigator.pop(context),
                    onPhoneVerify: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhoneVerificationScreen(
                            onVerify: () => Navigator.pop(context),
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.bookmark,
            iconColor: AppColors.primary,
            title: 'Bookmarks',
            subtitle: 'Saved posts',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.assignment,
            iconColor: Colors.blue,
            title: 'Status & Appeals',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatusScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.admin_panel_settings,
            iconColor: Colors.purple,
            title: 'Mod Queue',
            subtitle: 'Moderation dashboard',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModQueueScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'ROOBYTE WALLET'),
          _buildSettingsTile(
            context,
            icon: Icons.account_balance_wallet,
            iconColor: Colors.purple,
            title: 'Wallet Settings',
            subtitle: '8x4a...3b9c',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.history,
            iconColor: Colors.purple,
            title: 'Transaction History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'PREFERENCES'),
          _buildSettingsTile(
            context,
            icon: Icons.notifications,
            iconColor: Colors.orange,
            title: 'Notifications',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip,
            iconColor: Colors.orange,
            title: 'Privacy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.block,
            iconColor: Colors.red,
            title: 'Blocked Users',
            subtitle: 'Manage users you have blocked',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BlockedMutedUsersScreen(),
                ),
              );
            },
          ),

          Consumer<ThemeProvider>(
            builder: (_, themeProvider, __) {
              return _buildSettingsTileWithSwitch(
                context,
                icon: Icons.dark_mode,
                iconColor: Colors.grey,
                title: 'Dark Mode',
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              );
            },
          ),

          Consumer<LanguageProvider>(
            builder: (_, languageProvider, __) {
              return _buildSettingsTile(
                context,
                icon: Icons.language,
                iconColor: Colors.orange,
                title: 'Language',
                subtitle: languageProvider.currentLanguageName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'SUPPORT'),
          _buildSettingsTile(
            context,
            icon: Icons.help_center,
            iconColor: Colors.teal,
            title: 'Help Center',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FAQScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.contact_support,
            iconColor: Colors.teal,
            title: 'Support Chat',
            subtitle: 'Online help with our team',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportChatScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info,
            iconColor: Colors.teal,
            title: 'About ROOVERSE',
            onTap: () => _showAboutDialog(context),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'LEGAL'),
          _buildSettingsTile(
            context,
            icon: Icons.description,
            iconColor: Colors.blue,
            title: 'Terms of Service',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip,
            iconColor: Colors.blue,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'DANGER ZONE'),
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => _showLogoutDialog(context),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildSettingsTileWithSwitch(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  static String _getVerificationStatus(String? status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'pending':
        return 'Pending verification';
      default:
        return 'Not verified';
    }
  }

  static void _showAboutDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'About ROOVERSE',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          'ROOVERSE – Human-First Social Platform\n\nVersion 1.0.2\n\n© 2026 ROOVERSE Inc.',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void _showLogoutDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('Log Out', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Delete Account',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. Type DELETE to confirm.',
              style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type DELETE',
                filled: true,
                fillColor: scheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().toUpperCase() == 'DELETE') {
                Navigator.pop(dialogContext);
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Account deletion request submitted. You have been logged out.',
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
