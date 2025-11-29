import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Initialize notification services
  Future<void> initialize() async {
    // Request permission (iOS and Android 13+)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $_fcmToken');
      }

      //  Configure foreground notification presentation
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Setup message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
      });
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'security_alerts',
      'Security Alerts',
      description: 'Notifications for object detection alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Setup FCM message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification when app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Foreground message received: ${message.messageId}');
    }

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }

    // TODO: Navigate to appropriate screen based on payload
    // This will be handled by the app's navigation logic
  }

  // Handle message when app opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Message opened app: ${message.messageId}');
    }

    // TODO: Navigate to appropriate screen
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'security_alerts',
        'Security Alerts',
        channelDescription: 'Notifications for object detection alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: data.toString(),
      );
    }
  }

  // Send notification for security alert
  Future<void> sendSecurityAlert({
    required String object,
    required double confidence,
    required String pairingCode,
  }) async {
    // This would typically call a Cloud Function or your backend
    // to send the notification to the paired monitor device
    
    if (kDebugMode) {
      print('Sending security alert: $object (${(confidence * 100).toStringAsFixed(0)}%)');
    }

    // For now, we'll show a local notification as a demo
    const androidDetails = AndroidNotificationDetails(
      'security_alerts',
      'Security Alerts',
      channelDescription: 'Notifications for object detection alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Security Alert',
      '$object detected (${(confidence * 100).toStringAsFixed(0)}% confidence)',
      details,
      payload: 'security_alert:$pairingCode',
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Get initial message if app was opened from terminated state
  Future<RemoteMessage?> getInitialMessage() async {
    return await _firebaseMessaging.getInitialMessage();
  }
}
