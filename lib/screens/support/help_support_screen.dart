import 'package:flutter/material.dart';
import 'faq_screen.dart';
import 'support_chat_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'.tr(context)),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      backgroundColor: colors.surface,
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildTile(
            context,
            icon: Icons.help_center,
            iconColor: Colors.teal,
            title: 'FAQ / Help Center',
            subtitle: 'Browse frequently asked questions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FAQScreen()),
            ),
          ),
          _buildTile(
            context,
            icon: Icons.contact_support,
            iconColor: Colors.teal,
            title: 'Contact Support',
            subtitle: 'Chat with our support team',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportChatScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
