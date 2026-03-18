import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logSignUp({String method = 'email'}) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId ?? '');
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Future<void> logPostCreated({String? type}) =>
      _analytics.logEvent(name: 'post_created', parameters: {'type': type ?? 'text'});

  Future<void> logPostLiked(String postId) =>
      _analytics.logEvent(name: 'post_liked', parameters: {'post_id': postId});

  Future<void> logPostShared(String postId) =>
      _analytics.logEvent(name: 'post_shared', parameters: {'post_id': postId});

  Future<void> logCommentAdded(String postId) =>
      _analytics.logEvent(name: 'comment_added', parameters: {'post_id': postId});

  Future<void> logPostBookmarked(String postId) =>
      _analytics.logEvent(name: 'post_bookmarked', parameters: {'post_id': postId});

  // ── Social ────────────────────────────────────────────────────────────────

  Future<void> logUserFollowed(String targetUserId) =>
      _analytics.logEvent(name: 'user_followed', parameters: {'target_user_id': targetUserId});

  // ── Wallet ────────────────────────────────────────────────────────────────

  Future<void> logRoochipSent(double amount) =>
      _analytics.logEvent(name: 'roochip_sent', parameters: {'amount': amount});

  // ── Screen tracking (manual fallback) ────────────────────────────────────

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);
}
