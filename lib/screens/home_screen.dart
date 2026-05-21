/// Home Screen — Main navigation shell for VisionGo.
///
/// Implements a three-tab bottom navigation bar with a custom glowing
/// pill-shaped design. The tabs are:
///   - [MainGalleryScreen] (index 0): Photo gallery with object detection
///   - [SecurityScreen] (index 1): Security camera pairing & monitoring
///   - [AccountScreen] (index 2): User profile and device management
///
/// Back-button behaviour: pressing back on a non-Gallery tab switches
/// to the Gallery tab first; on the Gallery tab it shows an exit
/// confirmation dialog.
library;

import 'package:flutter/material.dart';
import 'main_gallery.dart';
import 'security_screen.dart';
import 'account_screen.dart';

/// Stateful shell widget that hosts the bottom navigation and
/// swaps between the three main sections of the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Screens for bottom navigation
  final List<Widget> _screens = [
    const MainGalleryScreen(),
    const SecurityScreen(),
    const AccountScreen(),
  ];

  // Navigation items data
  final List<Map<String, dynamic>> _navItems = [
    {
      'icon': Icons.photo_library_outlined,
      'activeIcon': Icons.photo_library,
    },
    {
      'icon': Icons.security_outlined,
      'activeIcon': Icons.security,
    },
    {
      'icon': Icons.account_circle_outlined,
      'activeIcon': Icons.account_circle,
    },
  ];

  /// Handles bottom-nav tab selection.
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Shows an exit-confirmation dialog and returns whether the user
  /// chose to leave the app.
  Future<bool> _shouldExitApp() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Exit App?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Do you want to exit VisionGo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0, // Only allow pop if on first tab
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return; // Already popped, do nothing
        }

        // If not on the first tab (Gallery), switch to it
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          // On first tab, show exit confirmation
          final shouldExit = await _shouldExitApp();
          if (shouldExit && context.mounted) {
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: _screens[_currentIndex],
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  /// Builds the floating, pill-shaped bottom navigation bar with
  /// a teal glow effect on the active item.
  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 65,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1F1F), Color(0xFF1A1A1A)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                blurRadius: 40,
              ),
            ],
          ),
          child: Row(
            children: List.generate(_navItems.length, (index) {
              return _buildNavItem(index);
            }),
          ),
        ),
      ),
    );
  }

  /// Builds a single navigation item with an animated icon and
  /// optional glow background.
  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    final item = _navItems[index];

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect for active item
                if (isActive) _buildGlowEffect(),

                // Icon with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isActive ? item['activeIcon'] : item['icon'],
                    key: ValueKey('$index-$isActive'),
                    color: isActive ? Colors.tealAccent : Colors.white.withValues(alpha: 0.5),
                    size: isActive ? 28 : 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Animated radial glow rendered behind the active nav icon.
  Widget _buildGlowEffect() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: 50 * value,
          height: 50 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.tealAccent.withValues(alpha: 0.15 * value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}