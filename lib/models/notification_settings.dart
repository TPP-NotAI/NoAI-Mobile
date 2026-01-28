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
    return NotificationSettings(
      userId: json['user_id'] as String? ?? '',
      notifyPush: json['notify_push'] as bool? ?? true,
      notifyEmail: json['notify_email'] as bool? ?? true,
      notifyInApp: json['notify_in_app'] as bool? ?? true,
      notifyFollows: json['notify_follows'] as bool? ?? true,
      notifyComments: json['notify_comments'] as bool? ?? true,
      notifyLikes: json['notify_reactions'] as bool? ?? true,
      notifyMentions: json['notify_mentions'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'user_id': userId,
      'notify_push': notifyPush,
      'notify_email': notifyEmail,
      'notify_in_app': notifyInApp,
      'notify_follows': notifyFollows,
      'notify_comments': notifyComments,
      'notify_reactions': notifyLikes,
      'notify_mentions': notifyMentions,
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
