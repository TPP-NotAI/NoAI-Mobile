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
    // Auth screens
    case 'Password is required':
      return l10n.passwordRequired;
    case 'Invalid email or password':
      return l10n.invalidEmailOrPassword;
    case 'Unable to start Google login':
      return l10n.unableToStartGoogleLogin;
    case 'Please enter your phone number':
      return l10n.pleaseEnterPhoneNumber;
    case 'Please enter a valid phone number':
      return l10n.pleaseEnterValidPhoneNumber;
    case 'Failed to send login code':
      return l10n.failedToSendLoginCode;
    case 'Please enter the 6-digit code':
      return l10n.pleaseEnter6DigitCode;
    case 'Enter 6-digit code':
      return l10n.pleaseEnter6DigitCode;
    case 'Invalid verification code':
      return l10n.invalidCode;
    case 'Verify & Login':
      return l10n.verifyAndLogin;
    case 'Send Code':
      return l10n.sendCode;
    case 'Failed to send verification code':
      return l10n.failedToSendVerificationCode;
    case 'An error occurred. Please try again.':
      return l10n.anErrorOccurredTryAgain;
    case 'VERIFY CODE':
      return l10n.verifyCode.toUpperCase();
    case 'ENTER PHONE':
      return l10n.enterPhone.toUpperCase();
    case 'Enter Verification Code':
      return l10n.enterVerificationCode;
    case 'Phone Verification':
      return l10n.phoneVerify;
    case 'Enter your phone number to receive a verification code via SMS.':
      return l10n.enterPhoneForSms;
    case 'Verify Phone':
      return l10n.phoneVerify;
    case 'Phone number':
      return l10n.phoneNumber;
    case 'Forgot Password?':
      return l10n.forgotPassword;
    case 'Email Address':
      return l10n.emailAddress;
    case 'Enter your email':
      return l10n.enterYourEmail;
    case 'Verify Code':
      return l10n.verifyCode;
    case 'New Password':
      return l10n.newPassword;
    case 'Enter new password':
      return l10n.enterNewPassword;
    case 'Confirm Password':
      return l10n.confirmPassword;
    case 'Confirm your password':
      return l10n.confirmYourPassword;
    case 'Reset Password':
      return l10n.resetPassword;
    case 'Password Reset!':
      return l10n.passwordReset;
    case 'Back to Login':
      return l10n.backToLogin;
    // Wallet screens
    case 'Online':
      return l10n.online;
    case 'Offline':
      return l10n.offline;
    case 'AVAILABLE':
      return l10n.available.toUpperCase();
    case 'LIFETIME EARNED':
      return l10n.lifetimeEarned.toUpperCase();
    case 'Enter ROO amount':
      return l10n.enterRooAmount;
    case 'Enter location...':
      return l10n.enterLocation;
    case 'Use current location':
      return l10n.useCurrentLocation;
    case 'Search or add topics...':
      return l10n.searchOrAddTopics;
    case 'Popular Topics':
      return l10n.popularTopics;
    case 'Recipient':
      return l10n.recipient;
    case 'Your verification is pending. You can send ROO once approved.':
      return l10n.verificationPendingSendRoo;
    case 'Please complete identity verification to send ROO.':
      return l10n.completeVerificationToSendRoo;
    case 'You cannot send ROO to your own account':
      return l10n.cannotSendRooToSelf;
    case 'AVAILABLE BALANCE':
      return l10n.availableBalance.toUpperCase();
    // Create post screen
    case 'Failed to pick media':
      return l10n.failedToPickMedia;
    case 'Checking content safety...':
      return l10n.checkingContentSafety;
    case 'Location permission denied':
      return l10n.locationPermissionDenied;
    case 'Location permission permanently denied':
      return l10n.locationPermissionPermanentlyDenied;
    case "What's on your mind?":
      return l10n.whatsOnYourMind;
    // Boost modal
    case 'You must be logged in to boost a post.':
      return l10n.mustBeLoggedInToBoost;
    case 'users':
      return l10n.users;
    // Tip modal
    case 'User not logged in':
      return l10n.userNotLoggedIn;
    case 'Your verification is pending. You can tip once approved.':
      return l10n.verificationPendingTip;
    case 'Insufficient Roobyte balance':
      return l10n.insufficientRooBalance;
    case 'You cannot tip your own post':
      return l10n.cannotTipOwnPost;
    case 'Enter amount':
      return l10n.enterAmount;
    // Post card
    case 'This post is under review.':
      return l10n.postUnderReview;
    case 'Sensitive Content':
      return l10n.sensitiveContent;
    // Comment card
    case 'Are you sure you want to delete this comment? This cannot be undone.':
      return l10n.deleteCommentConfirmation;
    // Comments sheet
    case 'Your comment was not published. Our AI detected it may violate our guidelines.':
      return l10n.commentNotPublishedAi;
    case 'Your comment is under review. It will appear once approved.':
      return l10n.commentUnderReviewExtended;
    case 'Comment under review.':
      return l10n.commentUnderReview;
    case 'Failed to post comment':
      return l10n.failedToPostComment;
    // Stories carousel
    case 'Advertisement Detected':
      return l10n.advertisementDetected;
    case 'Ad fee':
      return l10n.adFee;
    case 'Not now':
      return l10n.notNow;
    case 'Stories from people you follow will appear here':
      return l10n.storiesEmpty;
    case 'Text stories are limited to 250 words.':
      return l10n.textStoryWordLimit;
    case 'Create Story':
      return l10n.createStory;
    case 'Click to upload':
      return l10n.clickToUpload;
    case 'Image or video (max 15s)':
      return l10n.imageOrVideoMax;
    default:
      return null;
  }
}
