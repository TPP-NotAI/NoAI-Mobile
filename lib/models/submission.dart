import 'package:json_annotation/json_annotation.dart';

part 'submission.g.dart';

@JsonSerializable()
class Submission {
  final String id;
  final String title;
  final String status; // 'pending', 'approved', 'rejected'
  final String type; // 'post' or 'appeal'
  final String timestamp;
  final String? imageUrl;
  final double? reward;
  final String? reason;
  final String? appealStatus; // 'can_appeal', 'under_review', 'approved', 'rejected'

  Submission({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.reward,
    this.reason,
    this.appealStatus,
  });

  factory Submission.fromJson(Map<String, dynamic> json) => _$SubmissionFromJson(json);
  Map<String, dynamic> toJson() => _$SubmissionToJson(this);
}
