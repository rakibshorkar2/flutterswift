import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutterswift/core/theme.dart';

class NavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> with SingleTickerProviderStateMixin {
  late final AnimationController _hideController;
  late final Animation<double> _hideAnimation;

  @override
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hideAnimation = CurvedAnimation(
      parent: _hideController,
      curve: Curves.easeInOutCubic,
    );
    // Start visible
    _hideController.value = 0.0;
  }

  @override
  void dispose() {
    _hideController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Navigated tab page content
          Positioned.fill(
            child: widget.navigationShell,
          ),
          
          // Floating Bottom Navigation Bar Overlay
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomInset > 0 ? bottomInset : 20,
            child: AnimatedBuilder(
              animation: _hideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 100 * _hideAnimation.value),
                  child: Opacity(
                    opacity: 1.0 - _hideAnimation.value,
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassEffects.blurSigmaX,
                    sigmaY: GlassEffects.blurSigmaY,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.glassBgDark : AppColors.glassBgLight,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? const Color(0x66000000) : const Color(0x2B000000),
                          blurRadius: 24,
                          spreadRadius: -2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: CupertinoIcons.globe,
                          label: 'Browser',
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: CupertinoIcons.arrow_down_circle,
                          label: 'Downloader',
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: CupertinoIcons.shield,
                          label: 'Proxy',
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 3,
                          icon: CupertinoIcons.doc_on_clipboard,
                          label: 'Clipboard',
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 4,
                          icon: CupertinoIcons.settings,
                          label: 'Settings',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = widget.navigationShell.currentIndex == index;
    final accentColor = isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue;
    final inactiveColor = isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: AppSprings.interactiveSpring,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0x260A84FF) : const Color(0x1F007AFF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: AppSprings.interactiveSpring,
              child: Icon(
                icon,
                color: isSelected ? accentColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.sfPro(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? accentColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
