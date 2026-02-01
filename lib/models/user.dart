import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

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
  final bool isVerified;
  final double balance;
  final int postsCount;
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

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatar,
    this.bio,
    this.phone,
    this.isVerified = false,
    this.balance = 0.0,
    this.postsCount = 0,
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
  }) {
    return User(
      id: profile['user_id'] as String,
      username: profile['username'] as String? ?? 'unknown',
      displayName: profile['display_name'] as String? ?? '',
      email: null, // Email is in auth.users, not profiles
      avatar: profile['avatar_url'] as String?,
      bio: profile['bio'] as String?,
      phone: profile['phone_number'] as String?, // Persisted via Supabase profile column
      isVerified: profile['verified_human'] == 'verified',
      verifiedHuman: profile['verified_human'] as String? ?? 'unverified',
      balance: (wallet?['balance_rc'] as num?)?.toDouble() ?? 0.0,
      trustScore: (profile['trust_score'] as num?)?.toDouble() ?? 0.0,
      mlScore: (profile['ml_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: profile['created_at'] != null
          ? DateTime.parse(profile['created_at'] as String)
          : null,
      lastSeen: profile['last_active_at'] != null
          ? DateTime.parse(profile['last_active_at'] as String)
          : null,
      postsVisibility: profile['posts_visibility'] as String?,
      commentsVisibility: profile['comments_visibility'] as String?,
      messagesVisibility: profile['messages_visibility'] as String?,
      status: profile['status'] as String? ?? 'active',
      // Counts would need separate queries or computed columns
      postsCount: 0,
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
    bool? isVerified,
    double? balance,
    int? postsCount,
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
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      isVerified: isVerified ?? this.isVerified,
      balance: balance ?? this.balance,
      postsCount: postsCount ?? this.postsCount,
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
    );
  }
}
