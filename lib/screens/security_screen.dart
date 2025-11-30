import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'security_monitor_screen.dart';
import 'security_camera_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String? _deviceRole; // 'camera' or 'monitor'
  String? _pairingCode;
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  String _formatCode(String code) {
    // Format 8-digit code as "XXXX XXXX" for better readability
    if (code.length == 8) {
      return '${code.substring(0, 4)} ${code.substring(4)}';
    }
    return code;
  }

  void _selectRole(String role) {
    setState(() {
      _deviceRole = role;
      if (role == 'camera') {
        _pairingCode = _generateCode();
      }
    });
  }

  void _pairDevice() {
    final code = _codeController.text.trim().replaceAll(' ', '');

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a pairing code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (code.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing code must be 8 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to monitor screen with code
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecurityMonitorScreen(
          pairingCode: code.toUpperCase(),
        ),
      ),
    );
  }

  void _startCamera() {
    if (_pairingCode != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecurityCameraScreen(
            pairingCode: _pairingCode!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _deviceRole == null,
      onPopInvoked: (didPop) {
        // If a role is selected and user pressed back, go back to role selection
        if (!didPop && _deviceRole != null) {
          setState(() {
            _deviceRole = null;
            _pairingCode = null;
            _codeController.clear();
          });
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: const Center(
                  child: Text(
                    'Security System',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Main content
              Expanded(
                child: _deviceRole == null
                    ? _buildRoleSelection()
                    : _deviceRole == 'camera'
                    ? _buildCameraSetup()
                    : _buildMonitorSetup(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.security,
            size: 80,
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose Device Role',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select how you want to use this device',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Camera Option
          _buildRoleCard(
            icon: Icons.videocam,
            title: 'Use as Camera',
            description: 'Monitor area and detect objects',
            onTap: () => _selectRole('camera'),
          ),
          const SizedBox(height: 16),

          // Monitor Option
          _buildRoleCard(
            icon: Icons.notifications_active,
            title: 'Receive Alerts',
            description: 'Get notifications from paired cameras',
            onTap: () => _selectRole('monitor'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSetup() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_2,
            size: 80,
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 24),
          const Text(
            'Camera Pairing Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Share this code with monitoring devices',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),

          // Pairing Code Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatCode(_pairingCode ?? ''),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _pairingCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Start Camera Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Security Camera',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Back Button
          TextButton(
            onPressed: () {
              setState(() {
                _deviceRole = null;
                _pairingCode = null;
              });
            },
            child: const Text(
              'Change Role',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.link,
            size: 80,
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 24),
          const Text(
            'Pair with Camera',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the 8-digit pairing code from the camera device',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Code Input Field
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'XXXXXXXX',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.tealAccent,
                  width: 2,
                ),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 32),

          // Pair Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pairDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Pair Device',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Back Button
          TextButton(
            onPressed: () {
              setState(() {
                _deviceRole = null;
                _codeController.clear();
              });
            },
            child: const Text(
              'Change Role',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}