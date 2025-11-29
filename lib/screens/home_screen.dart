import 'package:flutter/material.dart';
import 'main_gallery.dart';
import 'security_screen.dart';
import 'account_screen.dart';

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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Handle back button press
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
      onPopInvoked: (didPop) async {
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

  // Custom bottom navigation bar
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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.tealAccent.withOpacity(0.1),
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

  // Single navigation item
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
                    color: isActive ? Colors.tealAccent : Colors.white.withOpacity(0.5),
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

  // Glow effect for active navigation item
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
                Colors.tealAccent.withOpacity(0.15 * value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}