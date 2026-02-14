import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// A single achievement badge unlocked by a user.
class UserAchievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String tier;
  final DateTime? unlockedAt;

  const UserAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    this.unlockedAt,
  });

  factory UserAchievement.fromSupabase(Map<String, dynamic> json) {
    final achievement = json['achievements'] as Map<String, dynamic>? ?? json;
    return UserAchievement(
      id: achievement['id'] as String? ?? json['achievement_id'] as String,
      name: achievement['name'] as String? ?? '',
      description: achievement['description'] as String? ?? '',
      icon: achievement['icon'] as String? ?? 'star',
      tier: achievement['tier'] as String? ?? 'bronze',
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'] as String)
          : null,
    );
  }
}

@JsonSerializable()
class User {
  /// User ID - String (UUID) for Supabase, or legacy int converted to String.
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatar;
  final String? bio;
  final String? phone;
  final String? location;
  final String? websiteUrl;
  final bool isVerified;
  final double balance;
  final int postsCount;
  final int humanVerifiedPostsCount;
  final int followersCount;
  final int followingCount;
  final double trustScore; // 0-100 trust score (matching web)
  final double mlScore; // ML-detected AI score
  final String verifiedHuman; // unverified, pending, verified
  final String? postsVisibility; // everyone, followers, private
  final String? commentsVisibility; // everyone, followers, private
  final String? messagesVisibility; // everyone, followers, private
  final String status; // active, suspended, banned
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final List<String> interests;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<UserAchievement> achievements;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatar,
    this.bio,
    this.phone,
    this.location,
    this.websiteUrl,
    this.isVerified = false,
    this.balance = 0.0,
    this.postsCount = 0,
    this.humanVerifiedPostsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.trustScore = 0.0,
    this.mlScore = 0.0,
    this.verifiedHuman = 'unverified',
    this.postsVisibility,
    this.commentsVisibility,
    this.messagesVisibility,
    this.status = 'active',
    this.createdAt,
    this.lastSeen,
    this.interests = const [],
    this.achievements = const [],
  });

  /// Whether the user account is active.
  bool get isActive => status == 'active';

  /// Whether the user account is suspended.
  bool get isSuspended => status == 'suspended';

  /// Whether the user account is banned.
  bool get isBanned => status == 'banned';

  /// Create a User from Supabase profile row.
  ///
  /// [profile] is the row from the profiles table.
  /// [wallet] is the optional wallet data (from join or separate query).
  factory User.fromSupabase(
    Map<String, dynamic> profile, {
    Map<String, dynamic>? wallet,
    List<UserAchievement>? achievements,
  }) {
    final userId = profile['user_id'] as String?;
    if (userId == null) {
      throw ArgumentError('user_id is required in profile data');
    }

    return User(
      id: userId,
      username: profile['username'] as String? ?? 'unknown',
      displayName: profile['display_name'] as String? ?? '',
      email: null, // Email is in auth.users, not profiles
      avatar: profile['avatar_url'] as String?,
      bio: profile['bio'] as String?,
      phone: profile['phone_number'] as String?,
      location: profile['location'] as String?,
      websiteUrl: profile['website_url'] as String?,
      isVerified: profile['verified_human'] == 'verified',
      verifiedHuman: profile['verified_human'] as String? ?? 'unverified',
      balance: (wallet?['balance_rc'] as num?)?.toDouble() ?? 0.0,
      trustScore: (profile['trust_score'] as num?)?.toDouble() ?? 0.0,
      mlScore: (profile['ml_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: profile['created_at'] != null
          ? DateTime.tryParse(profile['created_at'].toString())
          : null,
      lastSeen: profile['last_active_at'] != null
          ? DateTime.tryParse(profile['last_active_at'].toString())
          : null,
      postsVisibility: profile['posts_visibility'] as String?,
      commentsVisibility: profile['comments_visibility'] as String?,
      messagesVisibility: profile['messages_visibility'] as String?,
      status: profile['status'] as String? ?? 'active',
      interests:
          (profile['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      achievements: achievements ?? const [],
      // Counts would need separate queries or computed columns
      postsCount: 0,
      humanVerifiedPostsCount: 0,
      followersCount: 0,
      followingCount: 0,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? avatar,
    String? bio,
    String? phone,
    String? location,
    String? websiteUrl,
    bool? isVerified,
    double? balance,
    int? postsCount,
    int? humanVerifiedPostsCount,
    int? followersCount,
    int? followingCount,
    double? trustScore,
    double? mlScore,
    String? verifiedHuman,
    String? postsVisibility,
    String? commentsVisibility,
    String? messagesVisibility,
    String? status,
    DateTime? createdAt,
    DateTime? lastSeen,
    List<String>? interests,
    List<UserAchievement>? achievements,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isVerified: isVerified ?? this.isVerified,
      balance: balance ?? this.balance,
      postsCount: postsCount ?? this.postsCount,
      humanVerifiedPostsCount:
          humanVerifiedPostsCount ?? this.humanVerifiedPostsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      trustScore: trustScore ?? this.trustScore,
      mlScore: mlScore ?? this.mlScore,
      verifiedHuman: verifiedHuman ?? this.verifiedHuman,
      postsVisibility: postsVisibility ?? this.postsVisibility,
      commentsVisibility: commentsVisibility ?? this.commentsVisibility,
      messagesVisibility: messagesVisibility ?? this.messagesVisibility,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      interests: interests ?? this.interests,
      achievements: achievements ?? this.achievements,
    );
  }
}
