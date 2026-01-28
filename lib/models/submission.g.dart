// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Submission _$SubmissionFromJson(Map<String, dynamic> json) => Submission(
  id: json['id'] as String,
  title: json['title'] as String,
  status: json['status'] as String,
  type: json['type'] as String,
  timestamp: json['timestamp'] as String,
  imageUrl: json['imageUrl'] as String?,
  reward: (json['reward'] as num?)?.toDouble(),
  reason: json['reason'] as String?,
  appealStatus: json['appealStatus'] as String?,
);

Map<String, dynamic> _$SubmissionToJson(Submission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'status': instance.status,
      'type': instance.type,
      'timestamp': instance.timestamp,
      'imageUrl': instance.imageUrl,
      'reward': instance.reward,
      'reason': instance.reason,
      'appealStatus': instance.appealStatus,
    };
