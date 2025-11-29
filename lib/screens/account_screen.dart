import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_devices_section.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load current user data
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    _currentUser = _auth.currentUser;
    setState(() => _isLoading = false);
  }

  // Sign out user with confirmation
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.signOut();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching user data
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProfileCard(),
              const SizedBox(height: 20),
              const ManageSecurityDevicesSection(),
              const SizedBox(height: 20),
              _buildSettingsSection(),
              const SizedBox(height: 20),
              _buildAboutSection(),
              const SizedBox(height: 20),
              _buildSignOutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // App header with title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Row(
        children: [
          Icon(Icons.account_circle, color: Colors.tealAccent, size: 28),
          SizedBox(width: 12),
          Text('Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  // User profile card with avatar and info
  Widget _buildProfileCard() {
    String getUserInitial() => _currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U';
    String getUserId() {
      final uid = _currentUser?.uid;
      if (uid != null && uid.length >= 8) {
        return uid.substring(uid.length - 8);
      }
      return 'Unknown';
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2), width: 1),
        boxShadow: [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          // User avatar with initial
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Colors.tealAccent, Color(0xFF00BCD4)]),
              boxShadow: [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: Center(
              child: Text(getUserInitial(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
          const SizedBox(height: 16),

          // User email
          SizedBox(
            width: double.infinity,
            child: Text(
              _currentUser?.email ?? 'No email',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2,
            ),
          ),
          const SizedBox(height: 8),

          // User ID
          SizedBox(
            width: double.infinity,
            child: Text(
              'ID: ${getUserId()}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Account status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('Active Account', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Settings section with options
  Widget _buildSettingsSection() {
    final settings = [
      {'icon': Icons.notifications, 'title': 'Notifications', 'subtitle': 'Manage notification preferences'},
      {'icon': Icons.lock, 'title': 'Privacy & Security', 'subtitle': 'Control your privacy settings'},
      {'icon': Icons.storage, 'title': 'Storage', 'subtitle': 'Manage app data and cache'},
      {'icon': Icons.language, 'title': 'Language', 'subtitle': 'English (Default)'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Colors.tealAccent, size: 24),
              SizedBox(width: 12),
              Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Generate setting items from list
          ...settings.map((setting) => _buildSettingItem(
            icon: setting['icon'] as IconData,
            title: setting['title'] as String,
            subtitle: setting['subtitle'] as String,
            onTap: () => _showComingSoonSnackbar(context, setting['title'] as String),
          )),
        ],
      ),
    );
  }

  // Individual setting item widget
  Widget _buildSettingItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.tealAccent, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // About section with app info
  Widget _buildAboutSection() {
    final aboutItems = [
      {'label': 'App Version', 'value': '1.0.0'},
      {'label': 'Build Number', 'value': '100'},
      {'label': 'Developer', 'value': 'VisionGo Team'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.tealAccent, size: 24),
              SizedBox(width: 12),
              Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Generate about items from list
          ...aboutItems.map((item) => Column(
            children: [
              _buildAboutItem(label: item['label'] as String, value: item['value'] as String),
              const SizedBox(height: 12),
            ],
          )),

          // Licenses button
          Center(
            child: TextButton.icon(
              onPressed: () => _showAboutDialog(context),
              icon: const Icon(Icons.help_outline, color: Colors.tealAccent),
              label: const Text('View Licenses', style: TextStyle(color: Colors.tealAccent)),
            ),
          ),
        ],
      ),
    );
  }

  // Individual about item widget
  Widget _buildAboutItem({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)), overflow: TextOverflow.ellipsis),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // Sign out button
  Widget _buildSignOutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
      ),
    );
  }

  // Helper function to show coming soon message
  void _showComingSoonSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon'), backgroundColor: Colors.orange),
    );
  }

  // Helper function to show about dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('VisionGo', style: TextStyle(color: Colors.white)),
        content: const Text(
          'AI-powered object detection app with real-time security monitoring.\n\nVersion 1.0.0\n\n© 2025 VisionGo Team',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }
}