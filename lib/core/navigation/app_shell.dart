import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  // Branch indices == nav bar indices: 0=Dashboard 1=Leads 2=AddLead 3=FollowUps 4=Settings

  void _onTap(int navIndex, BuildContext context) {
    navigationShell.goBranch(
      navIndex,
      initialLocation: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: CurvedNavigationBar(
        index: navigationShell.currentIndex,
        height: 65,
        color: AppColors.backgroundDark,
        buttonBackgroundColor: AppColors.backgroundDark,
        backgroundColor: Colors.white,
        animationDuration: const Duration(milliseconds: 280),
        animationCurve: Curves.easeOut,
        items: const [
          Icon(Icons.home_rounded, size: 26, color: Colors.white),
          Icon(Icons.people_rounded, size: 26, color: Colors.white),
          Icon(Icons.add_rounded, size: 28, color: Colors.white),
          Icon(Icons.event_note_rounded, size: 26, color: Colors.white),
          Icon(Icons.settings_rounded, size: 26, color: Colors.white),
        ],
        onTap: (index) => _onTap(index, context),
      ),
    );
  }
}
