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
  late String _postsVisibility;
  late String _commentsVisibility;
  late String _messagesVisibility;
  bool _isSaving = false;

  // Private account = posts & comments locked to 'followers'
  bool get _isPrivateAccount => _postsVisibility == 'followers';

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<UserProvider>().currentUser;
    _postsVisibility = currentUser?.postsVisibility ?? 'everyone';
    _commentsVisibility = currentUser?.commentsVisibility ?? 'everyone';
    _messagesVisibility = currentUser?.messagesVisibility ?? 'everyone';
  }

  void _setPrivateAccount(bool isPrivate) {
    setState(() {
      if (isPrivate) {
        _postsVisibility = 'followers';
        _commentsVisibility = 'followers';
        _messagesVisibility = 'followers';
      } else {
        _postsVisibility = 'everyone';
        _commentsVisibility = 'everyone';
        _messagesVisibility = 'everyone';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(
          'Privacy Settings'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Account Type ─────────────────────────────────────────
          _buildSectionHeader('ACCOUNT TYPE'),
          _buildPrivateAccountTile(scheme),

          const SizedBox(height: 28),

          // ── Posts ─────────────────────────────────────────────────
          _buildSectionHeader('POSTS'),
          _buildVisibilitySelector(
            title: 'Who can see my posts?',
            value: _postsVisibility,
            enabled: !_isPrivateAccount,
            onChanged: (v) => setState(() => _postsVisibility = v),
          ),

          const SizedBox(height: 24),

          // ── Comments ──────────────────────────────────────────────
          _buildSectionHeader('COMMENTS'),
          _buildVisibilitySelector(
            title: 'Who can see my comments?',
            value: _commentsVisibility,
            enabled: !_isPrivateAccount,
            onChanged: (v) => setState(() => _commentsVisibility = v),
          ),

          const SizedBox(height: 24),

          // ── Messages ──────────────────────────────────────────────
          _buildSectionHeader('MESSAGES'),
          _buildVisibilitySelector(
            title: 'Who can send me messages?',
            value: _messagesVisibility,
            enabled: !_isPrivateAccount,
            onChanged: (v) => setState(() => _messagesVisibility = v),
          ),

          const SizedBox(height: 32),

          // ── Safety ────────────────────────────────────────────────
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

          const SizedBox(height: 48),

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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrivateAccountTile(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPrivateAccount
              ? AppColors.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isPrivateAccount
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isPrivateAccount ? Icons.lock : Icons.lock_open,
              color: _isPrivateAccount
                  ? AppColors.primary
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPrivateAccount
                      ? 'Only your followers can see your content'
                      : 'Anyone can see your posts and profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isPrivateAccount,
            onChanged: _setPrivateAccount,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVisibilitySelector({
    required String title,
    required String value,
    required bool enabled,
    required Function(String) onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildRadioOption('Everyone', 'everyone', value, enabled ? onChanged : (_) {}),
            _buildRadioOption('Followers only', 'followers', value, enabled ? onChanged : (_) {}),
            _buildRadioOption('Private (only me)', 'private', value, enabled ? onChanged : (_) {}),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Radio<String>(
                value: optionValue,
                groupValue: currentValue,
                onChanged: (v) => onChanged(v!),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : null,
                ),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
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
    if (mounted) setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Privacy settings saved successfully'
                : (userProvider.error ?? 'Failed to save privacy settings'),
          ),
          backgroundColor: success ? AppColors.primary : AppColors.error,
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
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.redAccent, size: 24),
              const SizedBox(width: 16),
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
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
