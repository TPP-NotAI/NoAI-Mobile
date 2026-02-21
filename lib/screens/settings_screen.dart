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
import 'support/help_support_screen.dart';
import 'support/support_tickets_admin_screen.dart';
import 'moderation/my_flagged_content_screen.dart';
import 'moderation/mod_queue_screen.dart';
import 'wallet/transaction_history_screen.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'security/password_security_screen.dart';
import 'settings/blocked_muted_users_screen.dart';
import 'settings/privacy_screen.dart';
import 'language_screen.dart';
import 'notifications/notification_settings_screen.dart';
import 'auth/human_verification_screen.dart';
import 'auth/phone_verification_screen.dart';
import '../services/app_update_service.dart';
import '../repositories/support_ticket_repository.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final SupportTicketRepository _supportTicketRepository =
      SupportTicketRepository();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(l10n.settings, style: TextStyle(color: scheme.onSurface)),
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
                    label: Text(l10n.editProfile),
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
            title: l10n.personalInformation,
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
            title: l10n.passwordSecurity,
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
            title: l10n.humanVerification,
            subtitle: _getVerificationStatus(context, currentUser?.verifiedHuman),
            onTap: currentUser?.verifiedHuman == 'verified' ||
                    currentUser?.verifiedHuman == 'pending'
                ? null
                : () {
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
            title: l10n.bookmarks,
            subtitle: l10n.savedPosts,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(context, 'ROOBYTE WALLET'),
          _buildSettingsTile(
            context,
            icon: Icons.history,
            iconColor: Colors.purple,
            title: l10n.transactionHistory,
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
            title: l10n.notifications,
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
            title: l10n.privacy,
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
                title: l10n.darkMode,
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
                title: l10n.language,
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
            title: l10n.helpCenter,
            subtitle: 'FAQ and contact support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          ),
          FutureBuilder<bool>(
            future: _supportTicketRepository.isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }
              return _buildSettingsTile(
                context,
                icon: Icons.confirmation_number,
                iconColor: Colors.indigo,
                title: 'Support Tickets (Admin)',
                subtitle: 'Review submitted support tickets',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportTicketsAdminScreen(),
                    ),
                  );
                },
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.gavel,
            iconColor: Colors.deepOrange,
            title: 'My Flagged Content',
            subtitle: 'View, appeal or delete AI-flagged posts & comments',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyFlaggedContentScreen(),
                ),
              );
            },
          ),
          FutureBuilder<bool>(
            future: _supportTicketRepository.isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return _buildSettingsTile(
                context,
                icon: Icons.admin_panel_settings,
                iconColor: Colors.deepOrange,
                title: 'Moderation Queue',
                subtitle: 'Review AI-flagged content',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModQueueScreen(),
                    ),
                  );
                },
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info,
            iconColor: Colors.teal,
            title: l10n.aboutROOVERSE,
            onTap: () => _showAboutDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.system_update,
            iconColor: Colors.teal,
            title: 'Check for Updates',
            onTap: () async {
              await AppUpdateService.instance.checkAndPromptForUpdate(
                context,
                manual: true,
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'LEGAL'),
          _buildSettingsTile(
            context,
            icon: Icons.description,
            iconColor: Colors.blue,
            title: l10n.termsOfService,
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
            title: l10n.privacyPolicy,
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
            title: l10n.deleteAccount,
            subtitle: l10n.permanentlyDeleteAccount,
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => _showLogoutDialog(context),
            child: Text(
              l10n.logOut,
              style: const TextStyle(color: Colors.red, fontSize: 16),
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
    VoidCallback? onTap,
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

  static String _getVerificationStatus(BuildContext context, String? status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'verified':
        return l10n.verified;
      case 'pending':
        return l10n.pendingVerification;
      default:
        return l10n.notVerified;
    }
  }

  static void _showAboutDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          l10n.aboutROOVERSE,
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          l10n.aboutROOVERSEDescription,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  static void _showLogoutDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(l10n.logOut, style: TextStyle(color: scheme.onSurface)),
        content: Text(
          l10n.areYouSureLogOut,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            child: Text(l10n.logOut, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          l10n.deleteAccount,
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.typeDeleteConfirm,
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
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().toUpperCase() == 'DELETE') {
                Navigator.pop(dialogContext);
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.accountDeletionRequested,
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(l10n.pleaseTypeDelete),
                  ),
                );
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}


