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
                      : currentUser?.username ??
                          _localizedSettingsText(context, 'userFallback'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
                Text(
                  '@${currentUser?.username ?? _localizedSettingsText(context, 'unknownUsername')}',
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionRoobyteWallet'),
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

          _buildSectionHeader(
            context,
            _localizedSettingsText(context, 'sectionDangerZone'),
          ),
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
                hintText: _localizedSettingsText(context, 'typeDeleteHint'),
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
    ).whenComplete(controller.dispose);
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
      'sectionRoobyteWallet': {
        'en': 'ROOBYTE WALLET',
        'es': 'CARTERA ROOBYTE',
        'fr': 'PORTEFEUILLE ROOBYTE',
        'de': 'ROOBYTE-WALLET',
        'it': 'PORTAFOGLIO ROOBYTE',
        'pt': 'CARTEIRA ROOBYTE',
        'ru': 'КОШЕЛЁК ROOBYTE',
        'zh': 'ROOBYTE 钱包',
        'ja': 'ROOBYTEウォレット',
        'ko': 'ROOBYTE 지갑',
        'ar': 'محفظة ROOBYTE',
        'hi': 'ROOBYTE वॉलेट',
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


