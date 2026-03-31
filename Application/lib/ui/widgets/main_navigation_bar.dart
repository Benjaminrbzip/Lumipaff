import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../../res/assets.dart';
import '../../app_routes.dart';

class MainNavigationBar extends StatelessWidget {
  final int currentIndex;

  const MainNavigationBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    String routeName;
    switch (index) {
      case 0:
        routeName = AppRoutes.home;
        break;
      case 1:
        routeName = AppRoutes.leaderboard;
        break;
      case 2:
        routeName = AppRoutes.settings;
        break;
      default:
        routeName = AppRoutes.home;
    }
    
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: const BoxDecoration(
        color: kNavigationBarColor,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, 0, 'Home', AppAssets.iconNavHome, currentIndex == 0),
            _buildNavItem(context, 1, 'Leaderboard', AppAssets.iconNavPodium, currentIndex == 1),
            _buildNavItem(context, 2, 'Setting', AppAssets.iconNavSettings, currentIndex == 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, String assetPath, bool isActive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTapped(context, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: isActive ? BoxDecoration(
              color: kCyanColor,
              borderRadius: BorderRadius.circular(20),
            ) : null,
            child: Image.asset(
              assetPath, 
              color: isActive ? kPrimaryBackgroundColor : kCyanColor,
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: kCyanColor,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
