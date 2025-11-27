import 'package:flutter/material.dart';
import 'main_gallery.dart';
import 'security_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  final List<Widget> _screens = [
    const MainGalleryScreen(),
    const SecurityScreen(),
    const AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    );
    _slideController.value = _currentIndex / 2;
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _slideController.animateTo(
        index / 2,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        height: 65,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F1F1F),
                  const Color(0xFF1A1A1A),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.photo_library_outlined,
                  activeIcon: Icons.photo_library,
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.security_outlined,
                  activeIcon: Icons.security,
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.account_circle_outlined,
                  activeIcon: Icons.account_circle,
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
  }) {
    final bool isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing glow effect for active icon
                  if (isActive)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
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
                      onEnd: () {
                        if (mounted && isActive) {
                          setState(() {});
                        }
                      },
                    ),
                  // Icon with scale animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey('$index-$isActive'),
                      color: isActive
                          ? Colors.tealAccent
                          : Colors.white.withOpacity(0.5),
                      size: isActive ? 28 : 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}