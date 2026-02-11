/// Response model for content moderation analysis.
class ModerationResult {
  final bool flagged;
  final Map<String, bool> categories;
  final Map<String, double> categoryScores;
  final String severity; // "none", "low", "medium", "high", "extreme"
  final String recommendedAction; // "allow", "warn", "flag", "block", "block_and_report"
  final String? details;

  ModerationResult({
    required this.flagged,
    required this.categories,
    required this.categoryScores,
    required this.severity,
    required this.recommendedAction,
    this.details,
  });

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      flagged: json['flagged'] as bool? ?? false,
      categories: (json['categories'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ??
          {},
      categoryScores: (json['category_scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      severity: json['severity'] as String? ?? 'none',
      recommendedAction: json['recommended_action'] as String? ?? 'allow',
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flagged': flagged,
      'categories': categories,
      'category_scores': categoryScores,
      'severity': severity,
      'recommended_action': recommendedAction,
      'details': details,
    };
  }
}
