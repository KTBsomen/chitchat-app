import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:chitchat/screens/search.dart';
import 'package:chitchat/screens/watchlist.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class AppBottomNav extends StatefulWidget {
  /// Optional callbacks for pages that need refresh logic
  final VoidCallback? onHomeRefresh;

  /// Default selected index (optional)
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
      // Re-tap logic (Home refresh etc.)
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 60,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        color: AppColors.Secondarybackground,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 0),
              _navItem(Icons.search_rounded, 1),
              const SizedBox(width: 30), // FAB gap
              _navItem(Icons.favorite_rounded, 2),
              _navItem(Icons.groups, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final isSelected = _activeIndex == index;

    return IconButton(
      icon: Icon(icon, size: 30),
      color: isSelected ? AppColors.warning : Colors.white,
      onPressed: () => _onItemTapped(index),
    );
  }
}
