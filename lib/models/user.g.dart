// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  username: json['username'] as String,
  displayName: json['displayName'] as String,
  email: json['email'] as String?,
  avatar: json['avatar'] as String?,
  bio: json['bio'] as String?,
  phone: json['phone'] as String?,
  location: json['location'] as String?,
  birthDate: json['birthDate'] == null
      ? null
      : DateTime.parse(json['birthDate'] as String),
  countryOfResidence: json['countryOfResidence'] as String?,
  websiteUrl: json['websiteUrl'] as String?,
  isVerified: json['isVerified'] as bool? ?? false,
  balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
  postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
  humanVerifiedPostsCount:
      (json['humanVerifiedPostsCount'] as num?)?.toInt() ?? 0,
  followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
  trustScore: (json['trustScore'] as num?)?.toDouble() ?? 0.0,
  mlScore: (json['mlScore'] as num?)?.toDouble() ?? 0.0,
  verifiedHuman: json['verifiedHuman'] as String? ?? 'unverified',
  postsVisibility: json['postsVisibility'] as String?,
  commentsVisibility: json['commentsVisibility'] as String?,
  messagesVisibility: json['messagesVisibility'] as String?,
  status: json['status'] as String? ?? 'active',
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  lastSeen: json['lastSeen'] == null
      ? null
      : DateTime.parse(json['lastSeen'] as String),
  interests:
      (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'displayName': instance.displayName,
  'email': instance.email,
  'avatar': instance.avatar,
  'bio': instance.bio,
  'phone': instance.phone,
  'location': instance.location,
  'birthDate': instance.birthDate?.toIso8601String(),
  'countryOfResidence': instance.countryOfResidence,
  'websiteUrl': instance.websiteUrl,
  'isVerified': instance.isVerified,
  'balance': instance.balance,
  'postsCount': instance.postsCount,
  'humanVerifiedPostsCount': instance.humanVerifiedPostsCount,
  'followersCount': instance.followersCount,
  'followingCount': instance.followingCount,
  'trustScore': instance.trustScore,
  'mlScore': instance.mlScore,
  'verifiedHuman': instance.verifiedHuman,
  'postsVisibility': instance.postsVisibility,
  'commentsVisibility': instance.commentsVisibility,
  'messagesVisibility': instance.messagesVisibility,
  'status': instance.status,
  'createdAt': instance.createdAt?.toIso8601String(),
  'lastSeen': instance.lastSeen?.toIso8601String(),
  'interests': instance.interests,
};
