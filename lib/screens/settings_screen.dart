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
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/wallet_provider.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
              child: Text('${(context.watch<WalletProvider>().wallet?.balanceRc ?? currentUser?.balance ?? 0).toStringAsFixed(2)} ROO',
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
                      : currentUser?.username ??
                          _localizedSettingsText(context, 'userFallback'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
                Text('@${currentUser?.username ?? _localizedSettingsText(context, 'unknownUsername')}',
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionAccount'),
          ),
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
                ? AppColors.primary
                : AppColors.warning,
            title: l10n.humanVerification,
            subtitle: _getVerificationStatus(context, currentUser?.verifiedHuman),
            onTap: () {
              if (currentUser?.verifiedHuman == 'verified') {
                _showAlreadyVerifiedDialog(context);
                return;
              }
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionRoochipWallet'),
          ),
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionPreferences'),
          ),
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
            title: _localizedSettingsText(context, 'blockedUsers'),
            subtitle: _localizedSettingsText(context, 'blockedUsersSubtitle'),
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionSupport'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.help_center,
            iconColor: Colors.teal,
            title: l10n.helpCenter,
            subtitle: _localizedSettingsText(context, 'helpCenterSubtitle'),
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
                title: _localizedSettingsText(context, 'supportTicketsAdmin'),
                subtitle: _localizedSettingsText(
                  context,
                  'supportTicketsAdminSubtitle',
                ),
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
            title: _localizedSettingsText(context, 'myFlaggedContent'),
            subtitle: _localizedSettingsText(
              context,
              'myFlaggedContentSubtitle',
            ),
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
                title: _localizedSettingsText(context, 'moderationQueue'),
                subtitle: _localizedSettingsText(
                  context,
                  'moderationQueueSubtitle',
                ),
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
            title: _localizedSettingsText(context, 'checkForUpdates'),
            onTap: () async {
              await AppUpdateService.instance.checkAndPromptForUpdate(
                context,
                manual: true,
              );
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionLegal'),
          ),
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

          _buildSectionHeader(context, 'DATA & PRIVACY'),
          _buildSettingsTile(
            context,
            icon: Icons.download_outlined,
            iconColor: Colors.teal,
            title: 'Export My Data',
            subtitle: 'Download a copy of all your personal data (GDPR)',
            onTap: () => _exportUserData(context),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionDangerZone'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.pause_circle_outline,
            iconColor: Colors.orange,
            title: _localizedSettingsText(context, 'deactivateAccount'),
            subtitle: _localizedSettingsText(context, 'deactivateAccountSubtitle'),
            onTap: () => _showDeactivateAccountDialog(context),
          ),
          if (currentUser?.isPendingDeletion == true)
            _buildSettingsTile(
              context,
              icon: Icons.cancel_schedule_send,
              iconColor: Colors.green,
              title: _localizedSettingsText(context, 'cancelDeletion'),
              subtitle: _buildCancelDeletionSubtitle(context, currentUser?.deletionScheduledAt),
              onTap: () => _showCancelDeletionDialog(context),
            ),
          if (currentUser?.isPendingDeletion != true)
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

  static void _showAlreadyVerifiedDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Row(
          children: [
            Icon(Icons.verified_user, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Verified', style: TextStyle(color: scheme.onSurface)),
          ],
        ),
        content: Text(
          'You are already verified as a human. No further action is needed.',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  static Future<void> _exportUserData(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Text(
            'Export My Data',
            style: TextStyle(color: scheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will generate a JSON file containing all your personal data stored on Rooverse, including your profile, posts, comments, wallet history, and activity log.',
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Preparing your data...',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        final session = SupabaseService().currentSession;
                        final accessToken = session?.accessToken;
                        if (accessToken == null) throw Exception('Not authenticated');

                        final response = await SupabaseService().client.functions.invoke(
                          'user-data-export',
                          headers: {'Authorization': 'Bearer $accessToken'},
                        );

                        // Check for errors returned by the function
                        if (response.data is Map && response.data['error'] != null) {
                          throw Exception(response.data['error']);
                        }

                        // Serialize the response data to JSON string
                        final jsonString = jsonEncode(response.data);

                        // Write to a temp file
                        final dir = await getTemporaryDirectory();
                        final userId = SupabaseService().currentUser?.id ?? 'unknown';
                        final fileName = 'data-export-$userId.json';
                        final file = File('${dir.path}/$fileName');
                        await file.writeAsString(jsonString);

                        if (dialogContext.mounted) Navigator.pop(dialogContext);

                        // Share/save the file
                        await Share.shareXFiles(
                          [XFile(file.path, mimeType: 'application/json')],
                          subject: 'My Data Export',
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Export failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  static void _showDeactivateAccountDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Row(
            children: [
              const Icon(Icons.pause_circle_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                _localizedSettingsText(context, 'deactivateAccount'),
                style: TextStyle(color: scheme.onSurface),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedSettingsText(context, 'deactivateAccountDescription'),
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: _localizedSettingsText(context, 'enterPasswordToConfirm'),
                    filled: true,
                    fillColor: scheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(_localizedSettingsText(context, 'cancel')),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(_localizedSettingsText(context, 'enterPasswordToConfirm'))),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      try {
                        final auth = context.read<AuthProvider>();
                        await auth.deactivateAccount(passwordController.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          final msg = e.toString().contains('Incorrect password')
                              ? _localizedSettingsText(context, 'incorrectPassword')
                              : _localizedSettingsText(context, 'somethingWentWrong');
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _localizedSettingsText(context, 'deactivate'),
                      style: const TextStyle(color: Colors.orange),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => passwordController.dispose());
  }

  static String _buildCancelDeletionSubtitle(BuildContext context, DateTime? deadline) {
    if (deadline == null) return _localizedSettingsText(context, 'cancelDeletionSubtitle');
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    final code = Localizations.localeOf(context).languageCode;
    final templates = <String, String>{
      'en': 'Account deletes in $daysLeft day${daysLeft == 1 ? '' : 's'} — tap to cancel',
      'es': 'La cuenta se elimina en $daysLeft día${daysLeft == 1 ? '' : 's'} — toca para cancelar',
      'fr': 'Suppression dans $daysLeft jour${daysLeft == 1 ? '' : 's'} — appuyez pour annuler',
      'de': 'Konto wird in $daysLeft Tag${daysLeft == 1 ? '' : 'en'} gelöscht — zum Abbrechen tippen',
      'it': 'L\'account verrà eliminato tra $daysLeft giorno${daysLeft == 1 ? '' : 'i'} — tocca per annullare',
      'pt': 'Conta excluída em $daysLeft dia${daysLeft == 1 ? '' : 's'} — toque para cancelar',
      'ru': 'Аккаунт будет удалён через $daysLeft д${daysLeft == 1 ? 'ень' : 'ней'} — нажмите для отмены',
      'zh': '账户将在 $daysLeft 天后删除 — 点击取消',
      'ja': '$daysLeft 日後に削除されます — タップしてキャンセル',
      'ko': '$daysLeft 일 후 삭제됩니다 — 취소하려면 탭',
      'ar': 'الحساب يُحذف خلال $daysLeft يوم — اضغط للإلغاء',
      'hi': '$daysLeft दिन में खाता हटाया जाएगा — रद्द करने के लिए टैप करें',
    };
    return templates[code] ?? templates['en']!;
  }

  static void _showCancelDeletionDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Row(
            children: [
              const Icon(Icons.cancel_schedule_send, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                _localizedSettingsText(context, 'cancelDeletion'),
                style: TextStyle(color: scheme.onSurface),
              ),
            ],
          ),
          content: Text(
            _localizedSettingsText(context, 'cancelDeletionDescription'),
            style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(_localizedSettingsText(context, 'cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        await context.read<AuthProvider>().cancelAccountDeletion();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_localizedSettingsText(context, 'cancelDeletionSuccess')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(_localizedSettingsText(context, 'somethingWentWrong')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_localizedSettingsText(context, 'keepMyAccount')),
            ),
          ],
        ),
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final confirmController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Text(
            l10n.deleteAccount,
            style: TextStyle(color: scheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.typeDeleteConfirm,
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: _localizedSettingsText(context, 'typeDeleteHint'),
                    filled: true,
                    fillColor: scheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Enter your password to confirm',
                    filled: true,
                    fillColor: scheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (confirmController.text.trim().toUpperCase() != 'DELETE') {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(l10n.pleaseTypeDelete)),
                        );
                        return;
                      }
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter your password.')),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      try {
                        final auth = context.read<AuthProvider>();
                        await auth.requestAccountDeletion(passwordController.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Your account has been permanently deleted.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          final msg = e.toString().contains('Invalid credentials')
                              ? 'Incorrect password.'
                              : 'Something went wrong. Please try again.';
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      confirmController.dispose();
      passwordController.dispose();
    });
  }

  static String _localizedSettingsText(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;

    const values = <String, Map<String, String>>{
      'userFallback': {
        'en': 'User',
        'es': 'Usuario',
        'fr': 'Utilisateur',
        'de': 'Benutzer',
        'it': 'Utente',
        'pt': 'Usuario',
        'ru': 'Пользователь',
        'zh': '用户',
        'ja': 'ユーザー',
        'ko': '사용자',
        'ar': 'مستخدم',
        'hi': 'उपयोगकर्ता',
      },
      'unknownUsername': {
        'en': 'unknown',
        'es': 'desconocido',
        'fr': 'inconnu',
        'de': 'unbekannt',
        'it': 'sconosciuto',
        'pt': 'desconhecido',
        'ru': 'неизвестно',
        'zh': '未知',
        'ja': '不明',
        'ko': '알 수 없음',
        'ar': 'غير معروف',
        'hi': 'अज्ञात',
      },
      'sectionAccount': {
        'en': 'ACCOUNT',
        'es': 'CUENTA',
        'fr': 'COMPTE',
        'de': 'KONTO',
        'it': 'ACCOUNT',
        'pt': 'CONTA',
        'ru': 'АККАУНТ',
        'zh': '账户',
        'ja': 'アカウント',
        'ko': '계정',
        'ar': 'الحساب',
        'hi': 'खाता',
      },
      'sectionRoochipWallet': {
        'en': 'ROOCHIP WALLET',
        'es': 'CARTERA ROOCHIP',
        'fr': 'PORTEFEUILLE ROOCHIP',
        'de': 'ROOCHIP-WALLET',
        'it': 'PORTAFOGLIO ROOCHIP',
        'pt': 'CARTEIRA ROOCHIP',
        'ru': 'КОШЕЛЁК ROOCHIP',
        'zh': 'ROOCHIP 钱包',
        'ja': 'ROOCHIPウォレット',
        'ko': 'ROOCHIP 지갑',
        'ar': 'محفظة ROOCHIP',
        'hi': 'ROOCHIP वॉलेट',
      },
      'sectionPreferences': {
        'en': 'PREFERENCES',
        'es': 'PREFERENCIAS',
        'fr': 'PREFERENCES',
        'de': 'EINSTELLUNGEN',
        'it': 'PREFERENZE',
        'pt': 'PREFERÊNCIAS',
        'ru': 'ПРЕДПОЧТЕНИЯ',
        'zh': '偏好设置',
        'ja': '設定',
        'ko': '환경설정',
        'ar': 'التفضيلات',
        'hi': 'प्राथमिकताएं',
      },
      'blockedUsers': {
        'en': 'Blocked Users',
        'es': 'Usuarios bloqueados',
        'fr': 'Utilisateurs bloques',
        'de': 'Blockierte Nutzer',
        'it': 'Utenti bloccati',
        'pt': 'Usuarios bloqueados',
        'ru': 'Заблокированные пользователи',
        'zh': '已屏蔽用户',
        'ja': 'ブロックしたユーザー',
        'ko': '차단된 사용자',
        'ar': 'المستخدمون المحظورون',
        'hi': 'ब्लॉक किए गए उपयोगकर्ता',
      },
      'blockedUsersSubtitle': {
        'en': 'Manage users you have blocked',
        'es': 'Administra los usuarios que has bloqueado',
        'fr': 'Gerez les utilisateurs que vous avez bloques',
        'de': 'Verwalte Nutzer, die du blockiert hast',
        'it': 'Gestisci gli utenti che hai bloccato',
        'pt': 'Gerencie os usuarios que voce bloqueou',
        'ru': 'Управляйте пользователями, которых вы заблокировали',
        'zh': '管理你已屏蔽的用户',
        'ja': 'ブロックしたユーザーを管理',
        'ko': '차단한 사용자를 관리합니다',
        'ar': 'إدارة المستخدمين الذين قمت بحظرهم',
        'hi': 'जिन उपयोगकर्ताओं को आपने ब्लॉक किया है उन्हें प्रबंधित करें',
      },
      'sectionSupport': {
        'en': 'SUPPORT',
        'es': 'SOPORTE',
        'fr': 'ASSISTANCE',
        'de': 'SUPPORT',
        'it': 'SUPPORTO',
        'pt': 'SUPORTE',
        'ru': 'ПОДДЕРЖКА',
        'zh': '支持',
        'ja': 'サポート',
        'ko': '지원',
        'ar': 'الدعم',
        'hi': 'सहायता',
      },
      'helpCenterSubtitle': {
        'en': 'FAQ and contact support',
        'es': 'Preguntas frecuentes y contacto con soporte',
        'fr': 'FAQ et contact du support',
        'de': 'FAQ und Support kontaktieren',
        'it': 'FAQ e contatta il supporto',
        'pt': 'FAQ e contato com o suporte',
        'ru': 'FAQ и обращение в поддержку',
        'zh': '常见问题与联系客服',
        'ja': 'FAQとサポートへの連絡',
        'ko': 'FAQ 및 지원팀 문의',
        'ar': 'الأسئلة الشائعة والتواصل مع الدعم',
        'hi': 'FAQ और सहायता से संपर्क',
      },
      'supportTicketsAdmin': {
        'en': 'Support Tickets (Admin)',
        'es': 'Tickets de soporte (Admin)',
        'fr': 'Tickets de support (Admin)',
        'de': 'Support-Tickets (Admin)',
        'it': 'Ticket di supporto (Admin)',
        'pt': 'Tickets de suporte (Admin)',
        'ru': 'Тикеты поддержки (админ)',
        'zh': '支持工单（管理员）',
        'ja': 'サポートチケット（管理者）',
        'ko': '지원 티켓(관리자)',
        'ar': 'تذاكر الدعم (المسؤول)',
        'hi': 'सपोर्ट टिकट (एडमिन)',
      },
      'supportTicketsAdminSubtitle': {
        'en': 'Review submitted support tickets',
        'es': 'Revisar tickets de soporte enviados',
        'fr': 'Examiner les tickets de support soumis',
        'de': 'Eingereichte Support-Tickets pruefen',
        'it': 'Controlla i ticket di supporto inviati',
        'pt': 'Revisar tickets de suporte enviados',
        'ru': 'Проверка отправленных тикетов поддержки',
        'zh': '查看已提交的支持工单',
        'ja': '送信されたサポートチケットを確認',
        'ko': '제출된 지원 티켓 검토',
        'ar': 'مراجعة تذاكر الدعم المرسلة',
        'hi': 'जमा किए गए सपोर्ट टिकट की समीक्षा करें',
      },
      'myFlaggedContent': {
        'en': 'My Flagged Content',
        'es': 'Mi contenido marcado',
        'fr': 'Mon contenu signale',
        'de': 'Meine markierten Inhalte',
        'it': 'I miei contenuti segnalati',
        'pt': 'Meu conteudo sinalizado',
        'ru': 'Мой отмеченный контент',
        'zh': '我被标记的内容',
        'ja': '自分のフラグ付きコンテンツ',
        'ko': '내가 표시된 콘텐츠',
        'ar': 'المحتوى المعلّم الخاص بي',
        'hi': 'मेरी चिन्हित सामग्री',
      },
      'myFlaggedContentSubtitle': {
        'en': 'View, appeal or delete AI-flagged posts & comments',
        'es': 'Ver, apelar o eliminar publicaciones y comentarios marcados por IA',
        'fr': 'Voir, contester ou supprimer les publications et commentaires signales par IA',
        'de': 'Von KI markierte Beitraege und Kommentare ansehen, anfechten oder loeschen',
        'it': 'Visualizza, contesta o elimina post e commenti segnalati dall IA',
        'pt': 'Ver, recorrer ou excluir posts e comentarios sinalizados por IA',
        'ru': 'Просмотр, обжалование или удаление постов и комментариев, отмеченных ИИ',
        'zh': '查看、申诉或删除被 AI 标记的帖子和评论',
        'ja': 'AIにフラグされた投稿とコメントを表示・異議申し立て・削除',
        'ko': 'AI가 표시한 게시물 및 댓글 보기, 이의제기 또는 삭제',
        'ar': 'عرض أو الاعتراض على أو حذف المنشورات والتعليقات التي علّمها الذكاء الاصطناعي',
        'hi': 'AI द्वारा चिन्हित पोस्ट और टिप्पणियाँ देखें, अपील करें या हटाएँ',
      },
      'moderationQueue': {
        'en': 'Moderation Queue',
        'es': 'Cola de moderacion',
        'fr': 'File de moderation',
        'de': 'Moderationswarteschlange',
        'it': 'Coda di moderazione',
        'pt': 'Fila de moderacao',
        'ru': 'Очередь модерации',
        'zh': '审核队列',
        'ja': 'モデレーションキュー',
        'ko': '검토 대기열',
        'ar': 'قائمة الإشراف',
        'hi': 'मॉडरेशन कतार',
      },
      'moderationQueueSubtitle': {
        'en': 'Review AI-flagged content',
        'es': 'Revisar contenido marcado por IA',
        'fr': 'Examiner le contenu signale par IA',
        'de': 'Von KI markierte Inhalte pruefen',
        'it': 'Controlla i contenuti segnalati dall IA',
        'pt': 'Revisar conteudo sinalizado por IA',
        'ru': 'Проверка контента, отмеченного ИИ',
        'zh': '审核被 AI 标记的内容',
        'ja': 'AIにフラグされたコンテンツを確認',
        'ko': 'AI가 표시한 콘텐츠 검토',
        'ar': 'مراجعة المحتوى الذي علّمه الذكاء الاصطناعي',
        'hi': 'AI द्वारा चिन्हित सामग्री की समीक्षा करें',
      },
      'checkForUpdates': {
        'en': 'Check for Updates',
        'es': 'Buscar actualizaciones',
        'fr': 'Rechercher des mises a jour',
        'de': 'Nach Updates suchen',
        'it': 'Controlla aggiornamenti',
        'pt': 'Verificar atualizacoes',
        'ru': 'Проверить обновления',
        'zh': '检查更新',
        'ja': 'アップデートを確認',
        'ko': '업데이트 확인',
        'ar': 'التحقق من التحديثات',
        'hi': 'अपडेट जांचें',
      },
      'sectionLegal': {
        'en': 'LEGAL',
        'es': 'LEGAL',
        'fr': 'LEGAL',
        'de': 'RECHTLICHES',
        'it': 'LEGALE',
        'pt': 'LEGAL',
        'ru': 'ЮРИДИЧЕСКОЕ',
        'zh': '法律',
        'ja': '法的情報',
        'ko': '법률',
        'ar': 'قانوني',
        'hi': 'कानूनी',
      },
      'sectionDangerZone': {
        'en': 'DANGER ZONE',
        'es': 'ZONA DE PELIGRO',
        'fr': 'ZONE DE DANGER',
        'de': 'GEFAHRENBEREICH',
        'it': 'ZONA DI PERICOLO',
        'pt': 'ZONA DE PERIGO',
        'ru': 'ОПАСНАЯ ЗОНА',
        'zh': '危险区域',
        'ja': '危険ゾーン',
        'ko': '위험 구역',
        'ar': 'منطقة الخطر',
        'hi': 'खतरे का क्षेत्र',
      },
      'deactivateAccount': {
        'en': 'Deactivate Account',
        'es': 'Desactivar cuenta',
        'fr': 'Désactiver le compte',
        'de': 'Konto deaktivieren',
        'it': 'Disattiva account',
        'pt': 'Desativar conta',
        'ru': 'Деактивировать аккаунт',
        'zh': '停用账户',
        'ja': 'アカウントを無効化',
        'ko': '계정 비활성화',
        'ar': 'تعطيل الحساب',
        'hi': 'खाता निष्क्रिय करें',
      },
      'deactivateAccountSubtitle': {
        'en': 'Temporarily disable your account',
        'es': 'Deshabilitar temporalmente tu cuenta',
        'fr': 'Désactiver temporairement votre compte',
        'de': 'Konto vorübergehend deaktivieren',
        'it': 'Disabilita temporaneamente il tuo account',
        'pt': 'Desabilitar temporariamente sua conta',
        'ru': 'Временно отключить аккаунт',
        'zh': '暂时禁用您的账户',
        'ja': 'アカウントを一時的に無効化',
        'ko': '계정을 일시적으로 비활성화',
        'ar': 'تعطيل حسابك مؤقتاً',
        'hi': 'अपना खाता अस्थायी रूप से अक्षम करें',
      },
      'deactivateAccountDescription': {
        'en': 'Your account will become dormant — no posts, no activities. You can reactivate it anytime by signing back in.',
        'es': 'Tu cuenta quedará inactiva: sin publicaciones ni actividad. Puedes reactivarla iniciando sesión nuevamente.',
        'fr': 'Votre compte deviendra inactif — aucun post, aucune activité. Vous pouvez le réactiver en vous reconnectant.',
        'de': 'Dein Konto wird inaktiv — keine Beiträge, keine Aktivitäten. Du kannst es jederzeit durch erneutes Anmelden reaktivieren.',
        'it': 'Il tuo account diventerà inattivo — nessun post, nessuna attività. Puoi riattivarlo accedendo di nuovo.',
        'pt': 'Sua conta ficará inativa — sem publicações, sem atividades. Você pode reativá-la fazendo login novamente.',
        'ru': 'Ваш аккаунт станет неактивным — никаких публикаций и действий. Вы можете реактивировать его, снова войдя в систему.',
        'zh': '您的账户将变为休眠状态——无法发帖、无法活动。您可以随时重新登录来激活账户。',
        'ja': 'アカウントが休止状態になります。投稿や活動はできません。再度サインインすることでいつでも再有効化できます。',
        'ko': '계정이 휴면 상태가 됩니다 — 게시물 없음, 활동 없음. 다시 로그인하면 언제든지 재활성화할 수 있습니다.',
        'ar': 'سيصبح حسابك خاملاً — لا منشورات، لا نشاط. يمكنك إعادة تفعيله في أي وقت بتسجيل الدخول مجدداً.',
        'hi': 'आपका खाता निष्क्रिय हो जाएगा — कोई पोस्ट नहीं, कोई गतिविधि नहीं। आप दोबारा साइन इन करके इसे कभी भी पुनः सक्रिय कर सकते हैं।',
      },
      'deactivate': {
        'en': 'Deactivate',
        'es': 'Desactivar',
        'fr': 'Désactiver',
        'de': 'Deaktivieren',
        'it': 'Disattiva',
        'pt': 'Desativar',
        'ru': 'Деактивировать',
        'zh': '停用',
        'ja': '無効化',
        'ko': '비활성화',
        'ar': 'تعطيل',
        'hi': 'निष्क्रिय करें',
      },
      'enterPasswordToConfirm': {
        'en': 'Enter your password to confirm',
        'es': 'Ingresa tu contraseña para confirmar',
        'fr': 'Entrez votre mot de passe pour confirmer',
        'de': 'Passwort zur Bestätigung eingeben',
        'it': 'Inserisci la tua password per confermare',
        'pt': 'Digite sua senha para confirmar',
        'ru': 'Введите пароль для подтверждения',
        'zh': '输入密码以确认',
        'ja': '確認のためパスワードを入力',
        'ko': '확인을 위해 비밀번호를 입력하세요',
        'ar': 'أدخل كلمة المرور للتأكيد',
        'hi': 'पुष्टि के लिए अपना पासवर्ड दर्ज करें',
      },
      'incorrectPassword': {
        'en': 'Incorrect password.',
        'es': 'Contraseña incorrecta.',
        'fr': 'Mot de passe incorrect.',
        'de': 'Falsches Passwort.',
        'it': 'Password errata.',
        'pt': 'Senha incorreta.',
        'ru': 'Неверный пароль.',
        'zh': '密码错误。',
        'ja': 'パスワードが違います。',
        'ko': '잘못된 비밀번호입니다.',
        'ar': 'كلمة المرور غير صحيحة.',
        'hi': 'गलत पासवर्ड।',
      },
      'somethingWentWrong': {
        'en': 'Something went wrong. Please try again.',
        'es': 'Algo salió mal. Inténtalo de nuevo.',
        'fr': 'Quelque chose a mal tourné. Veuillez réessayer.',
        'de': 'Etwas ist schief gelaufen. Bitte versuche es erneut.',
        'it': 'Qualcosa è andato storto. Riprova.',
        'pt': 'Algo deu errado. Por favor, tente novamente.',
        'ru': 'Что-то пошло не так. Пожалуйста, попробуйте ещё раз.',
        'zh': '出了点问题，请重试。',
        'ja': '問題が発生しました。もう一度お試しください。',
        'ko': '문제가 발생했습니다. 다시 시도해 주세요.',
        'ar': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
        'hi': 'कुछ गलत हो गया। कृपया फिर से प्रयास करें।',
      },
      'cancel': {
        'en': 'Cancel',
        'es': 'Cancelar',
        'fr': 'Annuler',
        'de': 'Abbrechen',
        'it': 'Annulla',
        'pt': 'Cancelar',
        'ru': 'Отмена',
        'zh': '取消',
        'ja': 'キャンセル',
        'ko': '취소',
        'ar': 'إلغاء',
        'hi': 'रद्द करें',
      },
      'cancelDeletion': {
        'en': 'Cancel Account Deletion',
        'es': 'Cancelar eliminación de cuenta',
        'fr': 'Annuler la suppression du compte',
        'de': 'Kontolöschung abbrechen',
        'it': 'Annulla eliminazione account',
        'pt': 'Cancelar exclusão da conta',
        'ru': 'Отменить удаление аккаунта',
        'zh': '取消删除账户',
        'ja': 'アカウント削除をキャンセル',
        'ko': '계정 삭제 취소',
        'ar': 'إلغاء حذف الحساب',
        'hi': 'खाता हटाना रद्द करें',
      },
      'cancelDeletionSubtitle': {
        'en': 'Your account is scheduled for deletion — tap to cancel',
        'es': 'Tu cuenta está programada para eliminarse — toca para cancelar',
        'fr': 'Votre compte est programmé pour être supprimé — appuyez pour annuler',
        'de': 'Dein Konto ist zur Löschung vorgesehen — tippen zum Abbrechen',
        'it': 'Il tuo account è programmato per l\'eliminazione — tocca per annullare',
        'pt': 'Sua conta está agendada para exclusão — toque para cancelar',
        'ru': 'Ваш аккаунт запланирован к удалению — нажмите для отмены',
        'zh': '您的账户已安排删除 — 点击取消',
        'ja': 'アカウントの削除が予定されています — タップしてキャンセル',
        'ko': '계정 삭제가 예약되었습니다 — 취소하려면 탭',
        'ar': 'حسابك مجدول للحذف — اضغط للإلغاء',
        'hi': 'आपका खाता हटाने के लिए निर्धारित है — रद्द करने के लिए टैप करें',
      },
      'cancelDeletionDescription': {
        'en': 'Your account deletion will be cancelled and your account will be fully restored.',
        'es': 'La eliminación de tu cuenta se cancelará y tu cuenta se restaurará completamente.',
        'fr': 'La suppression de votre compte sera annulée et votre compte sera entièrement restauré.',
        'de': 'Die Kontolöschung wird abgebrochen und dein Konto wird vollständig wiederhergestellt.',
        'it': 'L\'eliminazione dell\'account verrà annullata e il tuo account sarà completamente ripristinato.',
        'pt': 'A exclusão da sua conta será cancelada e sua conta será totalmente restaurada.',
        'ru': 'Удаление аккаунта будет отменено, и ваш аккаунт будет полностью восстановлен.',
        'zh': '您的账户删除将被取消，账户将完全恢复。',
        'ja': 'アカウントの削除がキャンセルされ、アカウントが完全に復元されます。',
        'ko': '계정 삭제가 취소되고 계정이 완전히 복원됩니다.',
        'ar': 'سيتم إلغاء حذف حسابك واستعادة حسابك بالكامل.',
        'hi': 'आपके खाते को हटाना रद्द कर दिया जाएगा और आपका खाता पूरी तरह से बहाल हो जाएगा।',
      },
      'cancelDeletionSuccess': {
        'en': 'Account deletion cancelled. Welcome back!',
        'es': 'Eliminación de cuenta cancelada. ¡Bienvenido de nuevo!',
        'fr': 'Suppression du compte annulée. Bon retour !',
        'de': 'Kontolöschung abgebrochen. Willkommen zurück!',
        'it': 'Eliminazione account annullata. Bentornato!',
        'pt': 'Exclusão de conta cancelada. Bem-vindo de volta!',
        'ru': 'Удаление аккаунта отменено. С возвращением!',
        'zh': '账户删除已取消。欢迎回来！',
        'ja': 'アカウント削除がキャンセルされました。おかえりなさい！',
        'ko': '계정 삭제가 취소되었습니다. 다시 오신 것을 환영합니다!',
        'ar': 'تم إلغاء حذف الحساب. مرحباً بعودتك!',
        'hi': 'खाता हटाना रद्द कर दिया गया। वापस स्वागत है!',
      },
      'keepMyAccount': {
        'en': 'Keep My Account',
        'es': 'Mantener mi cuenta',
        'fr': 'Conserver mon compte',
        'de': 'Konto behalten',
        'it': 'Mantieni il mio account',
        'pt': 'Manter minha conta',
        'ru': 'Оставить аккаунт',
        'zh': '保留我的账户',
        'ja': 'アカウントを保持',
        'ko': '계정 유지',
        'ar': 'الاحتفاظ بحسابي',
        'hi': 'मेरा खाता रखें',
      },
      'typeDeleteHint': {
        'en': 'Type DELETE',
        'es': 'Escribe DELETE',
        'fr': 'Tapez DELETE',
        'de': 'DELETE eingeben',
        'it': 'Digita DELETE',
        'pt': 'Digite DELETE',
        'ru': 'Введите DELETE',
        'zh': '输入 DELETE',
        'ja': 'DELETE と入力',
        'ko': 'DELETE 입력',
        'ar': 'اكتب DELETE',
        'hi': 'DELETE टाइप करें',
      },
    };

    return values[key]?[code] ?? values[key]?['en'] ?? key;
  }
}


