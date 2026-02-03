import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'story.g.dart';

/// Lightweight story/status model backed by Supabase `stories` table.
@JsonSerializable()
class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // image | video
  final String? caption;
  final String? backgroundColor;
  final String? textOverlay;
  final Map<String, dynamic>? textPosition;
  final int viewCount;
  final DateTime expiresAt;
  final DateTime createdAt;
  final User author;
  final double? aiScore;
  final String? status;

  /// Whether the current viewer has already seen this story.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isViewed;

  Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.viewCount,
    required this.expiresAt,
    required this.createdAt,
    required this.author,
    this.caption,
    this.backgroundColor,
    this.textOverlay,
    this.textPosition,
    this.isViewed = false,
    this.aiScore,
    this.status,
  });

  /// Construct from Supabase row with joined `profiles` data.
  factory Story.fromSupabase(
    Map<String, dynamic> json, {
    bool isViewed = false,
  }) {
    final profile =
        json['profiles'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>? ??
        {};

    return Story(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      caption: json['caption'] as String?,
      backgroundColor: json['background_color'] as String?,
      textOverlay: json['text_overlay'] as String?,
      textPosition: json['text_position'] as Map<String, dynamic>?,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      author: User.fromSupabase(profile),
      isViewed: isViewed,
      aiScore: (json['ai_score'] as num?)?.toDouble(),
      status: json['status'] as String?,
    );
  }

  factory Story.fromJson(Map<String, dynamic> json) => _$StoryFromJson(json);
  Map<String, dynamic> toJson() => _$StoryToJson(this);

  Story copyWith({bool? isViewed, int? viewCount}) {
    return Story(
      id: id,
      userId: userId,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: caption,
      backgroundColor: backgroundColor,
      textOverlay: textOverlay,
      textPosition: textPosition,
      viewCount: viewCount ?? this.viewCount,
      expiresAt: expiresAt,
      createdAt: createdAt,
      author: author,
      isViewed: isViewed ?? this.isViewed,
    );
  }
}
