import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _hasSeenOnboarding;
  User? _currentUser;
  bool _isAuthChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_completed') ?? false;

    // Get current user
    final user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen;
        _currentUser = user;
        _isAuthChecked = true;
      });
    }

    // Listen to authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  Widget _getInitialScreen() {
    // If onboarding not completed, show onboarding
    if (_hasSeenOnboarding == false) {
      return const OnboardingScreen();
    }

    // If user is already logged in, go directly to home screen
    if (_currentUser != null) {
      return const HomeScreen();
    }

    // Otherwise show login screen
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking onboarding status and auth state
    if (_hasSeenOnboarding == null || !_isAuthChecked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.tealAccent),
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