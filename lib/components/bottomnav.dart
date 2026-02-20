import 'dart:ui';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/camera.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/search.dart';
import 'package:chitchat/screens/watchlist.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

// ---------------------------------------------------------------------------
// NavMenuItem — describes one bottom nav icon + optional custom tap handler
// ---------------------------------------------------------------------------
class NavMenuItem {
  final IconData icon;
  final String? label;

  /// Custom handler called when this item is tapped.
  final VoidCallback? onTap;

  const NavMenuItem({
    required this.icon,
    this.label,
    this.onTap,
  });
}

// ---------------------------------------------------------------------------
// AppBottomNav — stateless, pass highlightIndex from each screen
// ---------------------------------------------------------------------------
class AppBottomNav extends StatelessWidget {
  /// Which icon (0-3) to highlight. Use -1 for no highlight (sub-pages).
  final int highlightIndex;

  /// Nav items (left + right of center). Defaults to 4 icons if empty.
  final List<NavMenuItem> items;

  // ── Center button options ──────────────────────────────────────────
  final bool showCenterButton;

  /// If true the center button floats above the bar (FAB-style).
  /// Home page sets this to true; other pages default to false (inline).
  final bool centerButtonFloat;
  final IconData centerButtonIcon;
  final Color? centerButtonColor;
  final double? centerButtonSize;
  final VoidCallback? onCenterButtonTap;

  const AppBottomNav({
    super.key,
    this.highlightIndex = -1,
    this.items = const [],
    this.showCenterButton = true,
    this.centerButtonFloat = false,
    this.centerButtonIcon = Icons.camera_alt_rounded,
    this.centerButtonColor,
    this.centerButtonSize,
    this.onCenterButtonTap,
  });

  /// Default nav icons (no onTap — handled by [_defaultNavigate]).
  static const List<NavMenuItem> _defaultItems = [
    NavMenuItem(icon: Icons.home_rounded),
    NavMenuItem(icon: Icons.search_rounded),
    NavMenuItem(icon: Icons.favorite_rounded),
    NavMenuItem(icon: Icons.groups),
  ];

  List<NavMenuItem> get _effectiveItems =>
      items.isEmpty ? _defaultItems : items;

  bool get _usingDefaults => items.isEmpty;

  // ── Default navigation for tapping a default item ──────────────────
  void _defaultNavigate(BuildContext context, int index) {
    if (index == highlightIndex) return; // already on this tab

    Widget page;
    switch (index) {
      case 0:
        page = const HomePage();
        break;
      case 1:
        page = SearchPage();
        break;
      case 2:
        page = WatchlistPage();
        break;
      case 3:
        page = const PrivetProfilePage();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageTransition(
        isIos: true,
        type: PageTransitionType.rightToLeft,
        child: page,
        curve: Curves.fastEaseInToSlowEaseOut,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _defaultCameraTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const barHeight = 52.0;
    final centerBtnSize = this.centerButtonSize ?? 58.0;
    final centerBtnColor = this.centerButtonColor ?? Colors.blue;

    final navItems = _effectiveItems;
    final int half = (navItems.length / 2).floor();
    final leftItems = navItems.sublist(0, half);
    final rightItems = navItems.sublist(half);

    Widget bar = ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            // Colored glass — opaque-ish, not transparent
            color: AppColors.background.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.10),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left items
              ...leftItems.map((item) {
                final idx = navItems.indexOf(item);
                return _navIcon(context, item, idx);
              }),

              // Center placeholder / inline button
              if (showCenterButton && !centerButtonFloat)
                _inlineCenterButton(context, centerBtnColor, centerBtnSize)
              else if (showCenterButton && centerButtonFloat)
                SizedBox(width: centerBtnSize + 12),

              // Right items
              ...rightItems.map((item) {
                final idx = navItems.indexOf(item);
                return _navIcon(context, item, idx);
              }),
            ],
          ),
        ),
      ),
    );

    // If center button floats, wrap in a Stack so it protrudes above the bar
    if (showCenterButton && centerButtonFloat) {
      return SizedBox(
        height: barHeight + (centerBtnSize / 2) + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, right: 0, bottom: 0, child: bar),
            Positioned(
              bottom: barHeight - (centerBtnSize / 2) + 2,
              left: 0,
              right: 0,
              child: Center(
                child: _floatingCenterButton(
                    context, centerBtnColor, centerBtnSize),
              ),
            ),
          ],
        ),
      );
    }

    return bar;
  }

  // ── Individual nav icon ─────────────────────────────────────────────
  Widget _navIcon(BuildContext context, NavMenuItem item, int index) {
    final isSelected = highlightIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (item.onTap != null) {
          item.onTap!.call();
        } else if (_usingDefaults) {
          _defaultNavigate(context, index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.warning.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          item.icon,
          size: 24,
          color: isSelected ? AppColors.warning : Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  // ── Inline center button (non-floating) ─────────────────────────────
  Widget _inlineCenterButton(BuildContext context, Color color, double size) {
    return GestureDetector(
      onTap: onCenterButtonTap ?? () => _defaultCameraTap(context),
      child: Container(
        width: size * 0.70,
        height: size * 0.70,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          centerButtonIcon,
          color: Colors.white,
          size: size * 0.38,
        ),
      ),
    );
  }

  // ── Floating center button ──────────────────────────────────────────
  Widget _floatingCenterButton(BuildContext context, Color color, double size) {
    return GestureDetector(
      onTap: onCenterButtonTap ?? () => _defaultCameraTap(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.background.withValues(alpha: 0.8),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          centerButtonIcon,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }
}
