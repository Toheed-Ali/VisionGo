import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirebaseSecurityService {
  static final FirebaseSecurityService _instance = FirebaseSecurityService._internal();
  factory FirebaseSecurityService() => _instance;
  FirebaseSecurityService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keys for local storage
  static const String _activePairingsKey = 'active_pairings';
  static const String _pairingHistoryKey = 'pairing_history';

  // Cache for pairing info
  final Map<String, Map<String, dynamic>> _pairingCache = {};

  // Monitoring state
  StreamSubscription? _alertsSubscription;
  String? _currentMonitoringCode;
  List<String> _currentMonitoredObjects = [];
  bool _isMonitoring = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  /// Initialize service and restore active pairings
  Future<void> initialize() async {
    debugPrint('FirebaseSecurityService: Initializing...');
    
    // Restore active pairings from local storage
    await _restoreActivePairings();
    
    debugPrint('FirebaseSecurityService: Initialized');
  }

  /// Create or update a pairing in Firebase
  Future<void> createPairing(String code, List<String> selectedObjects) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      debugPrint('FirebaseSecurityService: Creating pairing for code: $code');

      final pairingRef = _database.child('security-pairings').child(code);

      final pairingData = {
        'selectedObjects': selectedObjects,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
        'lastUpdated': ServerValue.timestamp,
        'ownerId': user.uid,
        'ownerEmail': user.email,
      };

      await pairingRef.set(pairingData);

      // Store pairing locally
      await _storePairingLocally(code, 'camera', selectedObjects);

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

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      final pairingsJson = prefs.getString(_activePairingsKey);
      if (pairingsJson != null) {
        final pairings = Map<String, dynamic>.from(jsonDecode(pairingsJson));
        if (pairings.containsKey(code)) {
          pairings[code]['selectedObjects'] = objects;
          await prefs.setString(_activePairingsKey, jsonEncode(pairings));
        }
      }

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

      debugPrint('FirebaseSecurityService: Stream emitting ${alerts.length} alerts');
      return alerts;
    }).handleError((error) {
      debugPrint('FirebaseSecurityService: Stream error: $error');
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

  /// PUBLIC METHOD: Store pairing as monitor (call this when pairing as monitor)
  Future<void> storePairingAsMonitor(String code, List<String> selectedObjects) async {
    await _storePairingLocally(code, 'monitor', selectedObjects);
    debugPrint('FirebaseSecurityService: Pairing stored as monitor device');
  }

  /// Delete a pairing from Firebase
  Future<void> deletePairing(String code) async {
    try {
      debugPrint('FirebaseSecurityService: Deleting pairing for code: $code');

      final pairingRef = _database.child('security-pairings').child(code);
      await pairingRef.remove();

      // Clear cache
      _pairingCache.remove(code);

      // Remove from local storage
      await _removePairingLocally(code);

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

  /// Save FCM token for a device role in a pairing
  Future<void> saveFCMToken(String code, String role, String fcmToken) async {
    try {
      debugPrint('FirebaseSecurityService: Saving FCM token for code: $code, role: $role');

      final deviceRef = _database.child('security-pairings').child(code).child('devices').child(role);

      final user = _auth.currentUser;
      await deviceRef.update({
        'fcmToken': fcmToken,
        'lastActive': ServerValue.timestamp,
        'isOnline': true,
        'userId': user?.uid,
        'userEmail': user?.email,
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

      // Store monitoring state locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_monitoring_code', code);
      await prefs.setStringList('monitored_objects', monitoredObjects);

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
        cancelOnError: false,
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

      // Mark device as online but not actively monitoring
      try {
        final deviceRef = _database
            .child('security-pairings')
            .child(_currentMonitoringCode!)
            .child('devices')
            .child('monitor');
        await deviceRef.update({
          'lastActive': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('FirebaseSecurityService: Error updating device status: $e');
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

  /// Get all active pairings for current user
  Future<List<Map<String, dynamic>>> getActivePairings() async {
    try {
      debugPrint('FirebaseSecurityService: Getting active pairings');
      
      final prefs = await SharedPreferences.getInstance();
      final pairingsJson = prefs.getString(_activePairingsKey);
      
      if (pairingsJson == null) {
        debugPrint('FirebaseSecurityService: No active pairings found locally');
        return [];
      }
      
      final pairings = Map<String, dynamic>.from(jsonDecode(pairingsJson));
      final List<Map<String, dynamic>> activePairings = [];
      
      for (var entry in pairings.entries) {
        final code = entry.key;
        final pairingData = Map<String, dynamic>.from(entry.value);
        
        // Verify pairing still exists in Firebase
        final isValid = await validateCode(code);
        if (isValid) {
          pairingData['code'] = code;
          activePairings.add(pairingData);
        } else {
          // Remove invalid pairing from local storage
          await _removePairingLocally(code);
        }
      }
      
      debugPrint('FirebaseSecurityService: Found ${activePairings.length} active pairings');
      return activePairings;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting active pairings: $e');
      return [];
    }
  }

  /// Get pairing history for current user
  Future<List<Map<String, dynamic>>> getPairingHistory() async {
    try {
      debugPrint('FirebaseSecurityService: Getting pairing history');
      
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_pairingHistoryKey);
      
      if (historyJson == null) {
        return [];
      }
      
      final history = List<Map<String, dynamic>>.from(
        jsonDecode(historyJson).map((item) => Map<String, dynamic>.from(item))
      );
      
      debugPrint('FirebaseSecurityService: Found ${history.length} pairing history items');
      return history;
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error getting pairing history: $e');
      return [];
    }
  }

  /// PRIVATE METHODS

  /// Store pairing locally
  Future<void> _storePairingLocally(String code, String role, List<String> selectedObjects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store in active pairings
      final pairingsJson = prefs.getString(_activePairingsKey);
      Map<String, dynamic> pairings = {};
      
      if (pairingsJson != null) {
        pairings = Map<String, dynamic>.from(jsonDecode(pairingsJson));
      }
      
      pairings[code] = {
        'role': role,
        'selectedObjects': selectedObjects,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };
      
      await prefs.setString(_activePairingsKey, jsonEncode(pairings));
      
      // Also add to history
      await _addToPairingHistory(code, role);
      
      debugPrint('FirebaseSecurityService: Pairing stored locally');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error storing pairing locally: $e');
    }
  }

  /// Remove pairing from local storage
  Future<void> _removePairingLocally(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove from active pairings
      final pairingsJson = prefs.getString(_activePairingsKey);
      if (pairingsJson != null) {
        final pairings = Map<String, dynamic>.from(jsonDecode(pairingsJson));
        pairings.remove(code);
        await prefs.setString(_activePairingsKey, jsonEncode(pairings));
      }
      
      // Clear monitoring state if it's the active one
      final activeCode = prefs.getString('active_monitoring_code');
      if (activeCode == code) {
        await prefs.remove('active_monitoring_code');
        await prefs.remove('monitored_objects');
      }
      
      debugPrint('FirebaseSecurityService: Pairing removed from local storage');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error removing pairing locally: $e');
    }
  }

  /// Restore active pairings from local storage
  Future<void> _restoreActivePairings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Restore monitoring state if app was closed while monitoring
      final activeCode = prefs.getString('active_monitoring_code');
      final monitoredObjectsList = prefs.getStringList('monitored_objects');
      
      if (activeCode != null && monitoredObjectsList != null) {
        debugPrint('FirebaseSecurityService: Found active monitoring session for $activeCode');
        
        // Verify pairing still exists
        final isValid = await validateCode(activeCode);
        if (isValid) {
          // Don't auto-resume here, let the monitor screen handle it
          debugPrint('FirebaseSecurityService: Active pairing is still valid');
        } else {
          // Clean up invalid monitoring state
          await prefs.remove('active_monitoring_code');
          await prefs.remove('monitored_objects');
          await _removePairingLocally(activeCode);
        }
      }
      
      debugPrint('FirebaseSecurityService: Active pairings restored');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error restoring active pairings: $e');
    }
  }

  /// Add to pairing history
  Future<void> _addToPairingHistory(String code, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_pairingHistoryKey);
      
      List<Map<String, dynamic>> history = [];
      if (historyJson != null) {
        history = List<Map<String, dynamic>>.from(
          jsonDecode(historyJson).map((item) => Map<String, dynamic>.from(item))
        );
      }
      
      // Check if code already exists in history
      final existingIndex = history.indexWhere((item) => item['code'] == code);
      if (existingIndex != -1) {
        // Update existing entry
        history[existingIndex]['lastUsed'] = DateTime.now().toIso8601String();
        history[existingIndex]['role'] = role;
      } else {
        // Add new entry
        history.add({
          'code': code,
          'role': role,
          'firstUsed': DateTime.now().toIso8601String(),
          'lastUsed': DateTime.now().toIso8601String(),
        });
      }
      
      // Keep only last 20 history items
      if (history.length > 20) {
        history = history.sublist(history.length - 20);
      }
      
      await prefs.setString(_pairingHistoryKey, jsonEncode(history));
      
      debugPrint('FirebaseSecurityService: Added to pairing history');
    } catch (e) {
      debugPrint('FirebaseSecurityService: Error adding to history: $e');
    }
  }

  /// Update device activity timestamp
  Future<void> _updateDeviceActivity(String code, String role) async {
    try {
      final deviceRef = _database
          .child('security-pairings')
          .child(code)
          .child('devices')
          .child(role);
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

  /// Cleanup resources
  void dispose() {
    stopMonitoring();
    _pairingCache.clear();
    debugPrint('FirebaseSecurityService: Disposed');
  }
}