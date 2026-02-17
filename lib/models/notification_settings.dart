class NotificationSettings {
  final String userId;
  final bool notifyPush;
  final bool notifyEmail;
  final bool notifyInApp;
  final bool notifyFollows;
  final bool notifyComments;
  final bool notifyLikes;
  final bool notifyMentions;

  NotificationSettings({
    required this.userId,
    this.notifyPush = true,
    this.notifyEmail = true,
    this.notifyInApp = true,
    this.notifyFollows = true,
    this.notifyComments = true,
    this.notifyLikes = true,
    this.notifyMentions = true,
  });

  factory NotificationSettings.fromSupabase(Map<String, dynamic> json) {
    final inappFollows =
        (json['inapp_follows'] as bool?) ??
        (json['notify_follows'] as bool?) ??
        true;
    final inappComments =
        (json['inapp_comments'] as bool?) ??
        (json['notify_comments'] as bool?) ??
        true;
    final inappReactions =
        (json['inapp_reactions'] as bool?) ??
        (json['notify_reactions'] as bool?) ??
        true;
    final inappMentions =
        (json['inapp_mentions'] as bool?) ??
        (json['notify_mentions'] as bool?) ??
        true;

    return NotificationSettings(
      userId: json['user_id'] as String? ?? '',
      notifyPush:
          (json['push_enabled'] as bool?) ?? (json['notify_push'] as bool?) ?? true,
      notifyEmail:
          (json['email_enabled'] as bool?) ?? (json['notify_email'] as bool?) ?? true,
      notifyInApp: inappFollows || inappComments || inappReactions || inappMentions,
      notifyFollows: inappFollows,
      notifyComments: inappComments,
      notifyLikes: inappReactions,
      notifyMentions: inappMentions,
    );
  }

  Map<String, dynamic> toSupabase() {
    final inAppEnabled = notifyInApp;
    return {
      'user_id': userId,
      'push_enabled': notifyPush,
      'email_enabled': notifyEmail,
      'inapp_follows': inAppEnabled ? notifyFollows : false,
      'inapp_comments': inAppEnabled ? notifyComments : false,
      'inapp_reactions': inAppEnabled ? notifyLikes : false,
      'inapp_mentions': inAppEnabled ? notifyMentions : false,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      userId: json['userId'] as String? ?? '',
      notifyPush: json['notifyPush'] as bool? ?? true,
      notifyEmail: json['notifyEmail'] as bool? ?? true,
      notifyInApp: json['notifyInApp'] as bool? ?? true,
      notifyFollows: json['notifyFollows'] as bool? ?? true,
      notifyComments: json['notifyComments'] as bool? ?? true,
      notifyLikes: json['notifyLikes'] as bool? ?? true,
      notifyMentions: json['notifyMentions'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'notifyPush': notifyPush,
      'notifyEmail': notifyEmail,
      'notifyInApp': notifyInApp,
      'notifyFollows': notifyFollows,
      'notifyComments': notifyComments,
      'notifyLikes': notifyLikes,
      'notifyMentions': notifyMentions,
    };
  }

  NotificationSettings copyWith({
    String? userId,
    bool? notifyPush,
    bool? notifyEmail,
    bool? notifyInApp,
    bool? notifyFollows,
    bool? notifyComments,
    bool? notifyLikes,
    bool? notifyMentions,
  }) {
    return NotificationSettings(
      userId: userId ?? this.userId,
      notifyPush: notifyPush ?? this.notifyPush,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyInApp: notifyInApp ?? this.notifyInApp,
      notifyFollows: notifyFollows ?? this.notifyFollows,
      notifyComments: notifyComments ?? this.notifyComments,
      notifyLikes: notifyLikes ?? this.notifyLikes,
      notifyMentions: notifyMentions ?? this.notifyMentions,
    );
  }
}
