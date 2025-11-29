import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Dark theme setup
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );
    final colors = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text("VisionGo"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile section
            _buildProfileCard(user, colors, theme),

            const SizedBox(height: 16),

            // Settings section title
            _buildSectionTitle("Settings", colors, theme),

            // Settings options
            _buildSettingTile("Security Devices", "Manage paired devices", Icons.security, colors),
            _buildSettingTile("Notifications", "Alert preferences", Icons.notifications, colors),
            _buildSettingTile("Version", "1.0.0", Icons.storage, colors),

            const SizedBox(height: 20),

            // Logout button
            _buildLogoutButton(colors, context),
          ],
        ),
      ),
    );
  }

  // Profile card widget
  Widget _buildProfileCard(User? user, ColorScheme colors, ThemeData theme) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: colors.primaryContainer,
              child: Icon(Icons.person, size: 42, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? "User Name",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? "user@example.com",
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // Section title widget
  Widget _buildSectionTitle(String title, ColorScheme colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Settings tile widget
  Widget _buildSettingTile(String title, String subtitle, IconData icon, ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {}, // Add functionality here
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colors.primaryContainer,
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant)),
      ),
    );
  }

  // Logout button widget
  Widget _buildLogoutButton(ColorScheme colors, BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
      onPressed: () => _showLogoutDialog(context),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout),
          SizedBox(width: 8),
          Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Logout confirmation dialog
  void _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }
}