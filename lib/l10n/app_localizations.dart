import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ROOVERSE'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get selectLanguage;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @passwordSecurity.
  ///
  /// In en, this message translates to:
  /// **'Password & Security'**
  String get passwordSecurity;

  /// No description provided for @humanVerification.
  ///
  /// In en, this message translates to:
  /// **'Human Verification'**
  String get humanVerification;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @pendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Pending verification'**
  String get pendingVerification;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @savedPosts.
  ///
  /// In en, this message translates to:
  /// **'Saved Posts'**
  String get savedPosts;

  /// No description provided for @statusAppeals.
  ///
  /// In en, this message translates to:
  /// **'Status & Appeals'**
  String get statusAppeals;

  /// No description provided for @modQueue.
  ///
  /// In en, this message translates to:
  /// **'Moderation Queue'**
  String get modQueue;

  /// No description provided for @moderationDashboard.
  ///
  /// In en, this message translates to:
  /// **'Moderation Dashboard'**
  String get moderationDashboard;

  /// No description provided for @walletSettings.
  ///
  /// In en, this message translates to:
  /// **'Wallet Settings'**
  String get walletSettings;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @aboutROOVERSE.
  ///
  /// In en, this message translates to:
  /// **'About ROOVERSE'**
  String get aboutROOVERSE;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @permanentlyDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account'**
  String get permanentlyDeleteAccount;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @areYouSureLogOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get areYouSureLogOut;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @typeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm.'**
  String get typeDeleteConfirm;

  /// No description provided for @accountDeletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested. You have been logged out.'**
  String get accountDeletionRequested;

  /// No description provided for @pleaseTypeDelete.
  ///
  /// In en, this message translates to:
  /// **'Please type DELETE to confirm'**
  String get pleaseTypeDelete;

  /// No description provided for @aboutROOVERSEDescription.
  ///
  /// In en, this message translates to:
  /// **'ROOVERSE – Human-Centred Social Platform\n\nVersion 1.0.2\n\n© 2026 ROOVERSE Inc.'**
  String get aboutROOVERSEDescription;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @recover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get recover;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @humanVerify.
  ///
  /// In en, this message translates to:
  /// **'Human Verify'**
  String get humanVerify;

  /// No description provided for @phoneVerify.
  ///
  /// In en, this message translates to:
  /// **'Phone Verify'**
  String get phoneVerify;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @react.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get react;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied To Clipboard'**
  String get copiedToClipboard;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @accountBanned.
  ///
  /// In en, this message translates to:
  /// **'Account Banned'**
  String get accountBanned;

  /// No description provided for @accountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get accountSuspended;

  /// No description provided for @verificationError.
  ///
  /// In en, this message translates to:
  /// **'Verification Error'**
  String get verificationError;

  /// No description provided for @identityVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Identity Verified Successfully'**
  String get identityVerifiedSuccessfully;

  /// No description provided for @errorCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Error Checking Status'**
  String get errorCheckingStatus;

  /// No description provided for @checkVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Verification Status'**
  String get checkVerificationStatus;

  /// No description provided for @pleaseEnterDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Please Enter Display Name'**
  String get pleaseEnterDisplayName;

  /// No description provided for @pleaseEnterBio.
  ///
  /// In en, this message translates to:
  /// **'Please Enter Bio'**
  String get pleaseEnterBio;

  /// No description provided for @anErrorOccurredTryAgain.
  ///
  /// In en, this message translates to:
  /// **'An Error Occurred Try Again'**
  String get anErrorOccurredTryAgain;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @verificationCodeResent.
  ///
  /// In en, this message translates to:
  /// **'Verification Code Resent'**
  String get verificationCodeResent;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out Confirm Title'**
  String get signOutConfirmTitle;

  /// No description provided for @postSavedToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Post Saved To Bookmarks'**
  String get postSavedToBookmarks;

  /// No description provided for @adInsights.
  ///
  /// In en, this message translates to:
  /// **'Ad Insights'**
  String get adInsights;

  /// No description provided for @boostSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Boost Successful'**
  String get boostSuccessful;

  /// No description provided for @great.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get great;

  /// No description provided for @advertisementDetected.
  ///
  /// In en, this message translates to:
  /// **'Advertisement Detected'**
  String get advertisementDetected;

  /// No description provided for @adFee.
  ///
  /// In en, this message translates to:
  /// **'Ad Fee'**
  String get adFee;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @insufficientRooBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient ROO Balance'**
  String get insufficientRooBalance;

  /// No description provided for @boostFailed.
  ///
  /// In en, this message translates to:
  /// **'Boost Failed'**
  String get boostFailed;

  /// No description provided for @startMessaging.
  ///
  /// In en, this message translates to:
  /// **'Start Messaging'**
  String get startMessaging;

  /// No description provided for @deleteConversation.
  ///
  /// In en, this message translates to:
  /// **'Delete Conversation'**
  String get deleteConversation;

  /// No description provided for @conversationArchived.
  ///
  /// In en, this message translates to:
  /// **'Conversation Archived'**
  String get conversationArchived;

  /// No description provided for @conversationUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Conversation Unarchived'**
  String get conversationUnarchived;

  /// No description provided for @conversationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Conversation Deleted'**
  String get conversationDeleted;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone Permission Denied'**
  String get microphonePermissionDenied;

  /// No description provided for @failedToSendVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed To Send Voice Message'**
  String get failedToSendVoiceMessage;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfo;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete For Me'**
  String get deleteForMe;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete For Everyone'**
  String get deleteForEveryone;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video Call'**
  String get videoCall;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice Call'**
  String get voiceCall;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Hint'**
  String get messageHint;

  /// No description provided for @deleteDmThread.
  ///
  /// In en, this message translates to:
  /// **'Delete DM Thread'**
  String get deleteDmThread;

  /// No description provided for @dmThreadDeleted.
  ///
  /// In en, this message translates to:
  /// **'DM Thread Deleted'**
  String get dmThreadDeleted;

  /// No description provided for @failedToPickMedia.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick media'**
  String get failedToPickMedia;

  /// No description provided for @checkingContentSafety.
  ///
  /// In en, this message translates to:
  /// **'Checking Content Safety'**
  String get checkingContentSafety;

  /// No description provided for @contentWarning.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get contentWarning;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I Understand'**
  String get iUnderstand;

  /// No description provided for @removeMedia.
  ///
  /// In en, this message translates to:
  /// **'Remove Media'**
  String get removeMedia;

  /// No description provided for @failedToGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to get location'**
  String get failedToGetLocation;

  /// No description provided for @loadAnotherDraft.
  ///
  /// In en, this message translates to:
  /// **'Load Another Draft'**
  String get loadAnotherDraft;

  /// No description provided for @loadDraft.
  ///
  /// In en, this message translates to:
  /// **'Load Draft'**
  String get loadDraft;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get saveDraft;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft'**
  String get deleteDraft;

  /// No description provided for @draftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft Deleted'**
  String get draftDeleted;

  /// No description provided for @discardCurrentChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard Current Changes'**
  String get discardCurrentChanges;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get continueEditing;

  /// No description provided for @previewPost.
  ///
  /// In en, this message translates to:
  /// **'Preview Post'**
  String get previewPost;

  /// No description provided for @payAdFee.
  ///
  /// In en, this message translates to:
  /// **'Pay Ad Fee'**
  String get payAdFee;

  /// No description provided for @failedToCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Failed To Create Post'**
  String get failedToCreatePost;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @finishProfile.
  ///
  /// In en, this message translates to:
  /// **'Finish Profile'**
  String get finishProfile;

  /// No description provided for @addTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Add Title Optional'**
  String get addTitleOptional;

  /// No description provided for @whatsOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'Whats On Your Mind'**
  String get whatsOnYourMind;

  /// No description provided for @tagPeople.
  ///
  /// In en, this message translates to:
  /// **'Tag People'**
  String get tagPeople;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add Location'**
  String get addLocation;

  /// No description provided for @addTopics.
  ///
  /// In en, this message translates to:
  /// **'Add Topics'**
  String get addTopics;

  /// No description provided for @trimVideo.
  ///
  /// In en, this message translates to:
  /// **'Trim Video'**
  String get trimVideo;

  /// No description provided for @applyTrim.
  ///
  /// In en, this message translates to:
  /// **'Apply Trim'**
  String get applyTrim;

  /// No description provided for @muteVideo.
  ///
  /// In en, this message translates to:
  /// **'Mute Video'**
  String get muteVideo;

  /// No description provided for @videoWillBeMuted.
  ///
  /// In en, this message translates to:
  /// **'Video Will Be Muted'**
  String get videoWillBeMuted;

  /// No description provided for @rotateVideo.
  ///
  /// In en, this message translates to:
  /// **'Rotate Video'**
  String get rotateVideo;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @noSavedDrafts.
  ///
  /// In en, this message translates to:
  /// **'No saved drafts'**
  String get noSavedDrafts;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter location...'**
  String get enterLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @searchOrAddTopics.
  ///
  /// In en, this message translates to:
  /// **'Search or add topics...'**
  String get searchOrAddTopics;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @popularTopics.
  ///
  /// In en, this message translates to:
  /// **'Popular Topics'**
  String get popularTopics;

  /// No description provided for @searchByUsername.
  ///
  /// In en, this message translates to:
  /// **'Search by username...'**
  String get searchByUsername;

  /// No description provided for @addAComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get addAComment;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPost;

  /// No description provided for @postCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Post Cannot Be Empty'**
  String get postCannotBeEmpty;

  /// No description provided for @postUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Post Updated Successfully'**
  String get postUpdatedSuccessfully;

  /// No description provided for @failedToUpdatePost.
  ///
  /// In en, this message translates to:
  /// **'Failed to update post'**
  String get failedToUpdatePost;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get addVideo;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @deleteNotification.
  ///
  /// In en, this message translates to:
  /// **'Delete Notification'**
  String get deleteNotification;

  /// No description provided for @notificationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Notification deleted'**
  String get notificationDeleted;

  /// No description provided for @postNotFound.
  ///
  /// In en, this message translates to:
  /// **'Post Not Found'**
  String get postNotFound;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications Subtitle'**
  String get pushNotificationsSubtitle;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @emailNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications Subtitle'**
  String get emailNotificationsSubtitle;

  /// No description provided for @inAppNotifications.
  ///
  /// In en, this message translates to:
  /// **'In App Notifications'**
  String get inAppNotifications;

  /// No description provided for @inAppNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In App Notifications Subtitle'**
  String get inAppNotificationsSubtitle;

  /// No description provided for @newFollowers.
  ///
  /// In en, this message translates to:
  /// **'New Followers'**
  String get newFollowers;

  /// No description provided for @newFollowersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New Followers Subtitle'**
  String get newFollowersSubtitle;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @commentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Comments Subtitle'**
  String get commentsSubtitle;

  /// No description provided for @likesAndReactions.
  ///
  /// In en, this message translates to:
  /// **'Likes And Reactions'**
  String get likesAndReactions;

  /// No description provided for @likesAndReactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Likes And Reactions Subtitle'**
  String get likesAndReactionsSubtitle;

  /// No description provided for @mentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get mentions;

  /// No description provided for @mentionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mentions Subtitle'**
  String get mentionsSubtitle;

  /// No description provided for @commentPosted.
  ///
  /// In en, this message translates to:
  /// **'Comment Posted'**
  String get commentPosted;

  /// No description provided for @failedToPostComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment'**
  String get failedToPostComment;

  /// No description provided for @unpublishPost.
  ///
  /// In en, this message translates to:
  /// **'Unpublish Post'**
  String get unpublishPost;

  /// No description provided for @unpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get unpublish;

  /// No description provided for @postUnpublished.
  ///
  /// In en, this message translates to:
  /// **'Post Unpublished'**
  String get postUnpublished;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get deletePost;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post Deleted'**
  String get postDeleted;

  /// No description provided for @postDetails.
  ///
  /// In en, this message translates to:
  /// **'Post Details'**
  String get postDetails;

  /// No description provided for @boostPost.
  ///
  /// In en, this message translates to:
  /// **'Boost Post'**
  String get boostPost;

  /// No description provided for @viewBoostAnalytics.
  ///
  /// In en, this message translates to:
  /// **'View Boost Analytics'**
  String get viewBoostAnalytics;

  /// No description provided for @postSharedEarned.
  ///
  /// In en, this message translates to:
  /// **'Post Shared Earned'**
  String get postSharedEarned;

  /// No description provided for @linkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link Copied To Clipboard'**
  String get linkCopiedToClipboard;

  /// No description provided for @personalInformationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Personal Information Updated'**
  String get personalInformationUpdated;

  /// No description provided for @errorUpdatingInformation.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Information'**
  String get errorUpdatingInformation;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'User Blocked'**
  String get userBlocked;

  /// No description provided for @reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report User'**
  String get reportUser;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password Subtitle'**
  String get changePasswordSubtitle;

  /// No description provided for @resetPasswordViaEmail.
  ///
  /// In en, this message translates to:
  /// **'Reset Password Via Email'**
  String get resetPasswordViaEmail;

  /// No description provided for @resetPasswordViaEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password Via Email Subtitle'**
  String get resetPasswordViaEmailSubtitle;

  /// No description provided for @twoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two Factor Auth'**
  String get twoFactorAuth;

  /// No description provided for @twoFactorAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Two Factor Auth Subtitle'**
  String get twoFactorAuthSubtitle;

  /// No description provided for @accountSecurityTips.
  ///
  /// In en, this message translates to:
  /// **'Account Security Tips'**
  String get accountSecurityTips;

  /// No description provided for @newCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New Code Sent'**
  String get newCodeSent;

  /// No description provided for @failedToResend.
  ///
  /// In en, this message translates to:
  /// **'Failed To Resend'**
  String get failedToResend;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @enable2FA.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA'**
  String get enable2FA;

  /// No description provided for @pleaseEnter6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Please Enter 6digitcode'**
  String get pleaseEnter6DigitCode;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid Code'**
  String get invalidCode;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords Do Not Match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password Updated Successfully'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @failedToUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed To Update Password'**
  String get failedToUpdatePassword;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please Enter Valid Email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @failedToSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed To Send Reset Email'**
  String get failedToSendResetEmail;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @failedToSendCode.
  ///
  /// In en, this message translates to:
  /// **'Failed To Send Code'**
  String get failedToSendCode;

  /// No description provided for @whoCanSeeMyPosts.
  ///
  /// In en, this message translates to:
  /// **'Who Can See My Posts'**
  String get whoCanSeeMyPosts;

  /// No description provided for @whoCanSeeMyComments.
  ///
  /// In en, this message translates to:
  /// **'Who Can See My Comments'**
  String get whoCanSeeMyComments;

  /// No description provided for @whoCanSendMeMessages.
  ///
  /// In en, this message translates to:
  /// **'Who Can Send Me Messages'**
  String get whoCanSendMeMessages;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @blockedUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users Subtitle'**
  String get blockedUsersSubtitle;

  /// No description provided for @userNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User Not Logged In'**
  String get userNotLoggedIn;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @appealThisDecision.
  ///
  /// In en, this message translates to:
  /// **'Appeal This Decision'**
  String get appealThisDecision;

  /// No description provided for @failedToModeratePost.
  ///
  /// In en, this message translates to:
  /// **'Failed to moderate post'**
  String get failedToModeratePost;

  /// No description provided for @pleaseExplainAppeal.
  ///
  /// In en, this message translates to:
  /// **'Please Explain Appeal'**
  String get pleaseExplainAppeal;

  /// No description provided for @alreadySubmittedAppeal.
  ///
  /// In en, this message translates to:
  /// **'Already Submitted Appeal'**
  String get alreadySubmittedAppeal;

  /// No description provided for @appealSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Appeal Submitted'**
  String get appealSubmitted;

  /// No description provided for @errorSubmittingAppeal.
  ///
  /// In en, this message translates to:
  /// **'Error Submitting Appeal'**
  String get errorSubmittingAppeal;

  /// No description provided for @writeYourAppeal.
  ///
  /// In en, this message translates to:
  /// **'Write Your Appeal'**
  String get writeYourAppeal;

  /// No description provided for @deleteType.
  ///
  /// In en, this message translates to:
  /// **'Delete Type'**
  String get deleteType;

  /// No description provided for @commentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment Deleted'**
  String get commentDeleted;

  /// No description provided for @storyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Story Deleted'**
  String get storyDeleted;

  /// No description provided for @postDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Post Deleted Snack'**
  String get postDeletedSnack;

  /// No description provided for @paymentFailedCheckBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed Check Balance'**
  String get paymentFailedCheckBalance;

  /// No description provided for @createNewAppeal.
  ///
  /// In en, this message translates to:
  /// **'Create New Appeal'**
  String get createNewAppeal;

  /// No description provided for @appealProfileStatus.
  ///
  /// In en, this message translates to:
  /// **'Appeal Profile Status'**
  String get appealProfileStatus;

  /// No description provided for @pleaseProvideReasonForAppeal.
  ///
  /// In en, this message translates to:
  /// **'Please Provide Reason For Appeal'**
  String get pleaseProvideReasonForAppeal;

  /// No description provided for @failedToSubmitAppeal.
  ///
  /// In en, this message translates to:
  /// **'Failed To Submit Appeal'**
  String get failedToSubmitAppeal;

  /// No description provided for @fillInAllRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Fill In All Required Fields'**
  String get fillInAllRequiredFields;

  /// No description provided for @failedToSubmitTicket.
  ///
  /// In en, this message translates to:
  /// **'Failed To Submit Ticket'**
  String get failedToSubmitTicket;

  /// No description provided for @generalInquiry.
  ///
  /// In en, this message translates to:
  /// **'General Inquiry'**
  String get generalInquiry;

  /// No description provided for @accountIssue.
  ///
  /// In en, this message translates to:
  /// **'Account Issue'**
  String get accountIssue;

  /// No description provided for @moderationAppeal.
  ///
  /// In en, this message translates to:
  /// **'Moderation Appeal'**
  String get moderationAppeal;

  /// No description provided for @roobyteWallet.
  ///
  /// In en, this message translates to:
  /// **'Roobyte / Wallet'**
  String get roobyteWallet;

  /// No description provided for @technicalProblem.
  ///
  /// In en, this message translates to:
  /// **'Technical Problem'**
  String get technicalProblem;

  /// No description provided for @reportAbuse.
  ///
  /// In en, this message translates to:
  /// **'Report Abuse'**
  String get reportAbuse;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @supportChat.
  ///
  /// In en, this message translates to:
  /// **'Support Chat'**
  String get supportChat;

  /// No description provided for @supportTickets.
  ///
  /// In en, this message translates to:
  /// **'Support Tickets'**
  String get supportTickets;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @noUsersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Users Available'**
  String get noUsersAvailable;

  /// No description provided for @profileDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile Details'**
  String get profileDetails;

  /// No description provided for @receiveRoo.
  ///
  /// In en, this message translates to:
  /// **'Receive ROO'**
  String get receiveRoo;

  /// No description provided for @verifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify Now'**
  String get verifyNow;

  /// No description provided for @confirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transfer'**
  String get confirmTransfer;

  /// No description provided for @sendResetLinkWallet.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link Wallet'**
  String get sendResetLinkWallet;

  /// No description provided for @photoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo From Gallery'**
  String get photoFromGallery;

  /// No description provided for @chooseExistingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose Existing Photo'**
  String get chooseExistingPhoto;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take A Photo'**
  String get takeAPhoto;

  /// No description provided for @useYourCamera.
  ///
  /// In en, this message translates to:
  /// **'Use Your Camera'**
  String get useYourCamera;

  /// No description provided for @videoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Video From Gallery'**
  String get videoFromGallery;

  /// No description provided for @chooseExistingVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose Existing Video'**
  String get chooseExistingVideo;

  /// No description provided for @recordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get recordVideo;

  /// No description provided for @recordWithYourCamera.
  ///
  /// In en, this message translates to:
  /// **'Record With Your Camera'**
  String get recordWithYourCamera;

  /// No description provided for @failedToUploadMedia.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload media'**
  String get failedToUploadMedia;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get deleteComment;

  /// No description provided for @failedToDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get failedToDeleteComment;

  /// No description provided for @failedToUpdateComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to update comment'**
  String get failedToUpdateComment;

  /// No description provided for @searchPostsUsersHashtags.
  ///
  /// In en, this message translates to:
  /// **'Search posts, users, or #hashtags'**
  String get searchPostsUsersHashtags;

  /// No description provided for @toggleMute.
  ///
  /// In en, this message translates to:
  /// **'Toggle Mute'**
  String get toggleMute;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @failedToCapturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed To Capture Photo'**
  String get failedToCapturePhoto;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
