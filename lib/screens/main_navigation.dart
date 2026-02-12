import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class NavigationState {
  final int current;
  final int previous;
  NavigationState({required this.current, required this.previous});
}

final navigationStateProvider = StateProvider<NavigationState>(
  (ref) => NavigationState(current: 0, previous: 0),
);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationStateProvider);
    final selectedIndex = navState.current;
    final isReverse = navState.current < navState.previous;

    final List<Widget> screens = [
      const DashboardScreen(), // Home
      const LibraryScreen(), // Library
      const StatsScreen(), // Stats
      const SettingsScreen(), // Settings
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        reverse: isReverse,
        transitionBuilder: (child, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: Colors.transparent,
            child: child,
          );
        },
        child: Container(
          key: ValueKey<int>(selectedIndex),
          child: screens[selectedIndex],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GlassContainer(
            height: 70,
            blur: 20,
            opacity: 0.1,
            borderRadius: 35,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  ref,
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  ref,
                  index: 1,
                  icon: Icons.menu_book_rounded,
                  label: 'Library',
                ),
                _buildNavItem(
                  ref,
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                ),
                _buildNavItem(
                  ref,
                  index: 3,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    WidgetRef ref, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final navState = ref.watch(navigationStateProvider);
    final selectedIndex = navState.current;
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedIndex != index) {
            ref.read(navigationStateProvider.notifier).state = NavigationState(
              current: index,
              previous: selectedIndex,
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? YomuConstants.accent
                  : YomuConstants.textSecondary,
              size: 28,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: YomuConstants.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
