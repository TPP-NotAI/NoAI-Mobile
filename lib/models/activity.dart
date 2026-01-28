import 'package:json_annotation/json_annotation.dart';

part 'activity.g.dart';

@JsonSerializable()
class Activity {
  final String id;
  final String label;
  final String time;
  final String amount;
  final String type; // 'in' or 'out'
  final String icon;

  Activity({
    required this.id,
    required this.label,
    required this.time,
    required this.amount,
    required this.type,
    required this.icon,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => _$ActivityFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityToJson(this);
}
