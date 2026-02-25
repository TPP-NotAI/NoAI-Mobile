import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension HardcodedL10nString on String {
  String tr(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return this;
    return _translateExact(l10n, this) ?? this;
  }
}

String? _translateExact(AppLocalizations l10n, String value) {
  switch (value) {
    case 'ROOVERSE':
      return l10n.appName;
    case 'Settings':
      return l10n.settings;
    case 'Language':
      return l10n.language;
    case 'Select your preferred language':
      return l10n.selectLanguage;
    case 'Home':
      return l10n.home;
    case 'Discover':
      return l10n.discover;
    case 'Create':
      return l10n.create;
    case 'Wallet':
      return l10n.wallet;
    case 'Profile':
      return l10n.profile;
    case 'Edit Profile':
      return l10n.editProfile;
    case 'Personal Information':
      return l10n.personalInformation;
    case 'Password & Security':
      return l10n.passwordSecurity;
    case 'Human Verification':
      return l10n.humanVerification;
    case 'Verified':
      return l10n.verified;
    case 'Pending verification':
      return l10n.pendingVerification;
    case 'Not verified':
      return l10n.notVerified;
    case 'Bookmarks':
      return l10n.bookmarks;
    case 'Saved Posts':
      return l10n.savedPosts;
    case 'Status & Appeals':
      return l10n.statusAppeals;
    case 'Moderation Queue':
      return l10n.modQueue;
    case 'Moderation Dashboard':
      return l10n.moderationDashboard;
    case 'Wallet Settings':
      return l10n.walletSettings;
    case 'Transaction History':
      return l10n.transactionHistory;
    case 'Notifications':
      return l10n.notifications;
    case 'Privacy':
      return l10n.privacy;
    case 'Dark Mode':
      return l10n.darkMode;
    case 'Help Center':
      return l10n.helpCenter;
    case 'Contact Support':
      return l10n.contactSupport;
    case 'About ROOVERSE':
      return l10n.aboutROOVERSE;
    case 'Terms of Service':
      return l10n.termsOfService;
    case 'Privacy Policy':
      return l10n.privacyPolicy;
    case 'Delete Account':
      return l10n.deleteAccount;
    case 'Permanently delete your account':
      return l10n.permanentlyDeleteAccount;
    case 'Log Out':
      return l10n.logOut;
    case 'Are you sure you want to log out?':
      return l10n.areYouSureLogOut;
    case 'Cancel':
      return l10n.cancel;
    case 'Close':
      return l10n.close;
    case 'Delete':
      return l10n.delete;
    case 'Type DELETE to confirm.':
      return l10n.typeDeleteConfirm;
    case 'Account deletion requested. You have been logged out.':
      return l10n.accountDeletionRequested;
    case 'Please type DELETE to confirm':
      return l10n.pleaseTypeDelete;
    case 'ROOVERSE – Human-Centred Social Platform\n\nVersion 1.0.2\n\n© 2026 ROOVERSE Inc.':
      return l10n.aboutROOVERSEDescription;
    case 'Log In':
      return l10n.login;
    case 'Sign Up':
      return l10n.signup;
    case 'Recover':
      return l10n.recover;
    case 'Verify':
      return l10n.verify;
    case 'Human Verify':
      return l10n.humanVerify;
    case 'Phone Verify':
      return l10n.phoneVerify;
    case 'Back':
      return l10n.back;
    case 'Feed':
      return l10n.feed;
    case 'Explore':
      return l10n.explore;
    case 'Chat':
      return l10n.chat;
    case 'Notifications':
      return l10n.notificationsTitle;
    default:
      return null;
  }
}
