import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';

/// FCM API Service using Firebase HTTP v1 API
/// Works on FREE tier without Legacy Server Key
class FCMApiService {
  static final FCMApiService _instance = FCMApiService._internal();
  factory FCMApiService() => _instance;
  FCMApiService._internal();

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _projectId;

  /// Initialize the service by loading service account credentials
  Future<void> initialize() async {
    try {
      debugPrint('FCMApiService: Initializing with service account...');
      
      // Load the service account JSON from assets
      final jsonString = await rootBundle.loadString('assets/vision-go-b1cda-firebase-adminsdk-fbsvc-b137b42825.json');
      final Map<String, dynamic> serviceAccount = jsonDecode(jsonString);
      
      // Extract project ID
      _projectId = serviceAccount['project_id'];
      debugPrint('FCMApiService: Project ID: $_projectId');
      
      debugPrint('FCMApiService: Initialization complete');
    } catch (e) {
      debugPrint('FCMApiService: Initialization error: $e');
    }
  }

  /// Get OAuth 2.0 access token for FCM v1 API
  Future<String?> _getAccessToken() async {
    try {
      // Check if we have a valid cached token
      if (_accessToken != null && _tokenExpiry != null) {
        if (DateTime.now().isBefore(_tokenExpiry!)) {
          return _accessToken;
        }
      }

      debugPrint('FCMApiService: Getting new access token...');

      // Load service account JSON
      final jsonString = await rootBundle.loadString('assets/vision-go-b1cda-firebase-adminsdk-fbsvc-b137b42825.json');
      final serviceAccountJson = jsonDecode(jsonString);

      // Create service account credentials
      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Define FCM scope
      const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Get access credentials
      final client = http.Client();
      try {
        final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
          accountCredentials,
          scopes,
          client,
        );

        _accessToken = accessCredentials.accessToken.data;
        _tokenExpiry = accessCredentials.accessToken.expiry;

        debugPrint('FCMApiService: Access token obtained successfully');
        debugPrint('FCMApiService: Token expires at: $_tokenExpiry');

        return _accessToken;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('FCMApiService: Error getting access token: $e');
      return null;
    }
  }

  /// Send push notification using Firebase HTTP v1 API
  Future<bool> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Ensure service is initialized
      if (_projectId == null) {
        await initialize();
      }

      if (_projectId == null) {
        debugPrint('FCMApiService: Project ID not available');
        return false;
      }

      debugPrint('FCMApiService: Sending notification via v1 API...');

      // Get access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('FCMApiService: Failed to obtain access token');
        return false;
      }

      // Construct v1 API URL
      final url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final message = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'security_alerts',
              'sound': 'default',
              'color': '#ff0000',
              'notification_priority': 'PRIORITY_MAX',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
                'content-available': 1,
                'alert': {
                  'title': title,
                  'body': body,
                },
              },
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('FCMApiService: ✅ Notification sent successfully (v1 API)');
        debugPrint('FCMApiService: Response: ${response.body}');
        return true;
      } else {
        debugPrint('FCMApiService: ❌ Failed to send notification');
        debugPrint('FCMApiService: Status: ${response.statusCode}');
        debugPrint('FCMApiService: Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('FCMApiService: Error sending notification: $e');
      return false;
    }
  }

  /// Send security alert notification
  Future<bool> sendSecurityAlert({
    required String fcmToken,
    required String objectLabel,
    required double confidence,
    required String pairingCode,
  }) async {
    final confidencePercent = (confidence * 100).toInt();

    return await sendNotification(
      fcmToken: fcmToken,
      title: '🚨 Security Alert',
      body: '$objectLabel detected ($confidencePercent% confidence)',
      data: {
        'type': 'security_alert',
        'pairingCode': pairingCode,
        'object': objectLabel,
        'confidence': confidence.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'channelId': 'security_alerts',
      },
    );
  }
}