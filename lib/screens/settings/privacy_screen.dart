import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../config/app_colors.dart';
import 'blocked_muted_users_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late String _postsVisibility; // everyone, followers, private
  late String _commentsVisibility;
  late String _messagesVisibility;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser != null) {
      // Load current privacy settings from the user model
      _postsVisibility = currentUser.postsVisibility ?? 'everyone';
      _commentsVisibility = currentUser.commentsVisibility ?? 'everyone';
      _messagesVisibility = currentUser.messagesVisibility ?? 'everyone';
    } else {
      // Default values if no user is logged in (shouldn't happen if screen is protected)
      _postsVisibility =
          'everyone'; // Default to everyone if no user or setting
      _commentsVisibility = 'everyone';
      _messagesVisibility = 'everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Privacy Settings'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('POSTS'),
          _buildVisibilitySelector(
            title: 'Who can see my posts?',
            value: _postsVisibility,
            onChanged: (value) => setState(() => _postsVisibility = value),
          ),

          SizedBox(height: 24),

          _buildSectionHeader('COMMENTS'),
          _buildVisibilitySelector(
            title: 'Who can see my comments?',
            value: _commentsVisibility,
            onChanged: (value) => setState(() => _commentsVisibility = value),
          ),

          SizedBox(height: 24),

          _buildVisibilitySelector(
            title: 'Who can send me messages?',
            value: _messagesVisibility,
            onChanged: (value) => setState(() => _messagesVisibility = value),
          ),

          SizedBox(height: 32),

          _buildSectionHeader('SAFETY'),
          _buildSettingsLink(
            title: 'Blocked Users',
            subtitle: 'Users you have blocked cannot interact with you',
            icon: Icons.block,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BlockedMutedUsersScreen(initialIndex: 0),
              ),
            ),
          ),

          SizedBox(height: 48),

          ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(_isSaving ? 'Saving...' : 'Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildVisibilitySelector({
    required String title,
    required String value,
    required Function(String) onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: 16),
          _buildRadioOption('Everyone', 'everyone', value, onChanged),
          _buildRadioOption('Followers only', 'followers', value, onChanged),
          _buildRadioOption('Private (only me)', 'private', value, onChanged),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    String label,
    String optionValue,
    String currentValue,
    Function(String) onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(optionValue),
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Radio<String>(
              value: optionValue,
              groupValue: currentValue,
              onChanged: (value) => onChanged(value!),
              activeColor: AppColors.primary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: scheme.onSurface),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _saveSettings() async {
    if (_isSaving) return;

    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not logged in.'.tr(context)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final success = await userProvider.updatePrivacySettings(
      userId: currentUser.id,
      postsVisibility: _postsVisibility,
      commentsVisibility: _commentsVisibility,
      messagesVisibility: _messagesVisibility,
    );
    if (mounted) {
      setState(() => _isSaving = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Privacy settings saved successfully'
                : (userProvider.error ?? 'Failed to save privacy settings'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingsLink({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
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
            Icon(Icons.chevron_right, color: scheme.onSurface.withOpacity(0.3)),
          ],
        ),
        ),
      ),
    );
  }
}
