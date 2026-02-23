class LocalPostDraft {
  final String id;
  final String title;
  final String content;
  final String postType;
  final List<String> tags;
  final String? location;
  final List<Map<String, dynamic>> taggedPeople;
  final List<String> mediaPaths;
  final List<String> mediaTypes;
  final bool certifyHumanGenerated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalPostDraft({
    required this.id,
    required this.title,
    required this.content,
    required this.postType,
    required this.tags,
    required this.location,
    required this.taggedPeople,
    required this.mediaPaths,
    required this.mediaTypes,
    required this.certifyHumanGenerated,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasContent =>
      title.trim().isNotEmpty ||
      content.trim().isNotEmpty ||
      mediaPaths.isNotEmpty ||
      tags.isNotEmpty ||
      (location?.trim().isNotEmpty ?? false) ||
      taggedPeople.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'post_type': postType,
      'tags': tags,
      'location': location,
      'tagged_people': taggedPeople,
      'media_paths': mediaPaths,
      'media_types': mediaTypes,
      'certify_human_generated': certifyHumanGenerated,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LocalPostDraft.fromJson(Map<String, dynamic> json) {
    final tagged = (json['tagged_people'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return LocalPostDraft(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      postType: (json['post_type'] as String?) ?? 'Text',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      location: (json['location'] as String?)?.trim().isEmpty == true
          ? null
          : json['location'] as String?,
      taggedPeople: tagged,
      mediaPaths: (json['media_paths'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      mediaTypes: (json['media_types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      certifyHumanGenerated:
          json['certify_human_generated'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  LocalPostDraft copyWith({
    String? id,
    String? title,
    String? content,
    String? postType,
    List<String>? tags,
    String? location,
    bool clearLocation = false,
    List<Map<String, dynamic>>? taggedPeople,
    List<String>? mediaPaths,
    List<String>? mediaTypes,
    bool? certifyHumanGenerated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalPostDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      tags: tags ?? this.tags,
      location: clearLocation ? null : (location ?? this.location),
      taggedPeople: taggedPeople ?? this.taggedPeople,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      certifyHumanGenerated:
          certifyHumanGenerated ?? this.certifyHumanGenerated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
