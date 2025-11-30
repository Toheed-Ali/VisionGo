import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/firebase_security_service.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

/// Background message handler for Firebase Cloud Messaging
/// Must be a top-level function for Flutter to access it when app is terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  
  if (kDebugMode) {
    print('Background notification: ${message.notification?.title}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Register background message handler but don't initialize notifications yet
    // Notifications will be initialized after login/signup in gallery screen
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseSecurityService().initialize();
  } catch (e) {
    if (kDebugMode) print('Initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _hasSeenOnboarding;
  User? _currentUser;
  bool _isAuthChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkMonitoringState();
    }
  }

  /// Check if there's an active monitoring session when app resumes
  Future<void> _checkMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeCode = prefs.getString('active_monitoring_code');
      
      if (activeCode != null && kDebugMode) {
        print('Active monitoring: $activeCode');
      }
    } catch (e) {
      if (kDebugMode) print('Error checking monitoring state: $e');
    }
  }

  /// Initialize app state: onboarding, auth, and monitoring restoration
  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_completed') ?? false;
      final user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        setState(() {
          _hasSeenOnboarding = seen;
          _currentUser = user;
          _isAuthChecked = true;
        });
      }

      // Listen for auth state changes
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (mounted) {
          setState(() => _currentUser = user);
        }
      });

      await _restoreMonitoringIfNeeded();
    } catch (e) {
      if (kDebugMode) print('App initialization error: $e');
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = false;
          _isAuthChecked = true;
        });
      }
    }
  }

  /// Restore active monitoring session if app was restarted
  Future<void> _restoreMonitoringIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeCode = prefs.getString('active_monitoring_code');
      final monitoredObjects = prefs.getStringList('monitored_objects');

      if (activeCode != null && monitoredObjects != null) {
        final securityService = FirebaseSecurityService();
        final isValid = await securityService.validateCode(activeCode);

        if (!isValid) {
          // Clean up invalid pairing
          await prefs.remove('active_monitoring_code');
          await prefs.remove('monitored_objects');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error restoring monitoring: $e');
    }
  }

  /// Determine which screen to show based on app state
  Widget _getInitialScreen() {
    if (_hasSeenOnboarding == false) {
      return const OnboardingScreen();
    }
    
    if (_currentUser != null) {
      return const HomeScreen();
    }
    
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking onboarding and auth status
    if (_hasSeenOnboarding == null || !_isAuthChecked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.tealAccent),
                const SizedBox(height: 16),
                Text(
                  'Initializing VisionGo...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VisionGo - Object Detection App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _getInitialScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}