import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FirebaseSecurityService {
  static final FirebaseSecurityService _instance = FirebaseSecurityService._internal();
  factory FirebaseSecurityService() => _instance;
  FirebaseSecurityService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  // Cache for pairing info to reduce database reads
  final Map<String, Map<String, dynamic>> _pairingCache = {};

  /// Create or update a pairing in Firebase
  Future<void> createPairing(String code, List<String> selectedObjects) async {
    try {
      debugPrint('FirebaseSecurityService: Creating pairing for code: $code');
      
      final pairingRef = _database.child('security-pairings').child(code);
      
      final pairingData = {
        'selectedObjects': selectedObjects,
        'createdAt': ServerValue.timestamp,
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
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
        // Check if pairing is expired
        final data = snapshot.value as Map<dynamic, dynamic>;
        final expiresAt = data['expiresAt'] as int?;
        
        if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
          debugPrint('FirebaseSecurityService: Code expired');
          await deletePairing(code);
          return false;
        }
        
        debugPrint('FirebaseSecurityService: Code is valid');
        return true;
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
        
        // Check expiration
        final expiresAt = data['expiresAt'] as int?;
        if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
          debugPrint('FirebaseSecurityService: Pairing expired');
          await deletePairing(code);
          return null;
        }
        
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
      });
      
      // Update cache
      if (_pairingCache.containsKey(code)) {
        _pairingCache[code]!['selectedObjects'] = objects;
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
      };
      
      await newAlertRef.set(alertData);
      
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
    
    return alertsRef.onValue.map((event) {
      final List<Map<String, dynamic>> alerts = [];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
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
      
      debugPrint('FirebaseSecurityService: Stream emitting ${alerts.length} alerts');
      return alerts;
    });
  }

  /// Get all alerts for a pairing code (one-time fetch)
  Future<List<Map<String, dynamic>>> getAlerts(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Getting alerts for code: $code');
      
      final alertsRef = _database.child('security-pairings').child(code).child('alerts');
      final snapshot = await alertsRef.get();
      
      final List<Map<String, dynamic>> alerts = [];
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
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
      
      final deviceRef = _database.child('security-pairings').child(code).child('devices').push();
      
      final deviceData = {
        'role': role,
        'userId': userId,
        'deviceName': deviceName,
        'connectedAt': ServerValue.timestamp,
      };
      
      await deviceRef.set(deviceData);
      
      debugPrint('FirebaseSecurityService: Device registered successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error registering device: $e');
      rethrow;
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
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          devices[key] = Map<String, dynamic>.from(value as Map);
        });
      }
      
      debugPrint('FirebaseSecurityService: Found ${devices.length} devices');
      return devices;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting devices: $e');
      return {};
    }
  }

  /// Get all pairing codes for a user
  Future<List<String>> getUserPairingCodes(String userId) async {
    try {
      debugPrint('FirebaseSecurityService: Getting pairing codes for user: $userId');
      
      final pairingsRef = _database.child('security-pairings');
      final snapshot = await pairingsRef.get();
      
      final List<String> codes = [];
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
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
      
      debugPrint('FirebaseSecurityService: Found ${codes.length} pairing codes');
      return codes;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting user pairing codes: $e');
      return [];
    }
  }

  /// Save a notification for a user
  Future<void> saveNotification(
    String userId,
    String code,
    String objectLabel,
    String type,
    String role,
  ) async {
    try {
      debugPrint('FirebaseSecurityService: Saving notification for user: $userId');
      
      final notificationRef = _database.child('user-notifications').child(userId).push();
      
      final notificationData = {
        'pairingCode': code,
        'objectLabel': objectLabel,
        'timestamp': ServerValue.timestamp,
        'type': type, // 'sent' or 'received'
        'deviceRole': role, // 'camera' or 'monitor'
      };
      
      await notificationRef.set(notificationData);
      
      debugPrint('FirebaseSecurityService: Notification saved successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error saving notification: $e');
    }
  }

  /// Stream user notifications in real-time
  Stream<List<Map<String, dynamic>>> streamUserNotifications(String userId) {
    debugPrint('FirebaseSecurityService: Setting up notification stream for user: $userId');
    
    final notificationsRef = _database.child('user-notifications').child(userId);
    
    return notificationsRef.onValue.map((event) {
      final List<Map<String, dynamic>> notifications = [];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((key, value) {
          final notificationMap = Map<String, dynamic>.from(value as Map);
          notificationMap['id'] = key; // Add the notification ID
          notifications.add(notificationMap);
        });
        
        // Sort by timestamp (newest first)
        notifications.sort((a, b) {
          final aTime = a['timestamp'] as int? ?? 0;
          final bTime = b['timestamp'] as int? ?? 0;
          return bTime.compareTo(aTime);
        });
      }
      
      debugPrint('FirebaseSecurityService: Stream emitting ${notifications.length} notifications');
      return notifications;
    });
  }

  /// Delete a specific notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      debugPrint('FirebaseSecurityService: Deleting notification: $notificationId');
      
      final notificationRef = _database.child('user-notifications').child(userId).child(notificationId);
      await notificationRef.remove();
      
      debugPrint('FirebaseSecurityService: Notification deleted successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error deleting notification: $e');
      rethrow;
    }
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      debugPrint('FirebaseSecurityService: Clearing all notifications for user: $userId');
      
      final notificationsRef = _database.child('user-notifications').child(userId);
      await notificationsRef.remove();
      
      debugPrint('FirebaseSecurityService: All notifications cleared successfully');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error clearing notifications: $e');
      rethrow;
    }
  }
}
