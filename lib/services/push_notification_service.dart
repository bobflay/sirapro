import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:sirapro/services/api_service.dart';

/// Handler for background messages - must be a top-level function
/// Note: This only works on mobile platforms, not on web
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _isTokenSentToServer = false;

  /// VAPID key for web push notifications
  /// Get this from Firebase Console -> Project Settings -> Cloud Messaging -> Web Push certificates
  static const String _webVapidKey = 'YOUR_VAPID_KEY_HERE'; // TODO: Replace with your VAPID key

  /// Android notification channel for high importance notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications importantes',
    description: 'Ce canal est utilisé pour les notifications importantes.',
    importance: Importance.high,
  );

  /// Initialize the push notification service
  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Initialize local notifications for foreground display (mobile only)
    if (!kIsWeb) {
      await _initializeLocalNotifications();
    }

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      debugPrint('FCM Token refreshed: $newToken');
      // Send new token to backend if user is authenticated
      await sendTokenToServer();
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
        // Handle notification tap - navigate to specific screen based on payload
      },
    );

    // Create the notification channel on Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        // For web, use VAPID key
        _fcmToken = await _messaging.getToken(vapidKey: _webVapidKey);
        debugPrint('FCM Token (Web): $_fcmToken');
      } else {
        // For iOS, get APNs token first
        if (Platform.isIOS) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('APNs token not available yet');
            // Wait a bit and try again
            await Future.delayed(const Duration(seconds: 2));
          }
        }

        _fcmToken = await _messaging.getToken();
        debugPrint('FCM Token: $_fcmToken');
      }

      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = message.notification;

    // On web, the browser handles notifications automatically
    // On mobile, show local notification when app is in foreground
    if (notification != null && !kIsWeb) {
      final android = message.notification?.android;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap (when app opens from notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    // Navigate to specific screen based on message data
    // This can be customized based on notification type
    final data = message.data;
    if (data.containsKey('type')) {
      debugPrint('Notification type: ${data['type']}, id: ${data['id']}');
      // Navigation can be handled here or via a callback
    }
  }

  /// Send FCM token to backend server
  /// Call this after user login
  Future<bool> sendTokenToServer() async {
    if (_fcmToken == null) {
      debugPrint('No FCM token to send');
      return false;
    }

    // Check if API service has a token (user is authenticated)
    if (_apiService.token == null) {
      debugPrint('User not authenticated, skipping FCM token registration');
      return false;
    }

    try {
      String deviceType;
      if (kIsWeb) {
        deviceType = 'web';
      } else if (Platform.isIOS) {
        deviceType = 'ios';
      } else {
        deviceType = 'android';
      }

      await _apiService.post(
        '/api/fcm-token',
        body: {
          'fcm_token': _fcmToken,
          'device_type': deviceType,
        },
      );

      _isTokenSentToServer = true;
      debugPrint('FCM token sent to server successfully');
      return true;
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
      return false;
    }
  }

  /// Delete FCM token from backend server
  /// Call this before user logout
  Future<bool> deleteTokenFromServer() async {
    if (_fcmToken == null) {
      debugPrint('No FCM token to delete');
      return false;
    }

    try {
      await _apiService.delete('/api/fcm-token?fcm_token=$_fcmToken');

      _isTokenSentToServer = false;
      debugPrint('FCM token deleted from server successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting FCM token from server: $e');
      return false;
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
}
