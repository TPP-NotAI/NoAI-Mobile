import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'supabase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message received: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  late FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channels for Android
  static const AndroidNotificationChannel _socialChannel =
      AndroidNotificationChannel(
        'rooverse_social',
        'Social Notifications',
        description: 'Notifications for likes, comments, and follows',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        'rooverse_messages',
        'Messages',
        description: 'Notifications for direct messages and chats',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  static const AndroidNotificationChannel _walletChannel =
      AndroidNotificationChannel(
        'rooverse_wallet',
        'Wallet Notifications',
        description: 'Notifications for transactions and rewards',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  bool _isFirebaseAvailable = false;

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _messaging = FirebaseMessaging.instance;
      _isFirebaseAvailable = true;

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Create notification channels for Android
      await _createNotificationChannels();

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state via notification)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Get FCM token and save it
      await _getAndSaveToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToServer);

      _initialized = true;
      debugPrint('PushNotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('PushNotificationService: Failed to initialize - $e');
      _isFirebaseAvailable = false;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint(
      'PushNotificationService: Permission status - ${settings.authorizationStatus}',
    );

    // For iOS foreground presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_socialChannel);
        await androidPlugin.createNotificationChannel(_messageChannel);
        await androidPlugin.createNotificationChannel(_walletChannel);
      }
    }
  }

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('PushNotificationService: Foreground message - ${message.data}');

    final notification = message.notification;
    if (notification == null) return;

    // Determine channel based on notification type
    final type = message.data['type'] ?? 'social';
    final channel = _getChannelForType(type);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'ROOVERSE',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Get notification channel based on type
  AndroidNotificationChannel _getChannelForType(String type) {
    switch (type) {
      case 'message':
      case 'dm':
      case 'chat':
        return _messageChannel;
      case 'transaction':
      case 'reward':
      case 'wallet':
        return _walletChannel;
      default:
        return _socialChannel;
    }
  }

  /// Handle notification tap from FCM
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint(
      'PushNotificationService: Notification tapped - ${message.data}',
    );
    _navigateToScreen(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      'PushNotificationService: Local notification tapped - ${response.payload}',
    );
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateToScreen(data);
      } catch (e) {
        debugPrint('PushNotificationService: Failed to parse payload - $e');
      }
    }
  }

  /// Navigate to appropriate screen based on notification data
  void _navigateToScreen(Map<String, dynamic> data) {
    // Navigation will be handled by the app - store the data for later retrieval
    _pendingNotificationData = data;
    debugPrint('PushNotificationService: Pending navigation data stored');
  }

  Map<String, dynamic>? _pendingNotificationData;

  /// Get and clear pending notification data
  Map<String, dynamic>? consumePendingNotificationData() {
    final data = _pendingNotificationData;
    _pendingNotificationData = null;
    return data;
  }

  /// Get FCM token and save to server
  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('PushNotificationService: FCM Token - $token');
        await _saveTokenToServer(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService: Failed to get token - $e');
    }
  }

  /// Save FCM token to Supabase for the current user
  Future<void> _saveTokenToServer(String token) async {
    try {
      final client = SupabaseService().client;
      final userId = client.auth.currentUser?.id;

      if (userId != null) {
        await client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,token');

        debugPrint('PushNotificationService: Token saved to server');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Failed to save token - $e');
    }
  }

  /// Show a local notification directly (for in-app events)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String type = 'social',
    Map<String, dynamic>? data,
  }) async {
    final channel = _getChannelForType(type);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('PushNotificationService: Subscribed to $topic');
    } catch (e) {
      debugPrint('PushNotificationService: Failed to subscribe to topic - $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('PushNotificationService: Unsubscribed from $topic');
    } catch (e) {
      debugPrint(
        'PushNotificationService: Failed to unsubscribe from topic - $e',
      );
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    if (!_isFirebaseAvailable) return null;
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('PushNotificationService: Failed to get token - $e');
      return null;
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    if (!_isFirebaseAvailable) return;
    try {
      await _messaging.deleteToken();
      debugPrint('PushNotificationService: Token deleted');
    } catch (e) {
      debugPrint('PushNotificationService: Failed to delete token - $e');
    }
  }
}
