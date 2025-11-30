import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or update a pairing
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createPairing(String code, List<String> selectedObjects) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Login required');

    final pairingData = {
      'code': code,
      'ownerId': user.uid,
      'ownerEmail': user.email,
      'selectedObjects': selectedObjects,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    // Store in Firestore
    await _firestore.collection('pairings').doc(code).set(pairingData);
  }

  // Validate if a code exists
  Future<bool> validateCode(String code) async {
    final doc = await _firestore.collection('pairings').doc(code).get();
    return doc.exists && (doc.data()?['isActive'] ?? false);
  }


  // Get pairing information
  Future<Map<String, dynamic>?> getPairingInfo(String code) async {
    print('SecurityService: Getting pairing info for code: $code');

    try {
      // Try local storage first
      final localInfo = await _getPairingInfoLocally(code);
      if (localInfo != null) {
        return localInfo;
      }

      // Try shared pairings
      final allUsersPairings = await _getAllUsersPairings();
      if (allUsersPairings.containsKey(code)) {
        await _storePairingLocally(code, allUsersPairings[code]!);
        return allUsersPairings[code];
      }

      return null;
    } catch (e) {
      print('Error getting pairing info: $e');
      return await _getPairingInfoLocally(code);
    }
  }

  // Update selected objects for a pairing
  Future<void> updateSelectedObjects(String code, List<String> objects) async {
    print('SecurityService: Updating objects for code: $code');

    try {
      // Update locally
      await _updatePairingLocally(code, {'selectedObjects': objects});

      // Also update in shared pairings
      await _updateSharedPairing(code, {'selectedObjects': objects});

      print('SecurityService: Objects updated successfully');
    } catch (e) {
      print('Error updating objects: $e');
      await _updatePairingLocally(code, {'selectedObjects': objects});
    }
  }

  // Add an alert
  Future<void> addAlert(String code, String objectLabel) async {
    final alertData = {
      'pairingCode': code,
      'object': objectLabel,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('pairings').doc(code).collection('alerts').add(alertData);
  }

  Stream<List<Map<String, dynamic>>> getAlertsStream(String code) {
    return _firestore
        .collection('pairings')
        .doc(code)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }


  // Get all alerts for a code
  Future<List<Map<String, dynamic>>> getAlerts(String code) async {
    try {
      // Try shared alerts first (for multi-device support)
      final sharedAlerts = await _getSharedAlerts(code);
      if (sharedAlerts.isNotEmpty) {
        await _storeAlertsLocally(code, sharedAlerts);
        return sharedAlerts;
      }

      // Fallback to local alerts
      return await _getAlertsLocally(code);
    } catch (e) {
      print('Error getting alerts: $e');
      return await _getAlertsLocally(code);
    }
  }

  // Remove a pairing
  Future<void> removePairing(String code) async {
    print('SecurityService: Removing pairing for code: $code');

    try {
      // Mark as inactive locally
      await _updatePairingLocally(code, {
        'isActive': false,
        'deletedAt': DateTime.now().toIso8601String(),
      });

      // Remove from user's pairings
      await _removeFromUserPairings(code);

      // Remove from shared pairings
      await _removeFromSharedPairings(code);

      // Remove alerts
      await _removeAlertsLocally(code);
      await _removeSharedAlerts(code);

      print('SecurityService: Pairing removed');
    } catch (e) {
      print('Error removing pairing: $e');
      await _removePairingLocally(code);
      await _removeAlertsLocally(code);
    }
  }

  // LOCAL STORAGE METHODS

  Future<void> _storePairingLocally(String code, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPairingsJson = prefs.getString('all_pairings');
    Map<String, dynamic> allPairings = {};

    if (existingPairingsJson != null) {
      allPairings = jsonDecode(existingPairingsJson) as Map<String, dynamic>;
    }

    allPairings[code] = data;
    await prefs.setString('all_pairings', jsonEncode(allPairings));
  }



  Future<Map<String, dynamic>?> _getPairingInfoLocally(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final allPairingsJson = prefs.getString('all_pairings');

    if (allPairingsJson != null) {
      final allPairings = jsonDecode(allPairingsJson) as Map<String, dynamic>;
      return allPairings[code];
    }

    return null;
  }

  Future<void> _updatePairingLocally(String code, Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final allPairingsJson = prefs.getString('all_pairings');

    if (allPairingsJson != null) {
      final allPairings = jsonDecode(allPairingsJson) as Map<String, dynamic>;
      if (allPairings.containsKey(code)) {
        allPairings[code] = {...allPairings[code], ...updates};
        await prefs.setString('all_pairings', jsonEncode(allPairings));
      }
    }
  }

  Future<void> _removePairingLocally(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final allPairingsJson = prefs.getString('all_pairings');

    if (allPairingsJson != null) {
      final allPairings = jsonDecode(allPairingsJson) as Map<String, dynamic>;
      allPairings.remove(code);
      await prefs.setString('all_pairings', jsonEncode(allPairings));
    }
  }

  Future<void> _removeFromUserPairings(String code) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userPairingsJson = prefs.getString('user_${user.uid}_pairings');

    if (userPairingsJson != null) {
      List<String> userPairings = (jsonDecode(userPairingsJson) as List).cast<String>();
      userPairings.remove(code);
      await prefs.setString('user_${user.uid}_pairings', jsonEncode(userPairings));
    }
  }

  // SHARED PAIRINGS (Simulated multi-device support)
  Future<Map<String, Map<String, dynamic>>> _getAllUsersPairings() async {
    final prefs = await SharedPreferences.getInstance();
    final sharedPairingsJson = prefs.getString('shared_pairings');

    if (sharedPairingsJson != null) {
      final sharedData = jsonDecode(sharedPairingsJson) as Map<String, dynamic>;
      return sharedData.map((key, value) => MapEntry(key, value as Map<String, dynamic>));
    }

    return {};
  }

  Future<void> _updateSharedPairing(String code, Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final sharedPairingsJson = prefs.getString('shared_pairings');
    Map<String, dynamic> sharedPairings = {};

    if (sharedPairingsJson != null) {
      sharedPairings = jsonDecode(sharedPairingsJson) as Map<String, dynamic>;
    }

    if (sharedPairings.containsKey(code)) {
      sharedPairings[code] = {...sharedPairings[code], ...updates};
    } else {
      // Get local pairing data to store in shared
      final localInfo = await _getPairingInfoLocally(code);
      if (localInfo != null) {
        sharedPairings[code] = {...localInfo, ...updates};
      }
    }

    await prefs.setString('shared_pairings', jsonEncode(sharedPairings));
  }

  Future<void> _removeFromSharedPairings(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final sharedPairingsJson = prefs.getString('shared_pairings');

    if (sharedPairingsJson != null) {
      final sharedPairings = jsonDecode(sharedPairingsJson) as Map<String, dynamic>;
      sharedPairings.remove(code);
      await prefs.setString('shared_pairings', jsonEncode(sharedPairings));
    }
  }

  Future<List<Map<String, dynamic>>> _getAlertsLocally(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = prefs.getString('alerts_$code');

    if (alertsJson != null) {
      final alerts = jsonDecode(alertsJson) as List;
      return alerts.map((e) => e as Map<String, dynamic>).toList();
    }

    return [];
  }

  Future<void> _storeAlertsLocally(String code, List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alerts_$code', jsonEncode(alerts));
  }

  Future<void> _removeAlertsLocally(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alerts_$code');
  }

  Future<List<Map<String, dynamic>>> _getSharedAlerts(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final sharedAlertsJson = prefs.getString('shared_alerts_$code');

    if (sharedAlertsJson != null) {
      final alerts = jsonDecode(sharedAlertsJson) as List;
      return alerts.map((e) => e as Map<String, dynamic>).toList();
    }

    return [];
  }

  Future<void> _removeSharedAlerts(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shared_alerts_$code');
  }
}