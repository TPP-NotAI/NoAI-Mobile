/// Platform-wide configuration fetched from the platform_config table.
/// All fields mirror the database schema and have safe defaults so the app
/// works even when the fetch fails.
class PlatformConfig {
  final bool allowNewSignups;
  final bool requireEmailVerification;
  final bool requireHumanVerification;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final bool roocoinTradingEnabled;
  final double aiFlagThreshold;
  final double autoBanThreshold;
  final int maxPostLength;
  final int maxCommentLength;
  final int maxBioLength;
  final int maxMediaPerPost;
  final int maxTagsPerPost;
  final double defaultPublishFeeRc;
  final double newUserBonusRc;
  final int postsPerDayLimit;
  final int commentsPerHourLimit;
  final int messagesPerMinuteLimit;
  final String platformName;
  final String? platformLogoUrl;
  final String? adminContactEmail;
  final String? platformDescription;
  final String? tosUrl;
  final String? privacyPolicyUrl;
  final int minPasswordLength;
  final int usernameMinLength;
  final int usernameMaxLength;
  final int maxLoginAttempts;
  final double maxUploadSizeMb;
  final int maxImagesPerPost;
  final int maxVideoDurationSeconds;
  final String nsfwHandling;
  final bool enableStories;
  final bool enableChallenges;
  final bool enableTrustCircles;
  final bool enableCollectibles;
  final String mobileAppLatestVersion;

  const PlatformConfig({
    this.allowNewSignups = true,
    this.requireEmailVerification = true,
    this.requireHumanVerification = false,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.roocoinTradingEnabled = true,
    this.aiFlagThreshold = 85,
    this.autoBanThreshold = 98,
    this.maxPostLength = 10000,
    this.maxCommentLength = 2000,
    this.maxBioLength = 500,
    this.maxMediaPerPost = 10,
    this.maxTagsPerPost = 10,
    this.defaultPublishFeeRc = 10,
    this.newUserBonusRc = 100,
    this.postsPerDayLimit = 50,
    this.commentsPerHourLimit = 100,
    this.messagesPerMinuteLimit = 30,
    this.platformName = 'Rooverse',
    this.platformLogoUrl,
    this.adminContactEmail,
    this.platformDescription,
    this.tosUrl,
    this.privacyPolicyUrl,
    this.minPasswordLength = 8,
    this.usernameMinLength = 3,
    this.usernameMaxLength = 20,
    this.maxLoginAttempts = 5,
    this.maxUploadSizeMb = 10,
    this.maxImagesPerPost = 5,
    this.maxVideoDurationSeconds = 60,
    this.nsfwHandling = 'blur',
    this.enableStories = true,
    this.enableChallenges = true,
    this.enableTrustCircles = true,
    this.enableCollectibles = true,
    this.mobileAppLatestVersion = '1.0.0',
  });

  factory PlatformConfig.fromMap(Map<String, dynamic> map) {
    return PlatformConfig(
      allowNewSignups: map['allow_new_signups'] as bool? ?? true,
      requireEmailVerification:
          map['require_email_verification'] as bool? ?? true,
      requireHumanVerification:
          map['require_human_verification'] as bool? ?? false,
      maintenanceMode: map['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: map['maintenance_message'] as String?,
      roocoinTradingEnabled: map['roocoin_trading_enabled'] as bool? ?? true,
      aiFlagThreshold:
          (map['ai_flag_threshold'] as num?)?.toDouble() ?? 85,
      autoBanThreshold:
          (map['auto_ban_threshold'] as num?)?.toDouble() ?? 98,
      maxPostLength: map['max_post_length'] as int? ?? 10000,
      maxCommentLength: map['max_comment_length'] as int? ?? 2000,
      maxBioLength: map['max_bio_length'] as int? ?? 500,
      maxMediaPerPost: map['max_media_per_post'] as int? ?? 10,
      maxTagsPerPost: map['max_tags_per_post'] as int? ?? 10,
      defaultPublishFeeRc:
          (map['default_publish_fee_rc'] as num?)?.toDouble() ?? 10,
      newUserBonusRc: (map['new_user_bonus_rc'] as num?)?.toDouble() ?? 100,
      postsPerDayLimit: map['posts_per_day_limit'] as int? ?? 50,
      commentsPerHourLimit: map['comments_per_hour_limit'] as int? ?? 100,
      messagesPerMinuteLimit: map['messages_per_minute_limit'] as int? ?? 30,
      platformName: map['platform_name'] as String? ?? 'Rooverse',
      platformLogoUrl: map['platform_logo_url'] as String?,
      adminContactEmail: map['admin_contact_email'] as String?,
      platformDescription: map['platform_description'] as String?,
      tosUrl: map['tos_url'] as String?,
      privacyPolicyUrl: map['privacy_policy_url'] as String?,
      minPasswordLength: map['min_password_length'] as int? ?? 8,
      usernameMinLength: map['username_min_length'] as int? ?? 3,
      usernameMaxLength: map['username_max_length'] as int? ?? 20,
      maxLoginAttempts: map['max_login_attempts'] as int? ?? 5,
      maxUploadSizeMb:
          (map['max_upload_size_mb'] as num?)?.toDouble() ?? 10,
      maxImagesPerPost: map['max_images_per_post'] as int? ?? 5,
      maxVideoDurationSeconds: map['max_video_duration_seconds'] as int? ?? 60,
      nsfwHandling: map['nsfw_handling'] as String? ?? 'blur',
      enableStories: map['enable_stories'] as bool? ?? true,
      enableChallenges: map['enable_challenges'] as bool? ?? true,
      enableTrustCircles: map['enable_trust_circles'] as bool? ?? true,
      enableCollectibles: map['enable_collectibles'] as bool? ?? true,
      mobileAppLatestVersion:
          map['mobile_app_latest_version'] as String? ?? '1.0.0',
    );
  }
}
