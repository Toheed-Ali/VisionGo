import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_security_service.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 Background message received: ${message.messageId}');
    print('   Data: ${message.data}');
    print('   Notification: ${message.notification?.title}');
  }

  // Background notifications are handled by the OS using the data payload
  // Local notifications will be shown automatically by FCM
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

  bool _isInitialized = false;

  /// Initialize notification services
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationService: Already initialized');
      return;
    }

    try {
      debugPrint('NotificationService: Initializing...');

      // Request permission (iOS and Android 13+)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
        announcement: false,
      );

      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        if (_fcmToken != null) {
          debugPrint('NotificationService: FCM Token obtained');
          await _saveFCMTokenLocally(_fcmToken!);
        }

        // Configure foreground notification presentation
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Setup message handlers
        _setupMessageHandlers();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('NotificationService: Token refreshed');
          _fcmToken = newToken;
          _saveFCMTokenLocally(newToken);
          _updateAllPairingsWithToken(newToken);
        });

        // Restore monitoring notifications if needed
        await _restoreMonitoringState();

        _isInitialized = true;
        debugPrint('NotificationService: Initialization complete');
      } else {
        debugPrint('NotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('NotificationService: Initialization error: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    await _createNotificationChannels();

    debugPrint('NotificationService: Local notifications initialized');
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // High priority channel for security alerts
      const alertChannel = AndroidNotificationChannel(
        'security_alerts',
        'Security Alerts',
        description: 'High priority notifications for object detection alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
        showBadge: true,
      );

      // Default channel for general notifications
      const defaultChannel = AndroidNotificationChannel(
        'default_channel',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin.createNotificationChannel(alertChannel);
      await androidPlugin.createNotificationChannel(defaultChannel);

      debugPrint('NotificationService: Notification channels created');
    }
  }

  /// Setup FCM message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification when app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    debugPrint('NotificationService: Message handlers configured');
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('NotificationService: Foreground message received');
    await _showLocalNotificationFromMessage(message);
  }

  /// Handle notification tap
  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped: ${response.payload}');

    // TODO: Navigate to appropriate screen based on payload
    // You can use a global navigator key or notification callback
  }

  /// Handle message when app opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('NotificationService: Message opened app: ${message.messageId}');
    // TODO: Navigate to appropriate screen
  }

  /// Show local notification from RemoteMessage
  Future<void> _showLocalNotificationFromMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Security Alert',
        body: notification.body ?? 'Object detected',
        payload: jsonEncode(data),
        channelId: data['channelId'] ?? 'security_alerts',
      );
    } else if (data.isNotEmpty) {
      // Handle data-only messages
      await _showLocalNotification(
        title: data['title'] ?? 'Security Alert',
        body: data['body'] ?? 'Object detected',
        payload: jsonEncode(data),
        channelId: data['channelId'] ?? 'security_alerts',
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'security_alerts',
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'security_alerts' ? 'Security Alerts' : 'General Notifications',
        channelDescription: 'Notifications for object detection alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: const Color.fromARGB(255, 255, 0, 0),
        ledColor: const Color.fromARGB(255, 255, 0, 0),
        ledOnMs: 1000,
        ledOffMs: 500,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'VisionGo Security',
        ),
        ticker: 'Security Alert',
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('NotificationService: Local notification shown (ID: $notificationId)');
    } catch (e) {
      debugPrint('NotificationService: Error showing notification: $e');
    }
  }

  /// Send notification for security alert
  Future<void> sendSecurityAlert({
    required String object,
    required double confidence,
    required String pairingCode,
  }) async {
    debugPrint('NotificationService: Sending security alert for $object');

    const title = '🚨 Security Alert';
    final body = '$object detected (${(confidence * 100).toStringAsFixed(0)}% confidence)';

    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'security_alert',
        'pairingCode': pairingCode,
        'object': object,
        'confidence': confidence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
      channelId: 'security_alerts',
    );
  }

  /// Save FCM token locally
  Future<void> _saveFCMTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugPrint('NotificationService: FCM token saved locally');
    } catch (e) {
      debugPrint('NotificationService: Error saving FCM token: $e');
    }
  }

  /// Update all active pairings with new FCM token
  Future<void> _updateAllPairingsWithToken(String token) async {
    try {
      final securityService = FirebaseSecurityService();
      final activePairings = await securityService.getActivePairings();

      for (var pairing in activePairings) {
        final code = pairing['code'] as String?;
        final role = pairing['role'] as String?;

        if (code != null && role != null) {
          await securityService.saveFCMToken(code, role, token);
          debugPrint('NotificationService: Updated token for pairing $code');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error updating pairings with token: $e');
    }
  }

  /// Restore monitoring state after app restart
  Future<void> _restoreMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeCode = prefs.getString('active_monitoring_code');

      if (activeCode != null) {
        debugPrint('NotificationService: Restoring monitoring for $activeCode');

        // Token is already saved in Firebase, notifications will work in background
        debugPrint('NotificationService: Background notifications enabled for $activeCode');
      }
    } catch (e) {
      debugPrint('NotificationService: Error restoring monitoring state: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('NotificationService: All notifications cancelled');
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    debugPrint('NotificationService: Notification $id cancelled');
  }

  /// Get initial message if app was opened from terminated state
  Future<RemoteMessage?> getInitialMessage() async {
    return await _firebaseMessaging.getInitialMessage();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;

    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Request notification permissions again
  Future<bool> requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Dispose and cleanup
  void dispose() {
    // Cancel all subscriptions if needed
    debugPrint('NotificationService: Disposed');
  }
}