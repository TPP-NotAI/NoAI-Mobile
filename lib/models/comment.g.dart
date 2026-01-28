// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentAuthor _$CommentAuthorFromJson(Map<String, dynamic> json) =>
    CommentAuthor(
      displayName: json['displayName'] as String,
      username: json['username'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      avatar: json['avatar'] as String?,
      commentsVisibility: json['commentsVisibility'] as String?,
    );

Map<String, dynamic> _$CommentAuthorToJson(CommentAuthor instance) =>
    <String, dynamic>{
      'displayName': instance.displayName,
      'username': instance.username,
      'avatar': instance.avatar,
      'isVerified': instance.isVerified,
      'commentsVisibility': instance.commentsVisibility,
    };

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
  id: json['id'] as String,
  authorId: json['authorId'] as String?,
  author: CommentAuthor.fromJson(json['author'] as Map<String, dynamic>),
  text: json['text'] as String,
  timestamp: json['timestamp'] as String,
  likes: (json['likes'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  replies: (json['replies'] as List<dynamic>?)
      ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
      .toList(),
  mediaUrl: json['mediaUrl'] as String?,
  mediaType: json['mediaType'] as String?,
);

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
  'id': instance.id,
  'authorId': instance.authorId,
  'author': instance.author,
  'text': instance.text,
  'timestamp': instance.timestamp,
  'likes': instance.likes,
  'isLiked': instance.isLiked,
  'replies': instance.replies,
  'mediaUrl': instance.mediaUrl,
  'mediaType': instance.mediaType,
};
