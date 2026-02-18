import 'dart:ui';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:chitchat/screens/search.dart';
import 'package:chitchat/screens/watchlist.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class AppBottomNav extends StatefulWidget {
  final VoidCallback? onHomeRefresh;
  final int initialIndex;

  const AppBottomNav({
    super.key,
    this.onHomeRefresh,
    this.initialIndex = 0,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    if (_activeIndex == index) {
      if (index == 0 && widget.onHomeRefresh != null) {
        widget.onHomeRefresh!();
      }
      return;
    }

    setState(() => _activeIndex = index);

    switch (index) {
      case 0:
        widget.onHomeRefresh?.call();
        break;
      case 1:
        _navigate(SearchPage());
        break;
      case 2:
        _navigate(WatchlistPage());
        break;
      case 3:
        _navigate(PrivetProfilePage());
        break;
    }
  }

  void _navigate(Widget page) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              // color: Colors.white.withOpacity(0.08),
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 0),
                _navItem(Icons.search_rounded, 1),
                _navItem(Icons.favorite_rounded, 2),
                _navItem(Icons.groups, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final isSelected = _activeIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.warning.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? AppColors.warning : Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
