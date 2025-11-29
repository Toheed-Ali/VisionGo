import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSecurityService {
  static final FirebaseSecurityService _instance = FirebaseSecurityService._internal();
  factory FirebaseSecurityService() => _instance;
  FirebaseSecurityService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for pairing info to reduce database reads
  final Map<String, Map<String, dynamic>> _pairingCache = {};

  // Monitoring state management
  StreamSubscription? _alertsSubscription;
  String? _currentMonitoringCode;
  List<String> _currentMonitoredObjects = [];
  bool _isMonitoring = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  /// Create or update a pairing in Firebase
  Future<void> createPairing(String code, List<String> selectedObjects) async {
    try {
      debugPrint('FirebaseSecurityService: Creating pairing for code: $code');

      final pairingRef = _database.child('security-pairings').child(code);

      final pairingData = {
        'selectedObjects': selectedObjects,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
        'lastUpdated': ServerValue.timestamp,
      };

      await pairingRef.set(pairingData);

      // Update cache
      _pairingCache[code] = pairingData;

      debugPrint('FirebaseSecurityService: Pairing created successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error creating pairing: $e');
      rethrow;
    }
  }

  /// Validate if a pairing code exists in Firebase
  Future<bool> validateCode(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Validating code: $code');

      final pairingRef = _database.child('security-pairings').child(code);
      final snapshot = await pairingRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        final isActive = data?['isActive'] ?? true;
        debugPrint('FirebaseSecurityService: Code is ${isActive ? 'valid' : 'inactive'}');
        return isActive;
      }

      debugPrint('FirebaseSecurityService: Code not found');
      return false;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error validating code: $e');
      return false;
    }
  }

  /// Get pairing information from Firebase
  Future<Map<String, dynamic>?> getPairingInfo(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Getting pairing info for code: $code');

      // Check cache first
      if (_pairingCache.containsKey(code)) {
        debugPrint('FirebaseSecurityService: Info found in cache');
        return _pairingCache[code];
      }

      final pairingRef = _database.child('security-pairings').child(code);
      final snapshot = await pairingRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        // Update cache
        _pairingCache[code] = data;

        debugPrint('FirebaseSecurityService: Info found in Firebase');
        return data;
      }

      debugPrint('FirebaseSecurityService: Info not found');
      return null;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting pairing info: $e');
      return null;
    }
  }

  /// Update selected objects for a pairing
  Future<void> updateSelectedObjects(String code, List<String> objects) async {
    try {
      debugPrint('FirebaseSecurityService: Updating objects for code: $code');

      final pairingRef = _database.child('security-pairings').child(code);
      await pairingRef.update({
        'selectedObjects': objects,
        'lastUpdated': ServerValue.timestamp,
      });

      // Update cache
      if (_pairingCache.containsKey(code)) {
        _pairingCache[code]!['selectedObjects'] = objects;
        _pairingCache[code]!['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
      }

      // Update current monitored objects if this is the active pairing
      if (_currentMonitoringCode == code) {
        _currentMonitoredObjects = objects;
      }

      debugPrint('FirebaseSecurityService: Objects updated successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error updating objects: $e');
      rethrow;
    }
  }

  /// Add an alert to Firebase
  Future<void> addAlert(String code, String objectLabel, double confidence) async {
    try {
      debugPrint('FirebaseSecurityService: Adding alert for code: $code, object: $objectLabel');

      final alertsRef = _database.child('security-pairings').child(code).child('alerts');
      final newAlertRef = alertsRef.push();

      final alertData = {
        'objectLabel': objectLabel,
        'timestamp': ServerValue.timestamp,
        'confidence': confidence,
        'id': newAlertRef.key,
      };

      await newAlertRef.set(alertData);

      // Also update last activity
      await _updateDeviceActivity(code, 'camera');

      debugPrint('FirebaseSecurityService: Alert added successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error adding alert: $e');
      rethrow;
    }
  }

  /// Stream alerts for a pairing code (real-time updates)
  Stream<List<Map<String, dynamic>>> streamAlerts(String code) {
    debugPrint('FirebaseSecurityService: Setting up alert stream for code: $code');

    final alertsRef = _database.child('security-pairings').child(code).child('alerts');

    return alertsRef.orderByChild('timestamp').onValue.map((event) {
      final List<Map<String, dynamic>> alerts = [];

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          data.forEach((key, value) {
            final alertMap = Map<String, dynamic>.from(value as Map);
            alertMap['id'] = key; // Add the alert ID
            alerts.add(alertMap);
          });

          // Sort by timestamp (newest first)
          alerts.sort((a, b) {
            final aTime = a['timestamp'] as int? ?? 0;
            final bTime = b['timestamp'] as int? ?? 0;
            return bTime.compareTo(aTime);
          });
        }
      }

      debugPrint('FirebaseSecurityService: Stream emitting ${alerts.length} alerts');
      return alerts;
    }).handleError((error) {
      debugPrint('FirebaseSecurityService: Stream error: $error');
      // Don't throw the error, just return empty list to keep stream alive
      return <List<Map<String, dynamic>>>[];
    });
  }

  /// Get all alerts for a pairing code (one-time fetch)
  Future<List<Map<String, dynamic>>> getAlerts(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Getting alerts for code: $code');

      final alertsRef = _database.child('security-pairings').child(code).child('alerts');
      final snapshot = await alertsRef.orderByChild('timestamp').limitToLast(50).get();

      final List<Map<String, dynamic>> alerts = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          data.forEach((key, value) {
            final alertMap = Map<String, dynamic>.from(value as Map);
            alertMap['id'] = key;
            alerts.add(alertMap);
          });

          // Sort by timestamp (newest first)
          alerts.sort((a, b) {
            final aTime = a['timestamp'] as int? ?? 0;
            final bTime = b['timestamp'] as int? ?? 0;
            return bTime.compareTo(aTime);
          });
        }
      }

      debugPrint('FirebaseSecurityService: Found ${alerts.length} alerts');
      return alerts;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting alerts: $e');
      return [];
    }
  }

  /// Delete a pairing from Firebase
  Future<void> deletePairing(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Deleting pairing for code: $code');

      final pairingRef = _database.child('security-pairings').child(code);
      await pairingRef.remove();

      // Clear cache
      _pairingCache.remove(code);

      // Stop monitoring if this was the active pairing
      if (_currentMonitoringCode == code) {
        await stopMonitoring();
      }

      debugPrint('FirebaseSecurityService: Pairing deleted successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error deleting pairing: $e');
      rethrow;
    }
  }

  /// Register a device with a pairing code
  Future<void> registerDevice(String code, String role, String userId, String deviceName) async {
    try {
      debugPrint('FirebaseSecurityService: Registering device for code: $code, role: $role');

      final deviceRef = _database.child('security-pairings').child(code).child('devices').child(role);

      final deviceData = {
        'role': role,
        'userId': userId,
        'deviceName': deviceName,
        'connectedAt': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
        'isOnline': true,
      };

      await deviceRef.set(deviceData);

      debugPrint('FirebaseSecurityService: Device registered successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error registering device: $e');
      rethrow;
    }
  }

  /// Save FCM token for a device role in a pairing
  Future<void> saveFCMToken(String code, String role, String fcmToken) async {
    try {
      debugPrint('FirebaseSecurityService: Saving FCM token for code: $code, role: $role');

      final deviceRef = _database.child('security-pairings').child(code).child('devices').child(role);

      await deviceRef.update({
        'fcmToken': fcmToken,
        'lastActive': ServerValue.timestamp,
        'isOnline': true,
      });

      debugPrint('FirebaseSecurityService: FCM token saved successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error saving FCM token: $e');
      rethrow;
    }
  }

  /// Get FCM token for a specific device role
  Future<String?> getFCMToken(String code, String role) async {
    try {
      debugPrint('FirebaseSecurityService: Getting FCM token for code: $code, role: $role');

      final deviceRef = _database.child('security-pairings').child(code).child('devices').child(role);
      final snapshot = await deviceRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        final token = data?['fcmToken'] as String?;

        debugPrint('FirebaseSecurityService: FCM token ${token != null ? "found" : "not found"}');
        return token;
      }

      debugPrint('FirebaseSecurityService: Device not found');
      return null;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting FCM token: $e');
      return null;
    }
  }

  /// Get all devices for a pairing code
  Future<Map<String, dynamic>> getDevices(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Getting devices for code: $code');

      final devicesRef = _database.child('security-pairings').child(code).child('devices');
      final snapshot = await devicesRef.get();

      final Map<String, dynamic> devices = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            devices[key] = Map<String, dynamic>.from(value as Map);
          });
        }
      }

      debugPrint('FirebaseSecurityService: Found ${devices.length} devices');
      return devices;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting devices: $e');
      return {};
    }
  }

  /// MONITORING MANAGEMENT METHODS

  /// Start monitoring alerts for a pairing code
  Future<void> startMonitoring(String code, List<String> monitoredObjects) async {
    try {
      // Stop any existing monitoring
      await stopMonitoring();

      debugPrint('FirebaseSecurityService: Starting monitoring for $code');

      _currentMonitoringCode = code;
      _currentMonitoredObjects = List.from(monitoredObjects);
      _isMonitoring = true;

      // Update device activity
      await _updateDeviceActivity(code, 'monitor');

      // Start listening for alerts
      _alertsSubscription = streamAlerts(code).listen(
            (alerts) {
          debugPrint('FirebaseSecurityService: Received ${alerts.length} alerts');
          _handleNewAlerts(alerts);
        },
        onError: (error) {
          debugPrint('FirebaseSecurityService: Monitoring stream error: $error');
          _scheduleReconnection(code);
        },
        cancelOnError: false, // Keep stream alive even on errors
      );

      // Start heartbeat to keep connection alive
      _startHeartbeat(code);

      debugPrint('FirebaseSecurityService: Monitoring started successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error starting monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    debugPrint('FirebaseSecurityService: Stopping monitoring');

    _alertsSubscription?.cancel();
    _alertsSubscription = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _isMonitoring = false;

    if (_currentMonitoringCode != null) {
      debugPrint('FirebaseSecurityService: Stopped monitoring $_currentMonitoringCode');

      // Mark device as offline
      try {
        final deviceRef = _database.child('security-pairings').child(_currentMonitoringCode!).child('devices').child('monitor');
        await deviceRef.update({
          'isOnline': false,
          'lastActive': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('FirebaseSecurityService: Error marking device offline: $e');
      }

      _currentMonitoringCode = null;
    }
  }

  /// Check if currently monitoring
  bool isMonitoring() {
    return _isMonitoring && _currentMonitoringCode != null;
  }

  /// Get current monitoring code
  String? getCurrentMonitoringCode() {
    return _currentMonitoringCode;
  }

  /// Get current monitored objects
  List<String> getCurrentMonitoredObjects() {
    return List.from(_currentMonitoredObjects);
  }

  /// Resume monitoring after app restart
  Future<bool> resumeMonitoring(String code, List<String> monitoredObjects) async {
    try {
      debugPrint('FirebaseSecurityService: Resuming monitoring for $code');

      // Validate pairing still exists
      final isValid = await validateCode(code);
      if (!isValid) {
        debugPrint('FirebaseSecurityService: Cannot resume - pairing no longer valid');
        return false;
      }

      // Start monitoring
      await startMonitoring(code, monitoredObjects);

      debugPrint('FirebaseSecurityService: Monitoring resumed successfully');
      return true;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error resuming monitoring: $e');
      return false;
    }
  }

  /// PRIVATE METHODS

  /// Update device activity timestamp
  Future<void> _updateDeviceActivity(String code, String role) async {
    try {
      final deviceRef = _database.child('security-pairings').child(code).child('devices').child(role);
      await deviceRef.update({
        'lastActive': ServerValue.timestamp,
        'isOnline': true,
      });
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error updating device activity: $e');
    }
  }

  /// Handle new alerts from stream
  void _handleNewAlerts(List<Map<String, dynamic>> alerts) {
    if (alerts.isNotEmpty) {
      final latestAlert = alerts.first;
      final objectLabel = latestAlert['objectLabel']?.toString() ?? 'Unknown';

      // Check if this object is being monitored
      if (_currentMonitoredObjects.contains(objectLabel)) {
        debugPrint('FirebaseSecurityService: Monitored object detected: $objectLabel');
        // This alert should trigger a notification
        // The notification will be handled by the UI layer
      }
    }
  }

  /// Schedule reconnection when stream fails
  void _scheduleReconnection(String code) {
    debugPrint('FirebaseSecurityService: Scheduling reconnection in 10 seconds...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () async {
      if (_isMonitoring && _currentMonitoringCode == code) {
        debugPrint('FirebaseSecurityService: Attempting to reconnect...');
        try {
          await startMonitoring(code, _currentMonitoredObjects);
        } catch (e) {
          debugPrint('FirebaseSecurityService: Reconnection failed: $e');
          // Schedule another attempt
          _scheduleReconnection(code);
        }
      }
    });
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat(String code) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_isMonitoring && _currentMonitoringCode == code) {
        try {
          await _updateDeviceActivity(code, 'monitor');
          debugPrint('FirebaseSecurityService: Heartbeat sent');
        } catch (e) {
          debugPrint('FirebaseSecurityService: Heartbeat failed: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Get all pairing codes for a user
  Future<List<String>> getUserPairingCodes(String userId) async {
    try {
      debugPrint('FirebaseSecurityService: Getting pairing codes for user: $userId');

      final pairingsRef = _database.child('security-pairings');
      final snapshot = await pairingsRef.get();

      final List<String> codes = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          for (var entry in data.entries) {
            final code = entry.key as String;
            final pairingData = entry.value as Map<dynamic, dynamic>;

            // Check if user is part of this pairing
            if (pairingData['devices'] != null) {
              final devices = pairingData['devices'] as Map<dynamic, dynamic>;
              for (var device in devices.values) {
                final deviceMap = device as Map<dynamic, dynamic>;
                if (deviceMap['userId'] == userId) {
                  codes.add(code);
                  break;
                }
              }
            }
          }
        }
      }

      debugPrint('FirebaseSecurityService: Found ${codes.length} pairing codes');
      return codes;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting user pairing codes: $e');
      return [];
    }
  }

  /// Cleanup resources
  void dispose() {
    stopMonitoring();
    _pairingCache.clear();
    debugPrint('FirebaseSecurityService: Disposed');
  }
}