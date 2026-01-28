// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Activity _$ActivityFromJson(Map<String, dynamic> json) => Activity(
  id: json['id'] as String,
  label: json['label'] as String,
  time: json['time'] as String,
  amount: json['amount'] as String,
  type: json['type'] as String,
  icon: json['icon'] as String,
);

Map<String, dynamic> _$ActivityToJson(Activity instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'time': instance.time,
  'amount': instance.amount,
  'type': instance.type,
  'icon': instance.icon,
};
