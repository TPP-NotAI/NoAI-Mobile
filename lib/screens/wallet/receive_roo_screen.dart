import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallet_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/snackbar_utils.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class ReceiveRooScreen extends StatelessWidget {
  const ReceiveRooScreen({super.key});

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarUtils.showSuccess(context, 'Copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!user.isVerified) {
      return Scaffold(
        appBar: AppBar(title: Text('Receive ROO'.tr(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isVerificationPending
                      ? Icons.hourglass_top
                      : Icons.verified_user_outlined,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  user.isVerificationPending
                      ? 'Your verification is pending. You can receive ROO once approved.'
                      : 'Complete identity verification to access Receive ROO.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/verify'),
                  child: Text('Verify Now'.tr(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final backgroundColor = isDarkMode
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surfaceColor = isDarkMode
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final textPrimaryColor = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final borderColor = isDarkMode
        ? AppColors.outlineDark
        : AppColors.outlineLight;

    final walletProvider = context.watch<WalletProvider>();
    final walletAddress = walletProvider.wallet?.walletAddress ?? 'Loading...';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Receive ROO'.tr(context),
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Profile Info
            CircleAvatar(
              radius: 40,
              backgroundImage: user.avatar != null
                  ? NetworkImage(user.avatar!)
                  : null,
              backgroundColor: colors.surfaceContainerHighest,
              child: user.avatar == null
                  ? Icon(Icons.person, size: 40, color: colors.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName.isNotEmpty ? user.displayName : user.username,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('@${user.username}'.tr(context),
                  style: TextStyle(fontSize: 15, color: textSecondaryColor),
                ),
                if (user.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 40),

            // QR Code
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('Scan QR Code'.tr(context),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: QrImageView(
                        data: walletAddress,
                        version: QrVersions.auto,
                        size: 200.0,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Share this QR code to receive ROO'.tr(context),
                    style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Wallet Address Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Wallet Address'.tr(context),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          walletAddress,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: textPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () =>
                            _copyToClipboard(context, walletAddress),
                        icon: const Icon(Icons.copy, size: 20),
                        color: AppColors.primary,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Username Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Username'.tr(context),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('@${user.username}'.tr(context),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () =>
                            _copyToClipboard(context, '@${user.username}'),
                        icon: const Icon(Icons.copy, size: 20),
                        color: AppColors.primary,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Share Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Show share options
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: surfaceColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => Container(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textSecondaryColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Share Your Wallet'.tr(context),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildShareOption(
                            context,
                            Icons.link,
                            'Copy Wallet Address',
                            () {
                              _copyToClipboard(context, walletAddress);
                              Navigator.pop(context);
                            },
                            textPrimaryColor,
                            surfaceColor,
                            borderColor,
                          ),
                          const SizedBox(height: 12),
                          _buildShareOption(
                            context,
                            Icons.person,
                            'Copy Username',
                            () {
                              _copyToClipboard(context, '@${user.username}');
                              Navigator.pop(context);
                            },
                            textPrimaryColor,
                            surfaceColor,
                            borderColor,
                          ),
                          const SizedBox(height: 12),
                          _buildShareOption(
                            context,
                            Icons.qr_code,
                            'Save QR Code',
                            () {
                              Navigator.pop(context);
                              SnackBarUtils.showSuccess(
                                context,
                                'QR Code saved to gallery',
                              );
                            },
                            textPrimaryColor,
                            surfaceColor,
                            borderColor,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: Text('Share Wallet Info'.tr(context),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Share your wallet address or username with others to receive ROO coins. Only share with trusted sources.'.tr(context),
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimaryColor,
                        height: 1.4,
                      ),
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

  Widget _buildShareOption(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
    Color textColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
