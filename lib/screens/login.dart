import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers and state variables
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login with Firebase
  Future<void> _login() async {
    // Validate fields
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.black);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      _showSnackBar('Login successful!', Colors.green);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showSnackBar('An error occurred: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handle Firebase auth errors
  void _handleAuthError(FirebaseAuthException e) {
    String message = 'An error occurred';

    switch (e.code) {
      case 'user-not-found': message = 'No user found for that email.'; break;
      case 'wrong-password': message = 'Wrong password provided.'; break;
      case 'invalid-email': message = 'The email address is not valid.'; break;
      case 'user-disabled': message = 'This account has been disabled.'; break;
      case 'invalid-credential': message = 'Invalid email or password.'; break;
    }

    _showSnackBar(message, Colors.red);
  }

  // Show snack bar message
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF1C1C1C), Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: _buildLoginCard(),
        ),
      ),
    );
  }

  // Main login card widget
  Widget _buildLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.07),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.3)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const _TitleSection(),
                const SizedBox(height: 40),
                _EmailField(emailController: _emailController),
                const SizedBox(height: 20),
                _PasswordField(
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  onToggleVisibility: _togglePasswordVisibility,
                ),
                const SizedBox(height: 35),
                _LoginButton(
                  isLoading: _isLoading,
                  onLogin: _login,
                ),
                const SizedBox(height: 30),
                const _SignupLink(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Title section widget
class _TitleSection extends StatelessWidget {
  const _TitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "VisionGo",
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Login to continue your journey",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// Email field widget
class _EmailField extends StatelessWidget {
  final TextEditingController emailController;

  const _EmailField({required this.emailController});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: emailController,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Email",
        hintStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
        filled: true,
        fillColor: Color.fromRGBO(255, 255, 255, 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// Password field widget
class _PasswordField extends StatelessWidget {
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Password",
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// Login button widget
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onLogin;

  const _LoginButton({
    required this.isLoading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF0000), Color(0xFF590000)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(255, 0, 0, 0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: isLoading ? null : onLogin,
        child: isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        )
            : const Text(
          "Login",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

// Signup link widget
class _SignupLink extends StatelessWidget {
  const _SignupLink();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        _SignupButton(),
      ],
    );
  }
}

// Signup button widget
class _SignupButton extends StatelessWidget {
  const _SignupButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),
      child: const Text(
        "Sign Up",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}