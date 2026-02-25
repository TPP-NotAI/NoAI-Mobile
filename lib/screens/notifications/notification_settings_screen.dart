import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_settings.dart';
import '../../widgets/loading_widget.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    if (authProvider.currentUser == null) {
      if (mounted) setState(() => _initialized = true);
      return;
    }

    await notificationProvider.loadSettings(authProvider.currentUser!.id);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _updateSetting(
    NotificationSettings currentSettings,
    NotificationSettings newSettings,
  ) {
    context.read<NotificationProvider>().updateSettings(newSettings).then((
      success,
    ) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Notification settings updated' : 'Failed to update settings',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final settings = notificationProvider.settings ??
        (authProvider.currentUser != null
            ? NotificationSettings(userId: authProvider.currentUser!.id)
            : null);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Notification Settings'.tr(context)),
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
      ),
      body: !_initialized || settings == null
          ? const Center(child: LoadingWidget())
          : ListView(
              children: [
                _buildSectionHeader(context, 'CHANNELS'),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts on your device',
                  value: settings.notifyPush,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyPush: val),
                  ),
                  icon: Icons.notifications_active_outlined,
                ),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  value: settings.notifyEmail,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyEmail: val),
                  ),
                  icon: Icons.email_outlined,
                ),
                _buildSwitchTile(
                  title: 'In-App Notifications',
                  subtitle: 'See alerts in the activity tab',
                  value: settings.notifyInApp,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyInApp: val),
                  ),
                  icon: Icons.app_registration_outlined,
                ),

                const SizedBox(height: 24),
                _buildSectionHeader(context, 'ACTIVITY'),
                _buildSwitchTile(
                  title: 'New Followers',
                  subtitle: 'When someone follows you',
                  value: settings.notifyFollows,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyFollows: val),
                  ),
                  icon: Icons.person_add_outlined,
                ),
                _buildSwitchTile(
                  title: 'Comments',
                  subtitle: 'When someone comments on your post',
                  value: settings.notifyComments,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyComments: val),
                  ),
                  icon: Icons.chat_bubble_outline,
                ),
                _buildSwitchTile(
                  title: 'Likes & Reactions',
                  subtitle: 'When someone interacts with your content',
                  value: settings.notifyLikes,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyLikes: val),
                  ),
                  icon: Icons.favorite_border,
                ),
                _buildSwitchTile(
                  title: 'Mentions',
                  subtitle: 'When someone tags you in a post',
                  value: settings.notifyMentions,
                  onChanged: (val) => _updateSetting(
                    settings,
                    settings.copyWith(notifyMentions: val),
                  ),
                  icon: Icons.alternate_email,
                ),

                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Note: These settings control which activities spark a notification. Email and push delivery depends on your global device and account settings.'.tr(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.onSurfaceVariant, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: colors.onSurfaceVariant.withOpacity(0.7),
          fontSize: 13,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: colors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
